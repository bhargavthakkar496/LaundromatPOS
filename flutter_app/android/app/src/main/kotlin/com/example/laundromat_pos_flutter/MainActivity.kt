package com.example.washpos_flutter

import android.content.Intent
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        private const val customerDisplayChannel = "washpos/customer_display"
        private const val receiptPrinterChannel = "washpos/receipt_printer"
        private const val sunmiPrinterPackage = "woyou.aidlservice.jiuiv5"
        private const val sunmiPrinterAction = "woyou.aidlservice.jiuiv5.IWoyouService"
    }

    private lateinit var customerDisplayController: CustomerDisplayController
    private lateinit var hprtPrinterController: HprtPrinterController
    private lateinit var machineIntegrationBridge: MachineIntegrationBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        customerDisplayController = CustomerDisplayController(this)
        hprtPrinterController = HprtPrinterController(this)
        machineIntegrationBridge = MachineIntegrationBridge(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        machineIntegrationBridge.attach()
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            customerDisplayChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCustomerDisplay" -> result.success(
                    customerDisplayController.openCustomerDisplay(),
                )
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            receiptPrinterChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isEmbeddedPrinterAvailable" -> {
                    result.success(isEmbeddedPrinterAvailable())
                }
                "getPrinterDiagnostics" -> {
                    result.success(getPrinterDiagnostics())
                }
                "printHprtReceiptText" -> {
                    val receiptText = call.argument<String>("receiptText")
                    if (receiptText.isNullOrBlank()) {
                        result.error(
                            "invalid_receipt_text",
                            "Receipt text is required for HPRT printing.",
                            null,
                        )
                    } else {
                        hprtPrinterController.printReceiptText(
                            receiptText = receiptText,
                            result = result,
                        )
                    }
                }
                "printHprtTaffetaTags" -> {
                    val customerName = call.argument<String>("customerName")
                    val customerPhone = call.argument<String>("customerPhone")
                    val jobs =
                        call.argument<List<Map<String, Any?>>>("jobs") ?: emptyList()
                    if (customerName.isNullOrBlank() || customerPhone.isNullOrBlank()) {
                        result.error(
                            "invalid_taffeta_customer",
                            "Customer name and phone are required for HPRT taffeta tag printing.",
                            null,
                        )
                    } else if (jobs.isEmpty()) {
                        result.error(
                            "invalid_taffeta_jobs",
                            "At least one taffeta tag job is required for HPRT printing.",
                            null,
                        )
                    } else {
                        hprtPrinterController.printTaffetaTags(
                            customerName = customerName,
                            customerPhone = customerPhone,
                            jobs = jobs,
                            result = result,
                        )
                    }
                }
                "openPrintSettings" -> {
                    result.success(openPrintSettings())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (::hprtPrinterController.isInitialized) {
            hprtPrinterController.detach()
        }
        if (::machineIntegrationBridge.isInitialized) {
            machineIntegrationBridge.detach()
        }
        super.onDestroy()
    }

    private fun isEmbeddedPrinterAvailable(): Boolean {
        val intent = Intent().apply {
            setPackage(sunmiPrinterPackage)
            action = sunmiPrinterAction
        }
        return packageManager.resolveService(intent, PackageManager.MATCH_DEFAULT_ONLY) != null
    }

    private fun getPrinterDiagnostics(): Map<String, Any?> {
        val enabledServicesSetting = Settings.Secure.getString(
            contentResolver,
            "enabled_print_services",
        )
        val enabledPrintServices = enabledServicesSetting
            ?.split(':')
            ?.mapNotNull { ComponentName.unflattenFromString(it)?.packageName }
            ?.distinct()
            ?: emptyList<String>()

        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "sunmiEmbeddedPrinterAvailable" to isEmbeddedPrinterAvailable(),
            "hprtUsbPrinterDetected" to hprtPrinterController.hasUsbPrinter(),
            "usbPrinter" to hprtPrinterController.getUsbPrinterDiagnostics(),
            "enabledPrintServices" to enabledPrintServices,
        )
    }

    private fun openPrintSettings(): Boolean {
        val intents = listOf(
            Intent(Settings.ACTION_PRINT_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )

        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }

        return false
    }
}
