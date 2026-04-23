class PickupTaskStatus {
  static const pending = 'PENDING';
  static const reminderSent = 'REMINDER_SENT';
  static const pickedUp = 'PICKED_UP';
  static const cancelled = 'CANCELLED';
}

class PickupTask {
  const PickupTask({
    required this.orderId,
    required this.machineId,
    required this.status,
    this.updatedAt,
  });

  final int orderId;
  final int machineId;
  final String status;
  final DateTime? updatedAt;

  Map<String, Object?> toJson() {
    return {
      'orderId': orderId,
      'machineId': machineId,
      'status': status,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory PickupTask.fromJson(Map<String, dynamic> json) {
    return PickupTask(
      orderId: json['orderId'] as int,
      machineId: json['machineId'] as int,
      status: json['status'] as String,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  PickupTask copyWith({
    int? orderId,
    int? machineId,
    String? status,
    Object? updatedAt = _sentinel,
  }) {
    return PickupTask(
      orderId: orderId ?? this.orderId,
      machineId: machineId ?? this.machineId,
      status: status ?? this.status,
      updatedAt: identical(updatedAt, _sentinel)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const _sentinel = Object();
