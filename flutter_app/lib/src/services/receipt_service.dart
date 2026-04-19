import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/receipt_data.dart';

class ReceiptService {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String buildWhatsAppMessage(ReceiptData receipt) {
    final lines = [
      'WashPOS Receipt',
      'Order #${receipt.order.id}',
      'Customer: ${receipt.customer.fullName}',
      'Phone: ${receipt.customer.phone}',
      'Machine: ${receipt.machine.name}',
      'Type: ${receipt.machine.type} • ${receipt.machine.capacityKg}kg',
      'Amount: INR ${receipt.order.amount.toStringAsFixed(0)}',
      'Payment: ${receipt.order.paymentMethod}',
      'Reference: ${receipt.order.paymentReference}',
      'Date: ${_dateFormat.format(receipt.order.timestamp)}',
      'Status: ${receipt.order.paymentStatus}',
    ];

    return lines.join('\n');
  }

  static Future<Uint8List> buildReceiptPdf(ReceiptData receipt) async {
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'WashPOS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Payment Receipt',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 16),
              _row('Order', '#${receipt.order.id}'),
              _row('Date', _dateFormat.format(receipt.order.timestamp)),
              _row('Customer', receipt.customer.fullName),
              _row('Phone', receipt.customer.phone),
              _row('Machine', receipt.machine.name),
              _row(
                'Service',
                '${receipt.machine.type} • ${receipt.machine.capacityKg}kg',
              ),
              _row('Payment', receipt.order.paymentMethod),
              _row('Reference', receipt.order.paymentReference),
              pw.Divider(),
              _row(
                'Amount Paid',
                'INR ${receipt.order.amount.toStringAsFixed(0)}',
                bold: true,
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Thank you for your payment.',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Please keep this slip for your records.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 64,
            child: pw.Text(label, style: style),
          ),
          pw.Expanded(
            child: pw.Text(value, style: style),
          ),
        ],
      ),
    );
  }
}
