package com.example.washpos_flutter

object MachineIntegrationEvents {
    const val typeStatusChanged = "STATUS_CHANGED"
    const val typeTelemetry = "TELEMETRY"
    const val typeLifecycle = "LIFECYCLE"
}

object MachineStatuses {
    const val available = "AVAILABLE"
    const val maintenance = "MAINTENANCE"
    const val inUse = "IN_USE"
    const val readyForPickup = "READY_FOR_PICKUP"
}

data class MachineEventPayload(
    val machineId: Int,
    val type: String = MachineIntegrationEvents.typeTelemetry,
    val status: String? = null,
    val currentOrderId: Int? = null,
    val cycleStartedAt: String? = null,
    val cycleEndsAt: String? = null,
    val clearOrderAssignment: Boolean = false,
    val clearCycleWindow: Boolean = false,
    val source: String = "android",
    val metadata: Map<String, Any?> = emptyMap(),
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "machineId" to machineId,
            "type" to type,
            "status" to status,
            "currentOrderId" to currentOrderId,
            "cycleStartedAt" to cycleStartedAt,
            "cycleEndsAt" to cycleEndsAt,
            "clearOrderAssignment" to clearOrderAssignment,
            "clearCycleWindow" to clearCycleWindow,
            "source" to source,
            "metadata" to metadata,
        )
    }
}
