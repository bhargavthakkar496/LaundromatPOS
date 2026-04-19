package com.example.washpos_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build

object MachineIntegrationBroadcasts {
    const val actionMachineEvent = "com.washpos.app.MACHINE_EVENT"
    const val actionStartCycle = "com.washpos.app.MACHINE_START_CYCLE"
    const val actionClearMachine = "com.washpos.app.MACHINE_CLEAR"

    const val extraMachineId = "machineId"
    const val extraType = "type"
    const val extraStatus = "status"
    const val extraCurrentOrderId = "currentOrderId"
    const val extraCycleStartedAt = "cycleStartedAt"
    const val extraCycleEndsAt = "cycleEndsAt"
    const val extraClearOrderAssignment = "clearOrderAssignment"
    const val extraClearCycleWindow = "clearCycleWindow"
    const val extraSource = "source"
    const val extraMachineType = "machineType"
    const val extraOrderId = "orderId"

    fun registerMachineEventReceiver(
        context: Context,
        receiver: BroadcastReceiver,
    ) {
        val filter = IntentFilter(actionMachineEvent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(receiver, filter)
        }
    }

    fun toPayload(intent: Intent): MachineEventPayload? {
        if (intent.action != actionMachineEvent) {
            return null
        }

        val machineId = intent.getIntExtra(extraMachineId, -1)
        if (machineId == -1) {
            return null
        }

        val metadata = mutableMapOf<String, Any?>()
        intent.extras?.keySet()?.forEach { key ->
            if (key !in handledKeys) {
                metadata[key] = intent.extras?.get(key)
            }
        }

        return MachineEventPayload(
            machineId = machineId,
            type = intent.getStringExtra(extraType)
                ?: MachineIntegrationEvents.typeTelemetry,
            status = intent.getStringExtra(extraStatus),
            currentOrderId = intent.extras?.get(extraCurrentOrderId) as? Int,
            cycleStartedAt = intent.getStringExtra(extraCycleStartedAt),
            cycleEndsAt = intent.getStringExtra(extraCycleEndsAt),
            clearOrderAssignment = intent.getBooleanExtra(extraClearOrderAssignment, false),
            clearCycleWindow = intent.getBooleanExtra(extraClearCycleWindow, false),
            source = intent.getStringExtra(extraSource) ?: "android-broadcast",
            metadata = metadata,
        )
    }

    private val handledKeys = setOf(
        extraMachineId,
        extraType,
        extraStatus,
        extraCurrentOrderId,
        extraCycleStartedAt,
        extraCycleEndsAt,
        extraClearOrderAssignment,
        extraClearCycleWindow,
        extraSource,
    )
}
