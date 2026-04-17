
package com.laundromat.pos.data.db
import androidx.room.*
import com.laundromat.pos.data.model.*

@Dao
interface PosDao {
    @Query("SELECT * FROM machines WHERE id = :machineId LIMIT 1")
    fun getMachineById(machineId: Int): Machine?

    @Query("SELECT * FROM machines ORDER BY name")
    fun getAllMachines(): List<Machine>

    @Query("SELECT * FROM machines WHERE status = :status ORDER BY name")
    fun getMachinesByStatus(status: String = MachineStatus.AVAILABLE): List<Machine>

    @Transaction
    @Query("SELECT * FROM machines ORDER BY name")
    fun getMachinesWithServiceHistory(): List<MachineWithServiceHistory>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertMachine(machine: Machine): Long

    @Update
    fun updateMachine(machine: Machine)

    @Delete
    fun deleteMachine(machine: Machine)

    @Query("SELECT * FROM customers ORDER BY fullName")
    fun getAllCustomers(): List<Customer>

    @Query("SELECT * FROM customers WHERE phone LIKE '%' || :query || '%' OR fullName LIKE '%' || :query || '%' ORDER BY fullName")
    fun searchCustomers(query: String): List<Customer>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertCustomer(customer: Customer): Long

    @Update
    fun updateCustomer(customer: Customer)

    @Delete
    fun deleteCustomer(customer: Customer)

    @Insert
    fun insertOrder(order: Order): Long

    @Update
    fun updateOrder(order: Order)

    @Delete
    fun deleteOrder(order: Order)

    @Transaction
    @Query("SELECT * FROM orders ORDER BY timestamp DESC")
    fun getOrderHistory(): List<OrderWithDetails>

    @Transaction
    @Query("SELECT * FROM orders WHERE id = :orderId LIMIT 1")
    fun getOrderById(orderId: Int): OrderWithDetails?

    @Insert
    fun insertPayment(payment: PaymentTransaction): Long

    @Query("SELECT * FROM payment_transactions WHERE orderId = :orderId ORDER BY createdAt DESC")
    fun getPaymentsForOrder(orderId: Int): List<PaymentTransaction>

    @Query("SELECT * FROM inventory_items ORDER BY name")
    fun getInventoryItems(): List<InventoryItem>

    @Query("SELECT * FROM inventory_items WHERE quantityOnHand <= reorderLevel ORDER BY quantityOnHand ASC, name")
    fun getLowStockItems(): List<InventoryItem>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertInventoryItem(item: InventoryItem): Long

    @Update
    fun updateInventoryItem(item: InventoryItem)

    @Delete
    fun deleteInventoryItem(item: InventoryItem)

    @Insert
    fun insertServiceRecord(record: ServiceRecord): Long

    @Query("SELECT * FROM service_records WHERE machineId = :machineId ORDER BY performedAt DESC")
    fun getServiceRecordsForMachine(machineId: Int): List<ServiceRecord>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsertUser(user: PosUser): Long

    @Query("SELECT COUNT(*) FROM machines")
    fun getMachineCount(): Int

    @Query("SELECT COUNT(*) FROM customers")
    fun getCustomerCount(): Int

    @Query("SELECT COUNT(*) FROM pos_users")
    fun getUserCount(): Int

    @Query("SELECT * FROM pos_users WHERE username = :username AND pin = :pin AND isActive = 1 LIMIT 1")
    fun authenticate(username: String, pin: String): PosUser?

    @Query("UPDATE pos_users SET lastLoginAt = :timestamp WHERE id = :userId")
    fun updateLastLogin(userId: Int, timestamp: Long = System.currentTimeMillis())

    @Query(
        """
        SELECT
            COALESCE((SELECT SUM(amount) FROM orders WHERE paymentStatus = 'PAID'), 0) AS totalRevenue,
            (SELECT COUNT(*) FROM orders) AS totalOrders,
            (SELECT COUNT(*) FROM machines WHERE status = 'AVAILABLE') AS availableMachines,
            (SELECT COUNT(*) FROM inventory_items WHERE quantityOnHand <= reorderLevel) AS lowStockItems
        """
    )
    fun getDashboardSummary(): DashboardSummary

    @Query(
        """
        SELECT
            paymentMethod AS paymentMethod,
            COALESCE(SUM(amount), 0) AS totalAmount,
            COUNT(*) AS transactionCount
        FROM payment_transactions
        GROUP BY paymentMethod
        ORDER BY totalAmount DESC
        """
    )
    fun getPaymentMethodTotals(): List<PaymentMethodTotal>
}
