package com.example.washpos_flutter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MachineIntegrationBridge(
    private val context: Context,
    messenger: BinaryMessenger,
    private val workflowHandler: MachineWorkflowHandler = BroadcastMachineWorkflowHandler(),
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel =
        MethodChannel(messenger, MachineIntegrationChannels.methodChannelName)
    private val eventChannel =
        EventChannel(messenger, MachineIntegrationChannels.eventChannelName)

    private var eventSink: EventChannel.EventSink? = null
    private val listener = object : MachineIntegrationEventListener {
        override fun onEvent(event: Map<String, Any?>) {
            eventSink?.success(event)
        }
    }
    private val receiver = MachineIntegrationEventReceiver()
    private var receiverRegistered = false

    fun attach() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        MachineIntegrationEventDispatcher.register(listener)
        MachineIntegrationBroadcasts.registerMachineEventReceiver(context, receiver)
        receiverRegistered = true
    }

    fun detach() {
        MachineIntegrationEventDispatcher.unregister(listener)
        if (receiverRegistered) {
            context.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "startCycle" -> {
                val machineId = call.argument<Int>("machineId")
                val machineType = call.argument<String>("machineType")
                val orderId = call.argument<Int>("orderId")
                val startedAt = call.argument<String>("startedAt")
                val endsAt = call.argument<String>("endsAt")

                if (machineId == null || machineType == null || orderId == null ||
                    startedAt == null || endsAt == null
                ) {
                    result.error(
                        "bad_args",
                        "startCycle requires machineId, machineType, orderId, startedAt, and endsAt",
                        null,
                    )
                    return
                }

                workflowHandler.startCycle(
                    context = context,
                    request = StartCycleRequest(
                        machineId = machineId,
                        machineType = machineType,
                        orderId = orderId,
                        startedAt = startedAt,
                        endsAt = endsAt,
                    ),
                )
                result.success(null)
            }

            "clearMachine" -> {
                val machineId = call.argument<Int>("machineId")
                if (machineId == null) {
                    result.error("bad_args", "clearMachine requires machineId", null)
                    return
                }

                workflowHandler.clearMachine(
                    context = context,
                    machineId = machineId,
                )
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
