package com.laundromat.pos.ui.machine

import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.laundromat.pos.R
import com.laundromat.pos.data.model.Machine
import com.laundromat.pos.data.model.MachineStatus
import com.laundromat.pos.data.repository.PosRepository
import com.laundromat.pos.ui.checkout.CheckoutActivity
import com.laundromat.pos.ui.common.UiThread
import com.laundromat.pos.ui.customer.CustomerSecondaryDisplayLauncher
import com.laundromat.pos.ui.history.OrderHistoryActivity

class MachineListActivity : AppCompatActivity() {
    private lateinit var repository: PosRepository
    private lateinit var welcomeText: TextView
    private lateinit var emptyText: TextView
    private lateinit var machineList: ListView
    private lateinit var historyButton: Button
    private var machines: List<Machine> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_machine_list)

        repository = PosRepository.get(applicationContext)
        welcomeText = findViewById(R.id.txtWelcome)
        emptyText = findViewById(R.id.txtEmptyMachines)
        machineList = findViewById(R.id.listMachines)
        historyButton = findViewById(R.id.btnViewHistory)

        val displayName = intent.getStringExtra(EXTRA_USER_NAME).orEmpty()
        welcomeText.text = getString(R.string.machine_welcome, displayName)

        historyButton.setOnClickListener {
            startActivity(
                Intent(this, OrderHistoryActivity::class.java)
                    .putExtra(EXTRA_USER_ID, intent.getIntExtra(EXTRA_USER_ID, 0))
                    .putExtra(EXTRA_USER_NAME, displayName)
            )
        }

        machineList.setOnItemClickListener { _, _, position, _ ->
            val machine = machines[position]
            startActivity(
                Intent(this, CheckoutActivity::class.java)
                    .putExtra(EXTRA_USER_ID, intent.getIntExtra(EXTRA_USER_ID, 0))
                    .putExtra(EXTRA_USER_NAME, displayName)
                    .putExtra(CheckoutActivity.EXTRA_MACHINE_ID, machine.id)
            )
        }
    }

    override fun onResume() {
        super.onResume()
        CustomerSecondaryDisplayLauncher.ensureSelfServiceOnSecondaryDisplay(this)
        loadMachines()
    }

    private fun loadMachines() {
        Thread {
            val results = repository.getMachines().get().filter { it.status == MachineStatus.AVAILABLE }
            UiThread.post {
                machines = results
                emptyText.text = if (results.isEmpty()) getString(R.string.machine_empty) else ""
                machineList.adapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_list_item_1,
                    results.map { machine ->
                        "${machine.name} • ${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toInt()} • ${machine.status}"
                    }
                )
            }
        }.start()
    }

    companion object {
        const val EXTRA_USER_ID = "extra_user_id"
        const val EXTRA_USER_NAME = "extra_user_name"
    }
}
