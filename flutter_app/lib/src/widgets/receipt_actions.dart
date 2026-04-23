import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/receipt_data.dart';
import '../services/open_external_url.dart';
import '../services/receipt_printer_service.dart';
import '../services/receipt_service.dart';
import '../services/taffeta_tag_service.dart';

class ReceiptActions extends StatefulWidget {
  const ReceiptActions({
    super.key,
    required this.receipt,
  });

  final ReceiptData receipt;

  @override
  State<ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends State<ReceiptActions> {
  bool _printing = false;
  bool _printingTags = false;
  bool _openingPrintSettings = false;

  ReceiptData get receipt => widget.receipt;

  bool get _showNativePrinterDiagnostics =>
      ReceiptPrinterService.supportsNativePrinterDiagnostics;

  bool get _showPrintSettings => ReceiptPrinterService.supportsPrintSettings;

  Future<void> _sendViaWhatsApp(BuildContext context) async {
    final phone = receipt.customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = Uri.encodeComponent(
      ReceiptService.buildWhatsAppMessage(receipt),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    if (!await openExternalUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  Future<void> _printSlip(BuildContext context) async {
    if (_printing) {
      return;
    }

    setState(() {
      _printing = true;
    });

    try {
      final result = await ReceiptPrinterService.printReceipt(receipt);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mode == ReceiptPrintMode.embedded
                  ? 'Receipt sent to the embedded printer${result.message == null || result.message!.isEmpty ? '' : ' via ${result.message}'}.'
                  : 'Opened print preview${result.message == null || result.message!.isEmpty ? '' : ' via ${result.message}'}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print receipt: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _printing = false;
        });
      }
    }
  }

  Future<void> _showPrinterDiagnostics(BuildContext context) async {
    final diagnostics = await ReceiptPrinterService.getDiagnostics();
    if (!context.mounted) {
      return;
    }

    final printServices = diagnostics.enabledPrintServices;
    final printServicesLabel =
        printServices.isEmpty ? 'None detected' : printServices.join('\n');

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Printer Diagnostics', style: textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _DiagnosticRow(
                        label: 'Manufacturer', value: diagnostics.manufacturer),
                    _DiagnosticRow(label: 'Brand', value: diagnostics.brand),
                    _DiagnosticRow(label: 'Model', value: diagnostics.model),
                    _DiagnosticRow(label: 'Device', value: diagnostics.device),
                    _DiagnosticRow(
                        label: 'Product', value: diagnostics.product),
                    _DiagnosticRow(
                      label: 'Sunmi printer SDK',
                      value: diagnostics.sunmiEmbeddedPrinterAvailable
                          ? 'Detected'
                          : 'Not detected',
                    ),
                    _DiagnosticRow(
                      label: 'HPRT USB printer',
                      value: diagnostics.hprtUsbPrinterDetected
                          ? 'Detected'
                          : 'Not detected',
                    ),
                    _DiagnosticRow(
                      label: 'USB printer details',
                      value: diagnostics.usbPrinter.summary,
                    ),
                    _DiagnosticRow(
                      label: 'Android print services',
                      value: printServicesLabel,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      diagnostics.hasAndroidPrintService
                          ? 'Print Slip now opens Android print preview first. Choose the attached printer there to continue printing.'
                          : 'No Android print service is enabled yet. Open Print Settings and enable one so the preview can send the receipt to the printer.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _printTaffetaTags(BuildContext context) async {
    if (_printingTags) {
      return;
    }

    setState(() {
      _printingTags = true;
    });

    try {
      final jobs = await Future<List<TaffetaTagPrintJob>>(
        () => TaffetaTagService.buildPrintJobs(receipt),
      );
      final result = await ReceiptPrinterService.printTaffetaTags(receipt);
      if (context.mounted) {
        final usedFallbackManifest = receipt.order.garmentItems.isEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.mode == ReceiptPrintMode.embedded
                  ? 'Started printing ${jobs.length} taffeta tag${jobs.length == 1 ? '' : 's'} on the embedded printer${usedFallbackManifest ? ' using a default order-level tag' : ''}.'
                  : 'Opened print preview for ${jobs.length} taffeta tag${jobs.length == 1 ? '' : 's'}${usedFallbackManifest ? ' using a default order-level tag' : ''}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is PlatformException &&
                      error.code == 'hprt_taffeta_printer_unavailable'
                  ? 'Native HPRT tag printing is not available on this device right now. Check Printer Diagnostics and confirm the USB printer is detected.'
                  : 'Could not print taffeta tags: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _printingTags = false;
        });
      }
    }
  }

  Future<void> _openPrintSettings(BuildContext context) async {
    if (_openingPrintSettings) {
      return;
    }

    setState(() {
      _openingPrintSettings = true;
    });

    try {
      final opened = await ReceiptPrinterService.openPrintSettings();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Opened Android print settings.'
                  : 'Could not open print settings on this device.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _openingPrintSettings = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => _sendViaWhatsApp(context),
          icon: const Icon(Icons.message_outlined),
          label: const Text('Send Receipt by WhatsApp'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _printing ? null : () => _printSlip(context),
          icon: const Icon(Icons.print_outlined),
          label: Text(_printing ? 'Printing...' : 'Print Slip'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _printingTags ? null : () => _printTaffetaTags(context),
          icon: const Icon(Icons.qr_code_2_outlined),
          label: Text(
            _printingTags ? 'Building Tags...' : 'Print Taffeta Tags',
          ),
        ),
        if (_showNativePrinterDiagnostics) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showPrinterDiagnostics(context),
            icon: const Icon(Icons.info_outline),
            label: const Text('Printer Diagnostics'),
          ),
        ],
        if (_showPrintSettings) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _openingPrintSettings ? null : () => _openPrintSettings(context),
            icon: const Icon(Icons.settings_outlined),
            label: Text(
              _openingPrintSettings
                  ? 'Opening Print Settings...'
                  : 'Open Print Settings',
            ),
          ),
        ],
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
