class PaymentSessionStatus {
  static const awaitingScan = 'AWAITING_SCAN';
  static const processing = 'PROCESSING';
  static const paid = 'PAID';
  static const failed = 'FAILED';
}

class PaymentSession {
  const PaymentSession({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.qrPayload,
    required this.status,
    required this.attempt,
    required this.createdAt,
    required this.checkedAt,
    this.failureReason,
  });

  final int id;
  final double amount;
  final String paymentMethod;
  final String reference;
  final String qrPayload;
  final String status;
  final int attempt;
  final DateTime createdAt;
  final DateTime checkedAt;
  final String? failureReason;

  bool get isPaid => status == PaymentSessionStatus.paid;

  bool get isFailed => status == PaymentSessionStatus.failed;
}
