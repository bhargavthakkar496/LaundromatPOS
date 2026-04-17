package com.laundromat.pos.ui.checkout

import android.hardware.display.DisplayManager
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.laundromat.pos.R
import com.laundromat.pos.data.model.Machine
import com.laundromat.pos.data.repository.PosRepository
import com.laundromat.pos.payment.QrPaymentGateway
import com.laundromat.pos.ui.common.UiThread
import com.laundromat.pos.ui.customer.CustomerDisplayState
import com.laundromat.pos.ui.customer.CustomerPresentation
import com.laundromat.pos.ui.history.OrderHistoryActivity
import com.laundromat.pos.ui.machine.MachineListActivity
import java.util.UUID

class CheckoutActivity : AppCompatActivity() {
    private lateinit var repository: PosRepository
    private lateinit var paymentGateway: QrPaymentGateway
    private lateinit var machineNameText: TextView
    private lateinit var amountText: TextView
    private lateinit var customerNameInput: EditText
    private lateinit var customerPhoneInput: EditText
    private lateinit var paymentMethodSpinner: Spinner
    private lateinit var payButton: Button
    private var machine: Machine? = null
    private var customerPresentation: CustomerPresentation? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_checkout)

        repository = PosRepository.get(applicationContext)
        paymentGateway = QrPaymentGateway()
        machineNameText = findViewById(R.id.txtCheckoutMachine)
        amountText = findViewById(R.id.txtCheckoutAmount)
        customerNameInput = findViewById(R.id.edtCustomerName)
        customerPhoneInput = findViewById(R.id.edtCustomerPhone)
        paymentMethodSpinner = findViewById(R.id.spinnerPaymentMethod)
        payButton = findViewById(R.id.btnCompletePayment)

        paymentMethodSpinner.adapter = ArrayAdapter.createFromResource(
            this,
            R.array.payment_methods,
            android.R.layout.simple_spinner_dropdown_item
        )

        attachCustomerDisplay()
        loadMachine()

        payButton.setOnClickListener {
            completeCheckout()
        }
    }

    override fun onStop() {
        super.onStop()
        customerPresentation?.dismiss()
    }

    private fun attachCustomerDisplay() {
        val displayManager = getSystemService(DISPLAY_SERVICE) as DisplayManager
        val displays = displayManager.displays
        if (displays.size > 1) {
            customerPresentation = CustomerPresentation(this, displays[1]).also { it.show() }
        }
    }

    private fun loadMachine() {
        val machineId = intent.getIntExtra(EXTRA_MACHINE_ID, 0)
        Thread {
            val loadedMachine = repository.getMachine(machineId).get()
            UiThread.post {
                if (loadedMachine == null) {
                    Toast.makeText(this, R.string.machine_not_found, Toast.LENGTH_SHORT).show()
                    finish()
                    return@post
                }
                machine = loadedMachine
                machineNameText.text = loadedMachine.name
                amountText.text = getString(R.string.checkout_amount, loadedMachine.price)
                customerPresentation?.render(
                    CustomerDisplayState(
                        amountLabel = getString(R.string.checkout_amount, loadedMachine.price),
                        message = getString(R.string.customer_pay_prompt),
                        orderStatus = getString(R.string.customer_order_ready)
                    )
                )
            }
        }.start()
    }

    private fun completeCheckout() {
        val selectedMachine = machine ?: return
        val customerName = customerNameInput.text.toString().trim().ifEmpty { "Walk-in Customer" }
        val customerPhone = customerPhoneInput.text.toString().trim().ifEmpty {
            "9${System.currentTimeMillis().toString().takeLast(9)}"
        }
        val paymentMethod = paymentMethodSpinner.selectedItem.toString()
        val reference = "POS-${UUID.randomUUID().toString().take(8).uppercase()}"

        payButton.isEnabled = false
        customerPresentation?.render(
            CustomerDisplayState(
                amountLabel = getString(R.string.checkout_amount, selectedMachine.price),
                message = getString(R.string.customer_payment_processing),
                orderStatus = getString(R.string.customer_order_processing),
                paymentReference = getString(R.string.customer_reference, reference)
            )
        )

        Thread {
            val customerId = repository.saveWalkInCustomer(customerName, customerPhone).get().toInt()
            paymentGateway.createPaymentIntent(
                amount = selectedMachine.price,
                method = paymentMethod,
                orderReference = reference
            )
            val orderId = repository.createPaidOrder(
                machine = selectedMachine,
                customerId = customerId,
                userId = intent.getIntExtra(MachineListActivity.EXTRA_USER_ID, 0),
                paymentMethod = paymentMethod,
                paymentReference = reference
            ).get()

            UiThread.post {
                payButton.isEnabled = true
                customerPresentation?.render(
                    CustomerDisplayState(
                        amountLabel = getString(R.string.checkout_amount, selectedMachine.price),
                        message = getString(R.string.customer_payment_success),
                        orderStatus = getString(R.string.customer_order_complete),
                        paymentReference = getString(R.string.customer_reference, reference)
                    )
                )
                Toast.makeText(this, getString(R.string.checkout_success, orderId), Toast.LENGTH_SHORT).show()
                startActivity(
                    android.content.Intent(this, OrderHistoryActivity::class.java)
                        .putExtra(MachineListActivity.EXTRA_USER_ID, intent.getIntExtra(MachineListActivity.EXTRA_USER_ID, 0))
                        .putExtra(MachineListActivity.EXTRA_USER_NAME, intent.getStringExtra(MachineListActivity.EXTRA_USER_NAME))
                )
                finish()
            }
        }.start()
    }

    companion object {
        const val EXTRA_MACHINE_ID = "extra_machine_id"
    }
}
