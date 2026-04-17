import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/receipt_data.dart';
import '../services/open_external_url.dart';
import '../services/receipt_service.dart';

class ReceiptActions extends StatelessWidget {
  const ReceiptActions({
    super.key,
    required this.receipt,
  });

  final ReceiptData receipt;

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

  Future<void> _printSlip() async {
    final bytes = await ReceiptService.buildReceiptPdf(receipt);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'receipt-order-${receipt.order.id}',
    );
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
          onPressed: _printSlip,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print Slip'),
        ),
      ],
    );
  }
}
