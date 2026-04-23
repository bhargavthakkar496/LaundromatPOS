package com.example.washpos_flutter

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset

class HprtPrinterController(
    private val activity: Activity,
) {
    companion object {
        private const val usbPermissionAction =
            "com.example.washpos_flutter.HPRT_USB_PERMISSION"
        private const val bulkTransferTimeoutMs = 5_000
        private const val maxBulkChunkBytes = 2_048
        private val printerCharset: Charset = Charset.forName("CP437")
    }

    private data class PendingPrintRequest(
        val payload: ByteArray,
        val result: MethodChannel.Result,
    )

    private data class UsbPrinterTarget(
        val device: UsbDevice,
        val printerInterface: UsbInterface,
        val outEndpoint: UsbEndpoint,
    )

    private val usbManager =
        activity.getSystemService(Context.USB_SERVICE) as? UsbManager
    private val permissionIntent: PendingIntent by lazy {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        PendingIntent.getBroadcast(
            activity,
            0,
            Intent(usbPermissionAction).setPackage(activity.packageName),
            flags,
        )
    }

    private var pendingPrintRequest: PendingPrintRequest? = null
    private var receiverRegistered = false

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                usbPermissionAction -> {
                    val request = pendingPrintRequest ?: return
                    val device = intent.parcelableExtra<UsbDevice>(
                        UsbManager.EXTRA_DEVICE,
                    )
                    val granted = intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED,
                        false,
                    )
                    pendingPrintRequest = null
                    if (!granted || device == null) {
                        request.result.error(
                            "hprt_permission_denied",
                            "USB printer permission was denied.",
                            null,
                        )
                        return
                    }
                    val target = findUsbPrinterTarget(device.deviceId)
                    if (target == null) {
                        request.result.error(
                            "hprt_no_usb_endpoint",
                            "The connected USB printer does not expose a writable endpoint.",
                            mapOf(
                                "deviceId" to device.deviceId,
                                "vendorId" to device.vendorId,
                                "productId" to device.productId,
                            ),
                        )
                        return
                    }
                    printToUsbDevice(
                        target = target,
                        payload = request.payload,
                        result = request.result,
                    )
                }

                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    pendingPrintRequest = null
                }
            }
        }
    }

    init {
        registerReceiverIfNeeded()
    }

    fun detach() {
        if (!receiverRegistered) {
            return
        }
        activity.unregisterReceiver(usbReceiver)
        receiverRegistered = false
    }

    fun hasUsbPrinter(): Boolean = findUsbPrinterTarget() != null

    fun getUsbPrinterDiagnostics(): Map<String, Any?> {
        val target = findUsbPrinterTarget()
        if (target == null) {
            return mapOf(
                "detected" to false,
            )
        }

        return mapOf(
            "detected" to true,
            "deviceId" to target.device.deviceId,
            "vendorId" to target.device.vendorId,
            "productId" to target.device.productId,
            "manufacturerName" to target.device.manufacturerName,
            "productName" to target.device.productName,
            "interfaceClass" to target.printerInterface.interfaceClass,
            "interfaceSubclass" to target.printerInterface.interfaceSubclass,
            "interfaceProtocol" to target.printerInterface.interfaceProtocol,
        )
    }

    fun printReceiptText(
        receiptText: String,
        result: MethodChannel.Result,
    ) {
        printEscPosPayload(
            payload = buildEscPosPayload(receiptText),
            result = result,
        )
    }

    fun printTaffetaTags(
        customerName: String,
        customerPhone: String,
        jobs: List<Map<String, Any?>>,
        result: MethodChannel.Result,
    ) {
        if (jobs.isEmpty()) {
            result.error(
                "hprt_no_taffeta_jobs",
                "No taffeta tag jobs were provided.",
                null,
            )
            return
        }

        printEscPosPayload(
            payload = buildTaffetaEscPosPayload(
                customerName = customerName,
                customerPhone = customerPhone,
                jobs = jobs,
            ),
            result = result,
        )
    }

    private fun printEscPosPayload(
        payload: ByteArray,
        result: MethodChannel.Result,
    ) {
        val target = findUsbPrinterTarget()
        if (target == null) {
            result.error(
                "hprt_no_usb_printer",
                "No USB ESC/POS printer was detected.",
                null,
            )
            return
        }

        val device = target.device
        if (usbManager?.hasPermission(device) != true) {
            if (pendingPrintRequest != null) {
                result.error(
                    "hprt_busy",
                    "A previous USB permission request is still pending.",
                    null,
                )
                return
            }
            pendingPrintRequest = PendingPrintRequest(
                payload = payload,
                result = result,
            )
            usbManager?.requestPermission(device, permissionIntent)
            return
        }

        printToUsbDevice(
            target = target,
            payload = payload,
            result = result,
        )
    }

    private fun registerReceiverIfNeeded() {
        if (receiverRegistered) {
            return
        }
        val filter = IntentFilter().apply {
            addAction(usbPermissionAction)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(
                usbReceiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            @Suppress("DEPRECATION")
            activity.registerReceiver(usbReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun findUsbPrinterTarget(
        deviceId: Int? = null,
    ): UsbPrinterTarget? {
        val manager = usbManager ?: return null
        val devices = manager.deviceList.values
        for (device in devices) {
            if (deviceId != null && device.deviceId != deviceId) {
                continue
            }
            for (index in 0 until device.interfaceCount) {
                val intf: UsbInterface = device.getInterface(index)
                val outEndpoint = findBulkOutEndpoint(intf)
                if (outEndpoint == null) {
                    continue
                }
                val looksLikePrinter =
                    intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER ||
                        intf.interfaceSubclass == 1 ||
                        intf.interfaceProtocol == 2 ||
                        device.deviceClass == UsbConstants.USB_CLASS_PRINTER ||
                        device.productName?.contains("sol", ignoreCase = true) == true ||
                        device.productName?.contains("pos", ignoreCase = true) == true ||
                        device.productName?.contains("printer", ignoreCase = true) == true ||
                        device.manufacturerName?.contains("hprt", ignoreCase = true) == true ||
                        device.manufacturerName?.contains("printer", ignoreCase = true) == true
                if (looksLikePrinter) {
                    return UsbPrinterTarget(
                        device = device,
                        printerInterface = intf,
                        outEndpoint = outEndpoint,
                    )
                }
            }
        }
        return null
    }

    private fun findBulkOutEndpoint(
        printerInterface: UsbInterface,
    ): UsbEndpoint? {
        for (endpointIndex in 0 until printerInterface.endpointCount) {
            val endpoint = printerInterface.getEndpoint(endpointIndex)
            if (
                endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    endpoint.direction == UsbConstants.USB_DIR_OUT
            ) {
                return endpoint
            }
        }
        return null
    }

    private fun printToUsbDevice(
        target: UsbPrinterTarget,
        payload: ByteArray,
        result: MethodChannel.Result,
    ) {
        val manager = usbManager
        if (manager == null) {
            result.error(
                "hprt_usb_unavailable",
                "USB manager is unavailable on this device.",
                null,
            )
            return
        }

        val connection = manager.openDevice(target.device)
        if (connection == null) {
            result.error(
                "hprt_usb_open_failed",
                "The POS app could not open the USB printer connection.",
                mapOf(
                    "deviceId" to target.device.deviceId,
                    "vendorId" to target.device.vendorId,
                    "productId" to target.device.productId,
                ),
            )
            return
        }

        var claimed = false
        try {
            claimed = connection.claimInterface(target.printerInterface, true)
            if (!claimed) {
                result.error(
                    "hprt_claim_failed",
                    "The POS app could not claim the USB printer interface.",
                    mapOf(
                        "deviceId" to target.device.deviceId,
                        "interfaceId" to target.printerInterface.id,
                    ),
                )
                return
            }

            var offset = 0
            while (offset < payload.size) {
                val chunkLength = minOf(maxBulkChunkBytes, payload.size - offset)
                val chunk = payload.copyOfRange(offset, offset + chunkLength)
                val written = connection.bulkTransfer(
                    target.outEndpoint,
                    chunk,
                    chunk.size,
                    bulkTransferTimeoutMs,
                )
                if (written <= 0) {
                    result.error(
                        "hprt_bulk_transfer_failed",
                        "The USB printer did not accept the receipt data.",
                        mapOf(
                            "deviceId" to target.device.deviceId,
                            "vendorId" to target.device.vendorId,
                            "productId" to target.device.productId,
                            "bytesAttempted" to chunk.size,
                            "bytesWritten" to written,
                        ),
                    )
                    return
                }
                offset += written
            }

            result.success(
                mapOf(
                    "transport" to "usb-escpos",
                    "vendorId" to target.device.vendorId,
                    "productId" to target.device.productId,
                    "manufacturerName" to target.device.manufacturerName,
                    "productName" to target.device.productName,
                ),
            )
        } catch (error: Throwable) {
            result.error(
                "hprt_exception",
                error.message ?: "Unknown USB printer error.",
                mapOf(
                    "deviceId" to target.device.deviceId,
                    "vendorId" to target.device.vendorId,
                    "productId" to target.device.productId,
                    "errorType" to error::class.java.simpleName,
                ),
            )
        } finally {
            try {
                if (claimed) {
                    connection.releaseInterface(target.printerInterface)
                }
            } catch (_: Throwable) {
                // Best-effort cleanup only.
            }
            connection.close()
        }
    }

    private fun buildEscPosPayload(
        receiptText: String,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        val normalizedText = normalizeReceiptText(receiptText)

        // Reset printer state and force a known text/code page configuration.
        output.write(byteArrayOf(0x1B, 0x40))
        output.write(byteArrayOf(0x1B, 0x74, 0x00)) // ESC t 0 -> PC437
        output.write(byteArrayOf(0x1B, 0x61, 0x00)) // ESC a 0 -> left align
        output.write(byteArrayOf(0x1B, 0x21, 0x00)) // ESC ! 0 -> normal font
        output.write(byteArrayOf(0x1D, 0x21, 0x00)) // GS ! 0 -> normal size
        output.write(byteArrayOf(0x1B, 0x32)) // ESC 2 -> default line spacing
        output.write(byteArrayOf(0x1B, 0x4D, 0x00)) // ESC M 0 -> font A
        output.write(normalizedText.toByteArray(printerCharset))
        if (!normalizedText.endsWith("\r\n")) {
            output.write(byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()))
        }

        // Advance paper enough for manual tear on printers without an auto-cutter.
        output.write(byteArrayOf(0x1B, 0x64, 0x04))
        return output.toByteArray()
    }

    private fun buildTaffetaEscPosPayload(
        customerName: String,
        customerPhone: String,
        jobs: List<Map<String, Any?>>,
    ): ByteArray {
        val output = ByteArrayOutputStream()

        for ((index, job) in jobs.withIndex()) {
            val qrPayload = job["qrPayload"] as? String ?: continue

            output.write(byteArrayOf(0x1B, 0x40))
            output.write(byteArrayOf(0x1B, 0x74, 0x00))
            output.write(byteArrayOf(0x1B, 0x61, 0x01)) // center align
            output.write(byteArrayOf(0x1B, 0x21, 0x00))
            output.write(byteArrayOf(0x1D, 0x21, 0x00))
            output.write(byteArrayOf(0x1B, 0x32))
            output.write(byteArrayOf(0x1B, 0x4D, 0x00))
            output.write(byteArrayOf(0x1B, 0x45, 0x01))
            output.write(normalizeReceiptText(customerName).toByteArray(printerCharset))
            output.write(byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()))
            output.write(byteArrayOf(0x1B, 0x45, 0x00))
            output.write(normalizeReceiptText(customerPhone).toByteArray(printerCharset))
            output.write(byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()))
            output.write(byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()))

            appendQrCode(output, qrPayload)
            output.write(byteArrayOf('\r'.code.toByte(), '\n'.code.toByte()))
            output.write(byteArrayOf(0x1B, 0x64, if (index == jobs.lastIndex) 0x04 else 0x03))
        }

        return output.toByteArray()
    }

    private fun appendQrCode(
        output: ByteArrayOutputStream,
        data: String,
    ) {
        val qrBytes = data.toByteArray(Charsets.UTF_8)
        val storeLength = qrBytes.size + 3
        val pL = (storeLength and 0xFF).toByte()
        val pH = ((storeLength shr 8) and 0xFF).toByte()

        output.write(byteArrayOf(0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00))
        output.write(byteArrayOf(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x05))
        output.write(byteArrayOf(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31))
        output.write(byteArrayOf(0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30))
        output.write(qrBytes)
        output.write(byteArrayOf(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30))
    }

    private fun normalizeReceiptText(
        receiptText: String,
    ): String {
        return receiptText
            .replace('\u2022', '-')
            .replace("\r\n", "\n")
            .replace('\r', '\n')
            .replace(Regex("\n{3,}"), "\n\n\n")
            .map { character ->
                if (
                    character.code in 32..126 ||
                    character.code in 160..255 ||
                    character == '\n' ||
                    character == '\t'
                ) {
                    character
                } else {
                    '?'
                }
            }
            .joinToString(separator = "")
            .replace("\n", "\r\n")
    }
}

private inline fun <reified T> Intent.parcelableExtra(key: String): T? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableExtra(key, T::class.java)
    } else {
        @Suppress("DEPRECATION")
        getParcelableExtra(key)
    }
}
