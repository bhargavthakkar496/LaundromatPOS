import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode/barcode.dart' as barcode_lib;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/receipt_data.dart';

class TaffetaTagPrintJob {
  const TaffetaTagPrintJob({
    required this.tagId,
    required this.garmentLabel,
    required this.pieceNumber,
    required this.totalPieces,
    required this.selectedServices,
    required this.qrPayload,
  });

  final String tagId;
  final String garmentLabel;
  final int pieceNumber;
  final int totalPieces;
  final List<String> selectedServices;
  final String qrPayload;

  String get pieceLabel => '$pieceNumber/$totalPieces';
}

class TaffetaTagService {
  static const double _tagWidthMm = 50;
  static const double _tagHeightMm = 38;
  static const double _mmToPdfPoints = 72 / 25.4;
  static const double _tagWidthPoints = _tagWidthMm * _mmToPdfPoints;
  static const double _tagHeightPoints = _tagHeightMm * _mmToPdfPoints;
  static const double _qrSizePoints = 64;
  static final barcode_lib.Barcode _qrBarcode = barcode_lib.Barcode.qrCode();
  static const PdfPageFormat pdfPageFormat = PdfPageFormat(
    _tagWidthPoints,
    _tagHeightPoints,
  );

  static List<TaffetaTagPrintJob> buildPrintJobs(ReceiptData receipt) {
    final garmentItems = receipt.order.garmentItems;
    if (garmentItems.isEmpty) {
      return [
        TaffetaTagPrintJob(
          tagId: 'ORDER-${receipt.order.id}-1',
          garmentLabel: 'Laundry Order',
          pieceNumber: 1,
          totalPieces: 1,
          selectedServices: receipt.order.selectedServices,
          qrPayload: jsonEncode({
            'tagId': 'ORDER-${receipt.order.id}-1',
            'orderId': receipt.order.id,
            'customerName': receipt.customer.fullName,
            'customerPhone': receipt.customer.phone,
            'pieceNumber': 1,
            'totalPieces': 1,
            'garmentLabel': 'Laundry Order',
            'services': receipt.order.selectedServices,
            'status': 'ORDER_LEVEL_FALLBACK',
            'fallback': true,
          }),
        ),
      ];
    }

    final jobs = <TaffetaTagPrintJob>[];
    var pieceIndex = 0;
    final totalPieces = garmentItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    for (final garmentItem in garmentItems) {
      final quantity = garmentItem.quantity < 1 ? 1 : garmentItem.quantity;
      for (var itemPiece = 1; itemPiece <= quantity; itemPiece++) {
        pieceIndex += 1;
        final tagId = quantity == 1
            ? garmentItem.tagId
            : '${garmentItem.tagId}-$itemPiece';
        jobs.add(
          TaffetaTagPrintJob(
            tagId: tagId,
            garmentLabel: garmentItem.garmentLabel,
            pieceNumber: pieceIndex,
            totalPieces: totalPieces,
            selectedServices: garmentItem.selectedServices,
            qrPayload: jsonEncode({
              'tagId': tagId,
              'orderId': receipt.order.id,
              'customerName': receipt.customer.fullName,
              'customerPhone': receipt.customer.phone,
              'pieceNumber': pieceIndex,
              'totalPieces': totalPieces,
              'garmentLabel': garmentItem.garmentLabel,
              'services': garmentItem.selectedServices,
              'status': garmentItem.status,
            }),
          ),
        );
      }
    }

    return jobs;
  }

  static String buildPrinterTextTag(
    ReceiptData receipt,
    TaffetaTagPrintJob job,
  ) {
    final lines = <String>[
      'QR: ${job.qrPayload}',
      '',
      '',
    ];
    return lines.join('\n');
  }

  static Future<Uint8List> buildTagsPdf(
    ReceiptData receipt,
    List<TaffetaTagPrintJob> jobs,
  ) async {
    final document = pw.Document();

    for (final job in jobs) {
      document.addPage(
        pw.Page(
          pageFormat: pdfPageFormat,
          margin: const pw.EdgeInsets.all(6),
          build: (context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    receipt.customer.fullName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    receipt.customer.phone,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 6),
                    maxLines: 1,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.SizedBox(
                      width: _qrSizePoints,
                      height: _qrSizePoints,
                      child: pw.SvgImage(
                        svg: _qrBarcode.toSvg(
                          job.qrPayload,
                          width: _qrSizePoints,
                          height: _qrSizePoints,
                          drawText: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return document.save();
  }
}
