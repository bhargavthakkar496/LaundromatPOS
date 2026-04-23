package com.example.washpos_flutter

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class CustomerDisplayActivity : FlutterActivity() {
    companion object {
        fun createIntent(context: Context): Intent {
            return NewEngineIntentBuilder(CustomerDisplayActivity::class.java)
                .initialRoute("/customer-display")
                .build(context)
        }
    }
}
