package com.laundromat.pos.ui.customer

import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.ListView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.laundromat.pos.R
import com.laundromat.pos.data.model.Machine
import com.laundromat.pos.data.model.MachineStatus
import com.laundromat.pos.data.repository.PosRepository
import com.laundromat.pos.payment.QrPaymentGateway
import com.laundromat.pos.ui.common.UiThread
import java.util.UUID

class CustomerSelfServiceActivity : AppCompatActivity() {
    private lateinit var repository: PosRepository
    private lateinit var paymentGateway: QrPaymentGateway
    private lateinit var machineList: ListView
    private lateinit var selectedMachineText: TextView
    private lateinit var emptyText: TextView
    private lateinit var customerNameInput: EditText
    private lateinit var customerPhoneInput: EditText
    private lateinit var paymentMethodSpinner: Spinner
    private lateinit var payButton: Button

    private var machines: List<Machine> = emptyList()
    private var selectedMachine: Machine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_customer_self_service)

        repository = PosRepository.get(applicationContext)
        paymentGateway = QrPaymentGateway()
        machineList = findViewById(R.id.listSelfServiceMachines)
        selectedMachineText = findViewById(R.id.txtSelectedMachine)
        emptyText = findViewById(R.id.txtEmptySelfServiceMachines)
        customerNameInput = findViewById(R.id.edtSelfServiceCustomerName)
        customerPhoneInput = findViewById(R.id.edtSelfServiceCustomerPhone)
        paymentMethodSpinner = findViewById(R.id.spinnerSelfServicePaymentMethod)
        payButton = findViewById(R.id.btnSelfServicePay)

        paymentMethodSpinner.adapter = ArrayAdapter.createFromResource(
            this,
            R.array.payment_methods,
            android.R.layout.simple_spinner_dropdown_item
        )

        selectedMachineText.text = getString(R.string.customer_self_service_no_machine)
        payButton.setOnClickListener {
            completeSelfServiceCheckout()
        }
        machineList.setOnItemClickListener { _, _, position, _ ->
            selectedMachine = machines[position]
            selectedMachineText.text = getString(
                R.string.customer_self_service_selected_machine,
                machineDescription(machines[position])
            )
        }

        loadMachines()
    }

    private fun loadMachines() {
        payButton.isEnabled = false
        emptyText.visibility = View.VISIBLE
        emptyText.text = getString(R.string.customer_self_service_loading)
        Thread {
            val availableMachines = repository.getMachines().get()
                .filter { it.status == MachineStatus.AVAILABLE }
            UiThread.post {
                machines = availableMachines
                machineList.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_list_item_activated_1,
                    availableMachines.map(::machineDescription)
                )
                emptyText.text = if (availableMachines.isEmpty()) {
                    getString(R.string.customer_self_service_empty)
                } else {
                    ""
                }
                payButton.isEnabled = availableMachines.isNotEmpty()
            }
        }.start()
    }

    private fun completeSelfServiceCheckout() {
        val machine = selectedMachine
        if (machine == null) {
            Toast.makeText(this, R.string.customer_self_service_machine_required, Toast.LENGTH_SHORT).show()
            return
        }

        payButton.isEnabled = false
        val customerName = customerNameInput.text.toString().trim()
            .ifEmpty { getString(R.string.customer_self_service_walk_in) }
        val customerPhone = customerPhoneInput.text.toString().trim()
            .ifEmpty { "9${System.currentTimeMillis().toString().takeLast(9)}" }
        val paymentMethod = paymentMethodSpinner.selectedItem.toString()
        val reference = "SELF-${UUID.randomUUID().toString().take(8).uppercase()}"

        selectedMachineText.text = getString(R.string.customer_payment_processing)

        Thread {
            val customerId = repository.saveWalkInCustomer(customerName, customerPhone).get().toInt()
            paymentGateway.createPaymentIntent(
                amount = machine.price,
                method = paymentMethod,
                orderReference = reference
            )
            val orderId = repository.createPaidOrder(
                machine = machine,
                customerId = customerId,
                userId = null,
                paymentMethod = paymentMethod,
                paymentReference = reference
            ).get()

            UiThread.post {
                customerNameInput.text?.clear()
                customerPhoneInput.text?.clear()
                selectedMachine = null
                selectedMachineText.text = getString(R.string.customer_self_service_thank_you)
                payButton.isEnabled = true
                Toast.makeText(
                    this,
                    getString(R.string.customer_self_service_payment_success, orderId),
                    Toast.LENGTH_SHORT
                ).show()
                loadMachines()
            }
        }.start()
    }

    private fun machineDescription(machine: Machine): String =
        "${machine.name} • ${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toInt()}"
}
