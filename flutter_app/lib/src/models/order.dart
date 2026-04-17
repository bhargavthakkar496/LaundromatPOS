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
    required this.selectedServices,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentReference,
    required this.timestamp,
    this.loadSizeKg,
    this.washOption,
    this.dryerMachineId,
    this.ironingMachineId,
  });

  final int id;
  final int machineId;
  final int customerId;
  final int? createdByUserId;
  final String serviceType;
  final List<String> selectedServices;
  final double amount;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentReference;
  final DateTime timestamp;
  final int? loadSizeKg;
  final String? washOption;
  final int? dryerMachineId;
  final int? ironingMachineId;

  Order copyWith({
    int? id,
    int? machineId,
    int? customerId,
    Object? createdByUserId = _sentinel,
    String? serviceType,
    List<String>? selectedServices,
    double? amount,
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentReference,
    DateTime? timestamp,
    Object? loadSizeKg = _sentinel,
    Object? washOption = _sentinel,
    Object? dryerMachineId = _sentinel,
    Object? ironingMachineId = _sentinel,
  }) {
    return Order(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      customerId: customerId ?? this.customerId,
      createdByUserId: identical(createdByUserId, _sentinel)
          ? this.createdByUserId
          : createdByUserId as int?,
      serviceType: serviceType ?? this.serviceType,
      selectedServices: selectedServices ?? this.selectedServices,
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
      ironingMachineId: identical(ironingMachineId, _sentinel)
          ? this.ironingMachineId
          : ironingMachineId as int?,
    );
  }
}

const _sentinel = Object();
