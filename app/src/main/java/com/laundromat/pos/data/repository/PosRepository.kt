package com.laundromat.pos.data.repository

import android.content.Context
import com.laundromat.pos.data.db.AppDatabase
import com.laundromat.pos.data.db.PosDao
import com.laundromat.pos.data.model.Customer
import com.laundromat.pos.data.model.DashboardSummary
import com.laundromat.pos.data.model.InventoryItem
import com.laundromat.pos.data.model.Machine
import com.laundromat.pos.data.model.MachineStatus
import com.laundromat.pos.data.model.Order
import com.laundromat.pos.data.model.OrderStatus
import com.laundromat.pos.data.model.OrderWithDetails
import com.laundromat.pos.data.model.PaymentStatus
import com.laundromat.pos.data.model.PaymentMethodTotal
import com.laundromat.pos.data.model.PaymentTransaction
import com.laundromat.pos.data.model.PosUser
import com.laundromat.pos.data.model.ServiceRecord
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

class PosRepository private constructor(
    context: Context,
    private val ioExecutor: ExecutorService = Executors.newFixedThreadPool(4)
) {
    private val database: AppDatabase = AppDatabase.get(context)
    private val dao: PosDao = database.posDao()

    fun seedDemoData(): Future<Unit> =
        ioExecutor.submit<Unit> {
            database.runInTransaction {
                if (dao.getUserCount() == 0) {
                    dao.upsertUser(
                        PosUser(
                            username = "admin",
                            displayName = "Store Admin",
                            pin = "1234",
                            role = "ADMIN"
                        )
                    )
                }

                if (dao.getMachineCount() == 0) {
                    dao.upsertMachine(
                        Machine(
                            name = "Washer 01",
                            type = "Washer",
                            capacityKg = 8,
                            price = 120.0,
                            status = MachineStatus.AVAILABLE
                        )
                    )
                    dao.upsertMachine(
                        Machine(
                            name = "Dryer 02",
                            type = "Dryer",
                            capacityKg = 10,
                            price = 150.0,
                            status = MachineStatus.AVAILABLE
                        )
                    )
                    dao.upsertMachine(
                        Machine(
                            name = "Washer 03",
                            type = "Washer",
                            capacityKg = 12,
                            price = 180.0,
                            status = MachineStatus.MAINTENANCE
                        )
                    )
                }

                if (dao.getCustomerCount() == 0) {
                    dao.upsertCustomer(
                        Customer(
                            fullName = "Walk-in Customer",
                            phone = "9999999999",
                            notes = "Default customer profile"
                        )
                    )
                }
            }
            Unit
        }

    fun getMachines(): Future<List<Machine>> = ioExecutor.submit<List<Machine>> { dao.getAllMachines() }

    fun getMachine(machineId: Int): Future<Machine?> =
        ioExecutor.submit<Machine?> { dao.getMachineById(machineId) }

    fun saveMachine(machine: Machine): Future<Long> =
        ioExecutor.submit<Long> { dao.upsertMachine(machine) }

    fun removeMachine(machine: Machine): Future<Unit> =
        ioExecutor.submit<Unit> {
            dao.deleteMachine(machine)
            Unit
        }

    fun getCustomers(): Future<List<Customer>> =
        ioExecutor.submit<List<Customer>> { dao.getAllCustomers() }

    fun saveWalkInCustomer(fullName: String, phone: String): Future<Long> =
        ioExecutor.submit<Long> {
            dao.upsertCustomer(
                Customer(
                    fullName = fullName,
                    phone = phone
                )
            )
        }

    fun saveCustomer(customer: Customer): Future<Long> =
        ioExecutor.submit<Long> { dao.upsertCustomer(customer) }

    fun login(username: String, pin: String): Future<PosUser?> =
        ioExecutor.submit<PosUser?> {
            dao.authenticate(username, pin)?.also { user ->
                dao.updateLastLogin(user.id)
            }
        }

    fun checkout(order: Order, payment: PaymentTransaction): Future<Long> =
        ioExecutor.submit<Long> {
            database.runInTransaction<Long> {
                val orderId = dao.insertOrder(order).toInt()
                dao.insertPayment(payment.copy(orderId = orderId))
                orderId.toLong()
            }
        }

    fun createPaidOrder(
        machine: Machine,
        customerId: Int?,
        userId: Int?,
        paymentMethod: String,
        paymentReference: String
    ): Future<Long> =
        ioExecutor.submit<Long> {
            database.runInTransaction<Long> {
                val orderId = dao.insertOrder(
                    Order(
                        machineId = machine.id,
                        customerId = customerId,
                        createdByUserId = userId,
                        serviceType = machine.type.uppercase(),
                        amount = machine.price,
                        status = OrderStatus.COMPLETED,
                        paymentMethod = paymentMethod,
                        paymentStatus = PaymentStatus.PAID,
                        paymentReference = paymentReference,
                        notes = "Created from checkout flow"
                    )
                ).toInt()
                dao.insertPayment(
                    PaymentTransaction(
                        orderId = orderId,
                        paymentMethod = paymentMethod,
                        amount = machine.price,
                        provider = "QR",
                        reference = paymentReference,
                        status = PaymentStatus.PAID
                    )
                )
                dao.updateMachine(machine.copy(status = MachineStatus.AVAILABLE))
                orderId.toLong()
            }
        }

    fun getOrderHistory(): Future<List<OrderWithDetails>> =
        ioExecutor.submit<List<OrderWithDetails>> { dao.getOrderHistory() }

    fun getInventory(): Future<List<InventoryItem>> =
        ioExecutor.submit<List<InventoryItem>> { dao.getInventoryItems() }

    fun saveInventoryItem(item: InventoryItem): Future<Long> =
        ioExecutor.submit<Long> { dao.upsertInventoryItem(item) }

    fun logService(record: ServiceRecord): Future<Long> =
        ioExecutor.submit<Long> { dao.insertServiceRecord(record) }

    fun getDashboardSummary(): Future<DashboardSummary> =
        ioExecutor.submit<DashboardSummary> { dao.getDashboardSummary() }

    fun getPaymentMethodTotals(): Future<List<PaymentMethodTotal>> =
        ioExecutor.submit<List<PaymentMethodTotal>> { dao.getPaymentMethodTotals() }

    companion object {
        @Volatile
        private var instance: PosRepository? = null

        fun get(context: Context): PosRepository =
            instance ?: synchronized(this) {
                instance ?: PosRepository(context.applicationContext).also { instance = it }
            }
    }
}
