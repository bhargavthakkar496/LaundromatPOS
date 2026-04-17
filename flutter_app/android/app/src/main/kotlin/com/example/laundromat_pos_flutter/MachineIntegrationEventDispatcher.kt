package com.example.laundromat_pos_flutter

import java.util.concurrent.CopyOnWriteArraySet

interface MachineIntegrationEventListener {
    fun onEvent(event: Map<String, Any?>)
}

object MachineIntegrationEventDispatcher {
    private val listeners = CopyOnWriteArraySet<MachineIntegrationEventListener>()

    fun register(listener: MachineIntegrationEventListener) {
        listeners.add(listener)
    }

    fun unregister(listener: MachineIntegrationEventListener) {
        listeners.remove(listener)
    }

    fun dispatch(event: Map<String, Any?>) {
        listeners.forEach { listener ->
            listener.onEvent(event)
        }
    }
}
