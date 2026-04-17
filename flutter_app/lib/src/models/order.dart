class OrderStatus {
  static const booked = 'BOOKED';
  static const inProgress = 'IN_PROGRESS';
  static const completed = 'COMPLETED';
}

class PaymentStatus {
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const refunded = 'REFUNDED';
}

class Order {
  const Order({
    required this.id,
    required this.machineId,
    required this.customerId,
    required this.createdByUserId,
    required this.serviceType,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentReference,
    required this.timestamp,
    this.loadSizeKg,
    this.washOption,
    this.dryerMachineId,
  });

  final int id;
  final int machineId;
  final int customerId;
  final int? createdByUserId;
  final String serviceType;
  final double amount;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentReference;
  final DateTime timestamp;
  final int? loadSizeKg;
  final String? washOption;
  final int? dryerMachineId;

  Order copyWith({
    int? id,
    int? machineId,
    int? customerId,
    Object? createdByUserId = _sentinel,
    String? serviceType,
    double? amount,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentReference,
    DateTime? timestamp,
    Object? loadSizeKg = _sentinel,
    Object? washOption = _sentinel,
    Object? dryerMachineId = _sentinel,
  }) {
    return Order(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      customerId: customerId ?? this.customerId,
      createdByUserId: identical(createdByUserId, _sentinel)
          ? this.createdByUserId
          : createdByUserId as int?,
      serviceType: serviceType ?? this.serviceType,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      timestamp: timestamp ?? this.timestamp,
      loadSizeKg: identical(loadSizeKg, _sentinel)
          ? this.loadSizeKg
          : loadSizeKg as int?,
      washOption: identical(washOption, _sentinel)
          ? this.washOption
          : washOption as String?,
      dryerMachineId: identical(dryerMachineId, _sentinel)
          ? this.dryerMachineId
          : dryerMachineId as int?,
    );
  }
}

const _sentinel = Object();
