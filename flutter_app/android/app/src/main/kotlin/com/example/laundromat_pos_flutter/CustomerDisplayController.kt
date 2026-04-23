package com.example.washpos_flutter

import android.app.Activity
import android.app.ActivityOptions
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Display

class CustomerDisplayController(
    private val activity: Activity,
) {
    fun openCustomerDisplay(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }

        val displayManager =
            activity.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
                ?: return false

        val targetDisplay = displayManager.displays
            .firstOrNull { display ->
                display.displayId != Display.DEFAULT_DISPLAY &&
                    display.isValid &&
                    display.state != Display.STATE_OFF
            } ?: return false

        val intent = CustomerDisplayActivity.createIntent(activity).apply {
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val options = ActivityOptions.makeBasic().apply {
            launchDisplayId = targetDisplay.displayId
        }
        activity.startActivity(intent, options.toBundle())
        return true
    }
}
