package com.washpos.app.ui.login

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.washpos.app.R
import com.washpos.app.data.repository.PosRepository
import com.washpos.app.ui.common.UiThread
import com.washpos.app.ui.customer.CustomerSelfServiceActivity
import com.washpos.app.ui.customer.CustomerSecondaryDisplayLauncher
import com.washpos.app.ui.machine.MachineListActivity

class LoginActivity : AppCompatActivity() {
    private lateinit var repository: PosRepository
    private lateinit var usernameInput: EditText
    private lateinit var pinInput: EditText
    private lateinit var helperText: TextView
    private lateinit var loginButton: Button
    private lateinit var selfServiceButton: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login)

        repository = PosRepository.get(applicationContext)
        usernameInput = findViewById(R.id.edtUsername)
        pinInput = findViewById(R.id.edtPin)
        helperText = findViewById(R.id.txtHelper)
        loginButton = findViewById(R.id.btnLogin)
        selfServiceButton = findViewById(R.id.btnSelfService)

        helperText.text = getString(R.string.demo_login_hint)
        loginButton.isEnabled = false
        selfServiceButton.isEnabled = false
        Thread {
            repository.seedDemoData().get()
            UiThread.post {
                loginButton.isEnabled = true
                selfServiceButton.isEnabled = true
                CustomerSecondaryDisplayLauncher.ensureSelfServiceOnSecondaryDisplay(this)
            }
        }.start()

        loginButton.setOnClickListener {
            attemptLogin()
        }

        selfServiceButton.setOnClickListener {
            startActivity(Intent(this, CustomerSelfServiceActivity::class.java))
        }
    }

    override fun onResume() {
        super.onResume()
        CustomerSecondaryDisplayLauncher.ensureSelfServiceOnSecondaryDisplay(this)
    }

    private fun attemptLogin() {
        val username = usernameInput.text.toString().trim()
        val pin = pinInput.text.toString().trim()
        if (username.isEmpty() || pin.isEmpty()) {
            Toast.makeText(this, R.string.login_validation_error, Toast.LENGTH_SHORT).show()
            return
        }

        loginButton.isEnabled = false
        helperText.text = getString(R.string.login_loading)

        Thread {
            val user = repository.login(username, pin).get()
            UiThread.post {
                loginButton.isEnabled = true
                if (user == null) {
                    helperText.text = getString(R.string.login_failed)
                } else {
                    startActivity(
                        Intent(this, MachineListActivity::class.java)
                            .putExtra(MachineListActivity.EXTRA_USER_ID, user.id)
                            .putExtra(MachineListActivity.EXTRA_USER_NAME, user.displayName)
                    )
                    finish()
                }
            }
        }.start()
    }
}
