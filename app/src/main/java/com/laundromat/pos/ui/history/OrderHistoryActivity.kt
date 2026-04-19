package com.washpos.app.ui.history

import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.washpos.app.R
import com.washpos.app.data.repository.PosRepository
import com.washpos.app.ui.common.UiThread
import com.washpos.app.ui.customer.CustomerSecondaryDisplayLauncher
import com.washpos.app.ui.machine.MachineListActivity

class OrderHistoryActivity : AppCompatActivity() {
    private lateinit var repository: PosRepository
    private lateinit var ordersList: ListView
    private lateinit var emptyText: TextView
    private lateinit var backButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_order_history)

        repository = PosRepository.get(applicationContext)
        ordersList = findViewById(R.id.listOrders)
        emptyText = findViewById(R.id.txtEmptyOrders)
        backButton = findViewById(R.id.btnBackToMachines)

        backButton.setOnClickListener {
            startActivity(
                Intent(this, MachineListActivity::class.java)
                    .putExtra(MachineListActivity.EXTRA_USER_ID, intent.getIntExtra(MachineListActivity.EXTRA_USER_ID, 0))
                    .putExtra(MachineListActivity.EXTRA_USER_NAME, intent.getStringExtra(MachineListActivity.EXTRA_USER_NAME))
            )
            finish()
        }
    }

    override fun onResume() {
        super.onResume()
        CustomerSecondaryDisplayLauncher.ensureSelfServiceOnSecondaryDisplay(this)
        loadOrders()
    }

    private fun loadOrders() {
        Thread {
            val orders = repository.getOrderHistory().get()
            UiThread.post {
                emptyText.text = if (orders.isEmpty()) getString(R.string.order_empty) else ""
                ordersList.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_list_item_1,
                    orders.map { detail ->
                        val customerName = detail.customer?.fullName ?: "Walk-in"
                        "${detail.machine.name} • ${customerName} • ${detail.order.paymentMethod} • INR ${detail.order.amount.toInt()} • ${detail.order.status}"
                    }
                )
            }
        }.start()
    }
}
