import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order_history_item.dart';
import '../models/revenue.dart';

class RevenueReportService {
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  static Future<Uint8List> buildRevenueReportPdf({
    required RevenueSummary summary,
    required List<OrderHistoryItem> transactions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Map<String, String> filters,
  }) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'WashPOS Revenue Dashboard',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Report period: ${_dateFormat.format(rangeStart)} to ${_dateFormat.format(rangeEnd.subtract(const Duration(milliseconds: 1)))}',
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters.entries
                .where(
                    (entry) => entry.value != 'ALL' && entry.value.isNotEmpty)
                .map(
                  (entry) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text('${entry.key}: ${entry.value}'),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          _metricGrid(summary),
          pw.SizedBox(height: 18),
          _breakdownSection('Payment Breakdown', summary.paymentBreakdown),
          _breakdownSection('Service Breakdown', summary.serviceBreakdown),
          _breakdownSection(
              'Machine Type Breakdown', summary.machineTypeBreakdown),
          _breakdownSection('Top Machines', summary.topMachineBreakdown),
          pw.SizedBox(height: 18),
          pw.Text(
            'Transactions',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: const [
              'Time',
              'Customer',
              'Machine',
              'Method',
              'Status',
              'Amount'
            ],
            data: transactions
                .map(
                  (item) => [
                    _dateTimeFormat.format(item.order.timestamp),
                    item.customer.fullName,
                    item.machine.name,
                    item.order.paymentMethod,
                    item.order.paymentStatus,
                    'INR ${item.order.amount.toStringAsFixed(0)}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    return document.save();
  }

  static Future<Uint8List> buildDayEndCheckoutPdf(
    DayEndCheckout checkout,
  ) async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'WashPOS Day-End Checkout',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
                'Business date: ${_dateFormat.format(checkout.businessDate)}'),
            pw.Text('Closed at: ${_dateTimeFormat.format(checkout.closedAt)}'),
            pw.Text('Closed by: ${checkout.closedByName}'),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _row('Transactions', '${checkout.transactionCount}'),
                _row('Gross revenue',
                    'INR ${checkout.grossRevenue.toStringAsFixed(0)}'),
                _row('Refunded',
                    'INR ${checkout.refundedRevenue.toStringAsFixed(0)}'),
                _row('Net revenue',
                    'INR ${checkout.netRevenue.toStringAsFixed(0)}'),
                _row('Cash net', 'INR ${checkout.cashNet.toStringAsFixed(0)}'),
                _row('Digital net',
                    'INR ${checkout.digitalNet.toStringAsFixed(0)}'),
                _row('Opening cash',
                    'INR ${checkout.openingCash.toStringAsFixed(0)}'),
                _row(
                  'Expected drawer cash',
                  'INR ${checkout.expectedDrawerCash.toStringAsFixed(0)}',
                ),
                _row(
                  'Counted drawer cash',
                  'INR ${checkout.countedDrawerCash.toStringAsFixed(0)}',
                ),
                _row('Cash variance',
                    'INR ${checkout.cashVariance.toStringAsFixed(0)}'),
                _row('Pending refunds', '${checkout.pendingRefundCount}'),
                _row(
                  'Pending refund amount',
                  'INR ${checkout.pendingRefundAmount.toStringAsFixed(0)}',
                ),
              ],
            ),
            if ((checkout.notes ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Manager notes',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(checkout.notes!),
            ],
          ],
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _metricGrid(RevenueSummary summary) {
    final metrics = [
      ('Transactions', '${summary.transactionCount}'),
      ('Gross', 'INR ${summary.grossRevenue.toStringAsFixed(0)}'),
      ('Refunded', 'INR ${summary.refundedRevenue.toStringAsFixed(0)}'),
      ('Net', 'INR ${summary.netRevenue.toStringAsFixed(0)}'),
      ('Avg Ticket', 'INR ${summary.averageTicket.toStringAsFixed(0)}'),
      ('Cash Net', 'INR ${summary.cashNet.toStringAsFixed(0)}'),
      ('Card Net', 'INR ${summary.cardNet.toStringAsFixed(0)}'),
      ('UPI Net', 'INR ${summary.upiNet.toStringAsFixed(0)}'),
    ];
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics
          .map(
            (item) => pw.Container(
              width: 120,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(item.$1, style: const pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    item.$2,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _breakdownSection(
    String title,
    List<RevenueBreakdownItem> items,
  ) {
    if (items.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: const ['Segment', 'Orders', 'Net'],
          data: items
              .map(
                (item) => [
                  item.label,
                  '${item.orderCount}',
                  'INR ${item.amount.toStringAsFixed(0)}',
                ],
              )
              .toList(),
        ),
      ],
    );
  }

  static pw.TableRow _row(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(value),
        ),
      ],
    );
  }
}
