package com.example.washpos_flutter

object MachineNativeEventPublisher {
    fun publish(payload: MachineEventPayload) {
        MachineIntegrationEventDispatcher.dispatch(payload.toMap())
    }

    fun publishStatusChanged(
        machineId: Int,
        status: String,
        currentOrderId: Int? = null,
        cycleStartedAt: String? = null,
        cycleEndsAt: String? = null,
        source: String = "sunmi-sdk",
        metadata: Map<String, Any?> = emptyMap(),
    ) {
        publish(
            MachineEventPayload(
                machineId = machineId,
                type = MachineIntegrationEvents.typeStatusChanged,
                status = status,
                currentOrderId = currentOrderId,
                cycleStartedAt = cycleStartedAt,
                cycleEndsAt = cycleEndsAt,
                source = source,
                metadata = metadata,
            ),
        )
    }

    fun publishReadyForPickup(
        machineId: Int,
        currentOrderId: Int? = null,
        source: String = "sunmi-sdk",
        metadata: Map<String, Any?> = emptyMap(),
    ) {
        publishStatusChanged(
            machineId = machineId,
            status = MachineStatuses.readyForPickup,
            currentOrderId = currentOrderId,
            source = source,
            metadata = metadata,
        )
    }
}
