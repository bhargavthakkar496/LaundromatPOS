import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sunmi_printer_plus/column_maker.dart';
import 'package:flutter_sunmi_printer_plus/enums.dart';
import 'package:flutter_sunmi_printer_plus/flutter_sunmi_printer_plus.dart';
import 'package:flutter_sunmi_printer_plus/sunmi_style.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_data.dart';
import 'receipt_service.dart';
import 'taffeta_tag_service.dart';

enum ReceiptPrintMode {
  embedded,
  direct,
  systemPreview,
}

class ReceiptPrintResult {
  const ReceiptPrintResult({
    required this.mode,
    this.message,
  });

  final ReceiptPrintMode mode;
  final String? message;
}

class ReceiptUsbPrinterDiagnostics {
  const ReceiptUsbPrinterDiagnostics({
    required this.detected,
    required this.deviceId,
    required this.vendorId,
    required this.productId,
    required this.manufacturerName,
    required this.productName,
  });

  static const empty = ReceiptUsbPrinterDiagnostics(
    detected: false,
    deviceId: null,
    vendorId: null,
    productId: null,
    manufacturerName: null,
    productName: null,
  );

  factory ReceiptUsbPrinterDiagnostics.fromMap(
    Map<Object?, Object?>? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return empty;
    }

    return ReceiptUsbPrinterDiagnostics(
      detected: raw['detected'] as bool? ?? false,
      deviceId: raw['deviceId'] as int?,
      vendorId: raw['vendorId'] as int?,
      productId: raw['productId'] as int?,
      manufacturerName: raw['manufacturerName'] as String?,
      productName: raw['productName'] as String?,
    );
  }

  final bool detected;
  final int? deviceId;
  final int? vendorId;
  final int? productId;
  final String? manufacturerName;
  final String? productName;

  String get summary {
    if (!detected) {
      return 'Not detected';
    }

    final parts = <String>[];
    if (manufacturerName != null && manufacturerName!.isNotEmpty) {
      parts.add(manufacturerName!);
    }
    if (productName != null && productName!.isNotEmpty) {
      parts.add(productName!);
    }
    if (vendorId != null || productId != null) {
      parts.add(
        'VID:${vendorId?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? '----'} '
        'PID:${productId?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? '----'}',
      );
    }
    return parts.isEmpty ? 'Detected' : parts.join(' • ');
  }
}

class ReceiptPrinterDiagnostics {
  const ReceiptPrinterDiagnostics({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.device,
    required this.product,
    required this.sunmiEmbeddedPrinterAvailable,
    required this.hprtUsbPrinterDetected,
    required this.usbPrinter,
    required this.enabledPrintServices,
  });

  factory ReceiptPrinterDiagnostics.fromMap(Map<Object?, Object?> raw) {
    return ReceiptPrinterDiagnostics(
      manufacturer: raw['manufacturer'] as String? ?? 'unknown',
      brand: raw['brand'] as String? ?? 'unknown',
      model: raw['model'] as String? ?? 'unknown',
      device: raw['device'] as String? ?? 'unknown',
      product: raw['product'] as String? ?? 'unknown',
      sunmiEmbeddedPrinterAvailable:
          raw['sunmiEmbeddedPrinterAvailable'] as bool? ?? false,
      hprtUsbPrinterDetected: raw['hprtUsbPrinterDetected'] as bool? ?? false,
      usbPrinter: ReceiptUsbPrinterDiagnostics.fromMap(
        raw['usbPrinter'] as Map<Object?, Object?>?,
      ),
      enabledPrintServices:
          (raw['enabledPrintServices'] as List<dynamic>? ?? [])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  final String manufacturer;
  final String brand;
  final String model;
  final String device;
  final String product;
  final bool sunmiEmbeddedPrinterAvailable;
  final bool hprtUsbPrinterDetected;
  final ReceiptUsbPrinterDiagnostics usbPrinter;
  final List<String> enabledPrintServices;

  bool get hasAndroidPrintService => enabledPrintServices.isNotEmpty;
  bool get hasEmbeddedPrinterPath =>
      sunmiEmbeddedPrinterAvailable || hprtUsbPrinterDetected;
}

class ReceiptPrinterService {
  static const MethodChannel _channel =
      MethodChannel('washpos/receipt_printer');
  static const _windowsPrinterUrlKey = 'windows_receipt_printer_url_v1';
  static const _windowsPrinterNameKey = 'windows_receipt_printer_name_v1';
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static bool get supportsNativePrinterDiagnostics =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get supportsPrintSettings => supportsNativePrinterDiagnostics;

  static bool get supportsPrinterSelection =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<bool> openPrintSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('openPrintSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<ReceiptPrintResult> printReceipt(
    ReceiptData receipt, {
    Locale locale = const Locale('en'),
  }) async {
    final diagnostics = await getDiagnostics();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final printerName = await _printPdfDirectToWindowsPrinter(
        bytes: await ReceiptService.buildReceiptPdf(receipt, locale: locale),
        jobName: 'receipt-order-${receipt.order.id}',
        format: PdfPageFormat.roll80,
      );
      return ReceiptPrintResult(
        mode: ReceiptPrintMode.direct,
        message: printerName,
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _printPdfPreview(receipt, locale: locale);
      return ReceiptPrintResult(
        mode: ReceiptPrintMode.systemPreview,
        message: diagnostics.enabledPrintServices.isEmpty
            ? 'Android print preview'
            : diagnostics.enabledPrintServices.join(', '),
      );
    }

    if (diagnostics.sunmiEmbeddedPrinterAvailable) {
      try {
        await _printWithEmbeddedPrinter(receipt, locale: locale);
        return const ReceiptPrintResult(mode: ReceiptPrintMode.embedded);
      } on MissingPluginException {
        // Continue to the final no-path error below.
      } on PlatformException {
        // Continue to the final no-path error below.
      }
    }

    await _printPdfPreview(receipt, locale: locale);
    return const ReceiptPrintResult(
      mode: ReceiptPrintMode.systemPreview,
      message: 'system print dialog',
    );
  }

  static Future<ReceiptPrintResult> printTaffetaTags(
    ReceiptData receipt,
  ) async {
    final jobs = await Future<List<TaffetaTagPrintJob>>(
      () => TaffetaTagService.buildPrintJobs(receipt),
    );
    if (jobs.isEmpty) {
      throw PlatformException(
        code: 'no_taffeta_tags',
        message: 'No garment pieces are available for tag printing.',
      );
    }

    final diagnostics = await getDiagnostics();

    if (diagnostics.sunmiEmbeddedPrinterAvailable) {
      try {
        await _printTaffetaTagsWithEmbeddedPrinter(receipt, jobs);
        return ReceiptPrintResult(
          mode: ReceiptPrintMode.embedded,
          message: '${jobs.length} tag${jobs.length == 1 ? '' : 's'}',
        );
      } on MissingPluginException {
        // Continue to HPRT or fail-fast below.
      } on PlatformException {
        // Continue to HPRT or fail-fast below.
      }
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      if (diagnostics.hprtUsbPrinterDetected) {
        final details = await _printTaffetaTagsWithHprt(receipt, jobs);
        return ReceiptPrintResult(
          mode: ReceiptPrintMode.embedded,
          message: details == null || details.isEmpty
              ? '${jobs.length} tag${jobs.length == 1 ? '' : 's'}'
              : 'HPRT USB',
        );
      }

      throw PlatformException(
        code: 'hprt_taffeta_printer_unavailable',
        message:
            'Taffeta tags require the native HPRT USB printer path on Android, but no HPRT printer was detected. Android print preview was skipped intentionally.',
        details: {
          'manufacturer': diagnostics.manufacturer,
          'brand': diagnostics.brand,
          'model': diagnostics.model,
          'device': diagnostics.device,
          'product': diagnostics.product,
          'hprtUsbPrinterDetected': diagnostics.hprtUsbPrinterDetected,
          'sunmiEmbeddedPrinterAvailable':
              diagnostics.sunmiEmbeddedPrinterAvailable,
          'enabledPrintServices': diagnostics.enabledPrintServices,
        },
      );
    }

    final bytes = await TaffetaTagService.buildTagsPdf(receipt, jobs);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final printerName = await _printPdfDirectToWindowsPrinter(
        bytes: bytes,
        jobName: 'taffeta-tags-order-${receipt.order.id}',
        format: TaffetaTagService.pdfPageFormat,
      );
      return ReceiptPrintResult(
        mode: ReceiptPrintMode.direct,
        message: printerName,
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'taffeta-tags-order-${receipt.order.id}',
    );
    return ReceiptPrintResult(
      mode: ReceiptPrintMode.systemPreview,
      message: '${jobs.length} tag${jobs.length == 1 ? '' : 's'}',
    );
  }

  static Future<ReceiptPrinterDiagnostics> getDiagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const ReceiptPrinterDiagnostics(
        manufacturer: 'non-android',
        brand: 'non-android',
        model: 'non-android',
        device: 'non-android',
        product: 'non-android',
        sunmiEmbeddedPrinterAvailable: false,
        hprtUsbPrinterDetected: false,
        usbPrinter: ReceiptUsbPrinterDiagnostics.empty,
        enabledPrintServices: [],
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPrinterDiagnostics',
      );
      if (result == null) {
        return const ReceiptPrinterDiagnostics(
          manufacturer: 'unknown',
          brand: 'unknown',
          model: 'unknown',
          device: 'unknown',
          product: 'unknown',
          sunmiEmbeddedPrinterAvailable: false,
          hprtUsbPrinterDetected: false,
          usbPrinter: ReceiptUsbPrinterDiagnostics.empty,
          enabledPrintServices: [],
        );
      }
      return ReceiptPrinterDiagnostics.fromMap(result);
    } on MissingPluginException {
      return const ReceiptPrinterDiagnostics(
        manufacturer: 'unknown',
        brand: 'unknown',
        model: 'unknown',
        device: 'unknown',
        product: 'unknown',
        sunmiEmbeddedPrinterAvailable: false,
        hprtUsbPrinterDetected: false,
        usbPrinter: ReceiptUsbPrinterDiagnostics.empty,
        enabledPrintServices: [],
      );
    } on PlatformException {
      return const ReceiptPrinterDiagnostics(
        manufacturer: 'unknown',
        brand: 'unknown',
        model: 'unknown',
        device: 'unknown',
        product: 'unknown',
        sunmiEmbeddedPrinterAvailable: false,
        hprtUsbPrinterDetected: false,
        usbPrinter: ReceiptUsbPrinterDiagnostics.empty,
        enabledPrintServices: [],
      );
    }
  }

  static Future<List<Printer>> getAvailableWindowsPrinters() async {
    if (!supportsPrinterSelection) {
      return const [];
    }
    final printers = await Printing.listPrinters();
    printers.sort((left, right) {
      if (left.isDefault && !right.isDefault) {
        return -1;
      }
      if (!left.isDefault && right.isDefault) {
        return 1;
      }
      return left.name.compareTo(right.name);
    });
    return printers.where((printer) => printer.isAvailable).toList();
  }

  static Future<Printer?> getSelectedWindowsPrinter() async {
    if (!supportsPrinterSelection) {
      return null;
    }

    final printers = await getAvailableWindowsPrinters();
    if (printers.isEmpty) {
      return null;
    }

    final savedUrl = await _preferences.getString(_windowsPrinterUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      for (final printer in printers) {
        if (printer.url == savedUrl) {
          return printer;
        }
      }
    }

    final preferred = _preferredWindowsPrinter(printers);
    if (preferred != null) {
      await _saveWindowsPrinter(preferred);
    }
    return preferred;
  }

  static Future<Printer?> chooseWindowsPrinter(BuildContext context) async {
    if (!supportsPrinterSelection) {
      return null;
    }

    final printer = await Printing.pickPrinter(
      context: context,
      title: 'Select Receipt Printer',
    );
    if (printer == null) {
      return null;
    }

    await _saveWindowsPrinter(printer);
    return printer;
  }

  static Future<void> _saveWindowsPrinter(Printer printer) async {
    await _preferences.setString(_windowsPrinterUrlKey, printer.url);
    await _preferences.setString(_windowsPrinterNameKey, printer.name);
  }

  static Printer? _preferredWindowsPrinter(List<Printer> printers) {
    if (printers.isEmpty) {
      return null;
    }

    for (final printer in printers) {
      if (_looksLikeReceiptPrinter(printer)) {
        return printer;
      }
    }

    for (final printer in printers) {
      if (printer.isDefault) {
        return printer;
      }
    }

    return printers.first;
  }

  static bool _looksLikeReceiptPrinter(Printer printer) {
    final descriptor = [
      printer.name,
      printer.model ?? '',
      printer.comment ?? '',
    ].join(' ').toLowerCase();
    return descriptor.contains('pos') ||
        descriptor.contains('thermal') ||
        descriptor.contains('receipt') ||
        descriptor.contains('hprt') ||
        descriptor.contains('xprinter') ||
        descriptor.contains('80');
  }

  static Future<String> _printPdfDirectToWindowsPrinter({
    required Uint8List bytes,
    required String jobName,
    required PdfPageFormat format,
  }) async {
    final printer = await getSelectedWindowsPrinter();
    if (printer == null) {
      throw PlatformException(
        code: 'windows_printer_unavailable',
        message:
            'No Windows receipt printer is configured. Use Select Printer to choose the attached USB receipt printer.',
      );
    }

    final printed = await Printing.directPrintPdf(
      printer: printer,
      onLayout: (_) async => bytes,
      name: jobName,
      format: format,
      dynamicLayout: false,
      usePrinterSettings: true,
    );

    if (!printed) {
      throw PlatformException(
        code: 'windows_direct_print_failed',
        message:
            'Windows could not complete the print job for ${printer.name}. Check that the printer is online and has paper.',
      );
    }

    return printer.name;
  }

  static Future<void> _printWithEmbeddedPrinter(
    ReceiptData receipt, {
    Locale locale = const Locale('en'),
  }) async {
    final connected = await SunmiPrinter.initPrinter() ?? false;
    if (!connected) {
      throw PlatformException(
        code: 'sunmi_unavailable',
        message: 'Embedded printer is not connected.',
      );
    }

    await SunmiPrinter.printText(
      content: 'WashPOS',
      style: SunmiStyle(
        fontSize: 30,
        bold: true,
        align: SunmiPrintAlign.CENTER,
      ),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: 'Payment Receipt',
      style: SunmiStyle(
        fontSize: 18,
        align: SunmiPrintAlign.CENTER,
      ),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printTable(
      cols: [
        ColumnMaker(text: 'Order', width: 4),
        ColumnMaker(
          text: '#${receipt.order.id}',
          width: 8,
          align: SunmiPrintAlign.RIGHT,
        ),
      ],
    );
    await SunmiPrinter.printTable(
      cols: [
        ColumnMaker(text: 'Date', width: 4),
        ColumnMaker(
          text: ReceiptService.formatReceiptDate(receipt.order.timestamp),
          width: 8,
          align: SunmiPrintAlign.RIGHT,
        ),
      ],
    );
    await SunmiPrinter.printText(
      content: 'Customer',
      style: SunmiStyle(fontSize: 18, bold: true),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: receipt.customer.fullName,
      style: SunmiStyle(fontSize: 18),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printTable(
      cols: [
        ColumnMaker(text: 'Phone', width: 4),
        ColumnMaker(
          text: receipt.customer.phone,
          width: 8,
          align: SunmiPrintAlign.RIGHT,
        ),
      ],
    );
    await SunmiPrinter.printText(
      content: 'Machine',
      style: SunmiStyle(fontSize: 18, bold: true),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: receipt.machine.name,
      style: SunmiStyle(fontSize: 18),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: ReceiptService.describeReceiptService(receipt),
      style: SunmiStyle(fontSize: 18),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printTable(
      cols: [
        ColumnMaker(text: 'Payment', width: 4),
        ColumnMaker(
          text: receipt.order.paymentMethod,
          width: 8,
          align: SunmiPrintAlign.RIGHT,
        ),
      ],
    );
    await SunmiPrinter.printText(
      content: 'Reference',
      style: SunmiStyle(fontSize: 18, bold: true),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: receipt.order.paymentReference,
      style: SunmiStyle(fontSize: 18),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: '--------------------------------',
      style: SunmiStyle(fontSize: 18),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printTable(
      cols: [
        ColumnMaker(text: 'Amount Paid', width: 7),
        ColumnMaker(
          text: ReceiptService.buildPrinterTextReceipt(
            receipt,
            locale: locale,
          ).split('\n').firstWhere(
                (line) => line.startsWith('Amount Paid:'),
                orElse: () => 'Amount Paid:',
              ).replaceFirst('Amount Paid: ', ''),
          width: 5,
          align: SunmiPrintAlign.RIGHT,
        ),
      ],
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: 'Thank you for your payment.',
      style: SunmiStyle(fontSize: 18, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(
      content: 'Please keep this slip for your records.',
      style: SunmiStyle(fontSize: 18, align: SunmiPrintAlign.CENTER),
    );
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.feedPaper();
  }

  static Future<void> _printPdfPreview(
    ReceiptData receipt, {
    Locale locale = const Locale('en'),
  }) async {
    final bytes = await ReceiptService.buildReceiptPdf(receipt, locale: locale);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'receipt-order-${receipt.order.id}',
    );
  }

  static Future<void> _printTaffetaTagsWithEmbeddedPrinter(
    ReceiptData receipt,
    List<TaffetaTagPrintJob> jobs,
  ) async {
    final connected = await SunmiPrinter.initPrinter() ?? false;
    if (!connected) {
      throw PlatformException(
        code: 'sunmi_unavailable',
        message: 'Embedded printer is not connected.',
      );
    }

    for (final job in jobs) {
      await SunmiPrinter.printText(
        content: 'WashPOS Tag',
        style: SunmiStyle(
          fontSize: 24,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printQr(
        data: job.qrPayload,
        align: SunmiPrintAlign.CENTER,
        size: 5,
      );
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText(
        content: receipt.customer.fullName,
        style: SunmiStyle(fontSize: 20, bold: true),
      );
      await SunmiPrinter.printText(
        content: receipt.customer.phone,
        style: SunmiStyle(fontSize: 18),
      );
      await SunmiPrinter.printText(
        content: 'Order #${receipt.order.id}',
        style: SunmiStyle(fontSize: 18),
      );
      await SunmiPrinter.printText(
        content: 'Piece ${job.pieceLabel}',
        style: SunmiStyle(fontSize: 18),
      );
      await SunmiPrinter.printText(
        content: job.garmentLabel,
        style: SunmiStyle(fontSize: 18),
      );
      await SunmiPrinter.printText(
        content: job.selectedServices.join(', '),
        style: SunmiStyle(fontSize: 16),
      );
      await SunmiPrinter.printText(
        content: job.tagId,
        style: SunmiStyle(fontSize: 16, bold: true),
      );
      await SunmiPrinter.lineWrap(2);
    }
    await SunmiPrinter.feedPaper();
  }

  static Future<Map<Object?, Object?>?> _printTaffetaTagsWithHprt(
    ReceiptData receipt,
    List<TaffetaTagPrintJob> jobs,
  ) async {
    return _channel.invokeMethod<Map<Object?, Object?>>(
      'printHprtTaffetaTags',
      {
        'customerName': receipt.customer.fullName,
        'customerPhone': receipt.customer.phone,
        'jobs': jobs
            .map(
              (job) => {
                'tagId': job.tagId,
                'pieceNumber': job.pieceNumber,
                'totalPieces': job.totalPieces,
                'garmentLabel': job.garmentLabel,
                'selectedServices': job.selectedServices,
                'qrPayload': job.qrPayload,
              },
            )
            .toList(),
      },
    );
  }
}
