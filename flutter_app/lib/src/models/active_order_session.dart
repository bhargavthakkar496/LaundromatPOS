class ActiveOrderSessionStage {
  static const draft = 'DRAFT';
  static const booked = 'BOOKED';
  static const paid = 'PAID';
}

class LaundryService {
  static const washing = 'Washing';
  static const drying = 'Drying';
  static const ironing = 'Ironing';
}

class ActiveOrderSession {
  const ActiveOrderSession({
    required this.customerName,
    required this.customerPhone,
    required this.loadSizeKg,
    required this.selectedServices,
    required this.paymentMethod,
    required this.stage,
    required this.createdAt,
    this.washOption,
    this.washerMachineId,
    this.dryerMachineId,
    this.ironingMachineId,
    this.confirmedBy,
    this.orderId,
    this.paymentReference,
  });

  final String customerName;
  final String customerPhone;
  final int loadSizeKg;
  final List<String> selectedServices;
  final String? washOption;
  final int? washerMachineId;
  final int? dryerMachineId;
  final int? ironingMachineId;
  final String paymentMethod;
  final String stage;
  final DateTime createdAt;
  final String? confirmedBy;
  final int? orderId;
  final String? paymentReference;

  bool get includesWashing => selectedServices.contains(LaundryService.washing);
  bool get includesDrying => selectedServices.contains(LaundryService.drying);
  bool get includesIroning => selectedServices.contains(LaundryService.ironing);

  bool get isDraft => stage == ActiveOrderSessionStage.draft;
  bool get isBooked => stage == ActiveOrderSessionStage.booked;
  bool get isPaid => stage == ActiveOrderSessionStage.paid;

  ActiveOrderSession copyWith({
    String? customerName,
    String? customerPhone,
    int? loadSizeKg,
    List<String>? selectedServices,
    Object? washOption = _sentinel,
    Object? washerMachineId = _sentinel,
    Object? dryerMachineId = _sentinel,
    Object? ironingMachineId = _sentinel,
    String? paymentMethod,
    String? stage,
    DateTime? createdAt,
    Object? confirmedBy = _sentinel,
    Object? orderId = _sentinel,
    Object? paymentReference = _sentinel,
  }) {
    return ActiveOrderSession(
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      loadSizeKg: loadSizeKg ?? this.loadSizeKg,
      selectedServices: selectedServices ?? this.selectedServices,
      washOption: identical(washOption, _sentinel)
          ? this.washOption
          : washOption as String?,
      washerMachineId: identical(washerMachineId, _sentinel)
          ? this.washerMachineId
          : washerMachineId as int?,
      dryerMachineId: identical(dryerMachineId, _sentinel)
          ? this.dryerMachineId
          : dryerMachineId as int?,
      ironingMachineId: identical(ironingMachineId, _sentinel)
          ? this.ironingMachineId
          : ironingMachineId as int?,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      confirmedBy: identical(confirmedBy, _sentinel)
          ? this.confirmedBy
          : confirmedBy as String?,
      orderId: identical(orderId, _sentinel) ? this.orderId : orderId as int?,
      paymentReference: identical(paymentReference, _sentinel)
          ? this.paymentReference
          : paymentReference as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'loadSizeKg': loadSizeKg,
      'selectedServices': selectedServices,
      'washOption': washOption,
      'washerMachineId': washerMachineId,
      'dryerMachineId': dryerMachineId,
      'ironingMachineId': ironingMachineId,
      'paymentMethod': paymentMethod,
      'stage': stage,
      'createdAt': createdAt.toIso8601String(),
      'confirmedBy': confirmedBy,
      'orderId': orderId,
      'paymentReference': paymentReference,
    };
  }

  factory ActiveOrderSession.fromJson(Map<String, dynamic> json) {
    return ActiveOrderSession(
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      loadSizeKg: json['loadSizeKg'] as int,
      selectedServices: (json['selectedServices'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      washOption: json['washOption'] as String?,
      washerMachineId: json['washerMachineId'] as int?,
      dryerMachineId: json['dryerMachineId'] as int?,
      ironingMachineId: json['ironingMachineId'] as int?,
      paymentMethod: json['paymentMethod'] as String,
      stage: json['stage'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      confirmedBy: json['confirmedBy'] as String?,
      orderId: json['orderId'] as int?,
      paymentReference: json['paymentReference'] as String?,
    );
  }
}

const _sentinel = Object();
