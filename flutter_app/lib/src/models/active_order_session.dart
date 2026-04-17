class ActiveOrderSessionStage {
  static const draft = 'DRAFT';
  static const booked = 'BOOKED';
  static const paid = 'PAID';
}

class ActiveOrderSession {
  const ActiveOrderSession({
    required this.customerName,
    required this.customerPhone,
    required this.loadSizeKg,
    required this.washOption,
    required this.washerMachineId,
    required this.dryerMachineId,
    required this.paymentMethod,
    required this.stage,
    required this.createdAt,
    this.confirmedBy,
    this.orderId,
    this.paymentReference,
  });

  final String customerName;
  final String customerPhone;
  final int loadSizeKg;
  final String washOption;
  final int washerMachineId;
  final int dryerMachineId;
  final String paymentMethod;
  final String stage;
  final DateTime createdAt;
  final String? confirmedBy;
  final int? orderId;
  final String? paymentReference;

  bool get isDraft => stage == ActiveOrderSessionStage.draft;
  bool get isBooked => stage == ActiveOrderSessionStage.booked;
  bool get isPaid => stage == ActiveOrderSessionStage.paid;

  ActiveOrderSession copyWith({
    String? customerName,
    String? customerPhone,
    int? loadSizeKg,
    String? washOption,
    int? washerMachineId,
    int? dryerMachineId,
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
      washOption: washOption ?? this.washOption,
      washerMachineId: washerMachineId ?? this.washerMachineId,
      dryerMachineId: dryerMachineId ?? this.dryerMachineId,
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
      'washOption': washOption,
      'washerMachineId': washerMachineId,
      'dryerMachineId': dryerMachineId,
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
      washOption: json['washOption'] as String,
      washerMachineId: json['washerMachineId'] as int,
      dryerMachineId: json['dryerMachineId'] as int,
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
