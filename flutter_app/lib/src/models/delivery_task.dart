class DeliveryTaskStatus {
  static const pending = 'PENDING';
  static const scheduled = 'SCHEDULED';
  static const outForDelivery = 'OUT_FOR_DELIVERY';
  static const delivered = 'DELIVERED';
  static const cancelled = 'CANCELLED';
}

class DeliveryTask {
  const DeliveryTask({
    required this.orderId,
    required this.status,
    required this.windowLabel,
    this.assignedDriver,
    this.updatedAt,
  });

  final int orderId;
  final String status;
  final String windowLabel;
  final String? assignedDriver;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() {
    return {
      'orderId': orderId,
      'status': status,
      'windowLabel': windowLabel,
      'assignedDriver': assignedDriver,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory DeliveryTask.fromJson(Map<String, dynamic> json) {
    return DeliveryTask(
      orderId: json['orderId'] as int,
      status: json['status'] as String,
      windowLabel: json['windowLabel'] as String,
      assignedDriver: json['assignedDriver'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  DeliveryTask copyWith({
    int? orderId,
    String? status,
    String? windowLabel,
    Object? assignedDriver = _sentinel,
    Object? updatedAt = _sentinel,
  }) {
    return DeliveryTask(
      orderId: orderId ?? this.orderId,
      status: status ?? this.status,
      windowLabel: windowLabel ?? this.windowLabel,
      assignedDriver: identical(assignedDriver, _sentinel)
          ? this.assignedDriver
          : assignedDriver as String?,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const _sentinel = Object();
