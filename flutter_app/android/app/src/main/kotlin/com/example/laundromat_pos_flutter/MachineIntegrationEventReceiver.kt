package com.example.laundromat_pos_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MachineIntegrationEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent == null) {
            return
        }
        val payload = MachineIntegrationBroadcasts.toPayload(intent) ?: return
        MachineIntegrationEventDispatcher.dispatch(payload.toMap())
    }
}
