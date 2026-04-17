package com.example.laundromat_pos_flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var machineIntegrationBridge: MachineIntegrationBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        machineIntegrationBridge = MachineIntegrationBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        machineIntegrationBridge.attach()
    }

    override fun onDestroy() {
        if (::machineIntegrationBridge.isInitialized) {
            machineIntegrationBridge.detach()
        }
        super.onDestroy()
    }
}
