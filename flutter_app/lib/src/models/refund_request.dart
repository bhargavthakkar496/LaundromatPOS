class RefundRequestStatus {
  static const pending = 'PENDING';
  static const processed = 'PROCESSED';
}

class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.machineName,
    required this.amount,
    required this.paymentMethod,
    required this.paymentReference,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.requestedByName,
    this.processedAt,
    this.processedByName,
  });

  final int id;
  final int orderId;
  final String customerName;
  final String customerPhone;
  final String machineName;
  final double amount;
  final String paymentMethod;
  final String paymentReference;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final String? requestedByName;
  final DateTime? processedAt;
  final String? processedByName;

  bool get isPending => status == RefundRequestStatus.pending;

  bool get isProcessed => status == RefundRequestStatus.processed;

  RefundRequest copyWith({
    int? id,
    int? orderId,
    String? customerName,
    String? customerPhone,
    String? machineName,
    double? amount,
    String? paymentMethod,
    String? paymentReference,
    String? reason,
    String? status,
    DateTime? requestedAt,
    Object? requestedByName = _sentinel,
    Object? processedAt = _sentinel,
    Object? processedByName = _sentinel,
  }) {
    return RefundRequest(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      machineName: machineName ?? this.machineName,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentReference: paymentReference ?? this.paymentReference,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      requestedByName: identical(requestedByName, _sentinel)
          ? this.requestedByName
          : requestedByName as String?,
      processedAt: identical(processedAt, _sentinel)
          ? this.processedAt
          : processedAt as DateTime?,
      processedByName: identical(processedByName, _sentinel)
          ? this.processedByName
          : processedByName as String?,
    );
  }
}

const _sentinel = Object();
