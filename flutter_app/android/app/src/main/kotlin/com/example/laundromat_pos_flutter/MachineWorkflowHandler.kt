package com.example.laundromat_pos_flutter

import android.content.Context
import android.content.Intent

data class StartCycleRequest(
    val machineId: Int,
    val machineType: String,
    val orderId: Int,
    val startedAt: String,
    val endsAt: String,
)

interface MachineWorkflowHandler {
    fun startCycle(context: Context, request: StartCycleRequest)

    fun clearMachine(context: Context, machineId: Int)
}

class BroadcastMachineWorkflowHandler : MachineWorkflowHandler {
    override fun startCycle(context: Context, request: StartCycleRequest) {
        context.sendBroadcast(
            Intent(MachineIntegrationBroadcasts.actionStartCycle).apply {
                `package` = context.packageName
                putExtra(MachineIntegrationBroadcasts.extraMachineId, request.machineId)
                putExtra(MachineIntegrationBroadcasts.extraMachineType, request.machineType)
                putExtra(MachineIntegrationBroadcasts.extraOrderId, request.orderId)
                putExtra(
                    MachineIntegrationBroadcasts.extraCycleStartedAt,
                    request.startedAt,
                )
                putExtra(
                    MachineIntegrationBroadcasts.extraCycleEndsAt,
                    request.endsAt,
                )
            },
        )
    }

    override fun clearMachine(context: Context, machineId: Int) {
        context.sendBroadcast(
            Intent(MachineIntegrationBroadcasts.actionClearMachine).apply {
                `package` = context.packageName
                putExtra(MachineIntegrationBroadcasts.extraMachineId, machineId)
            },
        )
    }
}
