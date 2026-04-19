package com.washpos.app.ui.customer

import android.app.Activity
import android.app.ActivityOptions
import android.content.Intent
import android.hardware.display.DisplayManager

object CustomerSecondaryDisplayLauncher {
    fun ensureSelfServiceOnSecondaryDisplay(activity: Activity) {
        if (activity is CustomerSelfServiceActivity) {
            return
        }

        val displayManager = activity.getSystemService(Activity.DISPLAY_SERVICE) as DisplayManager
        val currentDisplayId = activity.display?.displayId
        val secondaryDisplay = displayManager.displays.firstOrNull { display ->
            display.displayId != currentDisplayId
        } ?: return

        val intent = Intent(activity, CustomerSelfServiceActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val options = ActivityOptions.makeBasic().apply {
            launchDisplayId = secondaryDisplay.displayId
        }

        runCatching {
            activity.startActivity(intent, options.toBundle())
        }
    }
}
