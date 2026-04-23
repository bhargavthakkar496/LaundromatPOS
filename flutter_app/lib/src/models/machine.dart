import '../config/demo_settings.dart';

class MachineStatus {
  static const available = 'AVAILABLE';
  static const maintenance = 'MAINTENANCE';
  static const inUse = 'IN_USE';
  static const readyForPickup = 'READY_FOR_PICKUP';
}

class Machine {
  static const washerType = 'Washer';
  static const dryerType = 'Dryer';
  static const ironingStationType = 'Ironing Station';

  const Machine({
    required this.id,
    required this.name,
    required this.type,
    required this.capacityKg,
    required this.price,
    required this.status,
    this.currentOrderId,
    this.cycleStartedAt,
    this.cycleEndsAt,
  });

  final int id;
  final String name;
  final String type;
  final int capacityKg;
  final double price;
  final String status;
  final int? currentOrderId;
  final DateTime? cycleStartedAt;
  final DateTime? cycleEndsAt;

  bool get isWasher => type.toLowerCase() == 'washer';

  bool get isDryer => type.toLowerCase() == 'dryer';

  bool get isIroningStation => type.toLowerCase() == 'ironing station';

  String? get iconAsset {
    if (isWasher) {
      return 'assets/icons/washer.svg';
    }
    if (isDryer) {
      return 'assets/icons/dryer.svg';
    }
    return null;
  }

  bool get isAvailable => status == MachineStatus.available;

  bool get isInUse => status == MachineStatus.inUse;

  bool get isReadyForPickup => status == MachineStatus.readyForPickup;

  bool get hasCycleEnded {
    if (cycleEndsAt == null) {
      return false;
    }
    return !cycleEndsAt!.isAfter(DateTime.now());
  }

  int get productionCycleMinutes {
    if (isWasher) {
      return 35;
    }
    if (isDryer) {
      return 25;
    }
    return 20;
  }

  Duration get cycleDuration => DemoSettings.demoSpeedMode
      ? Duration(seconds: productionCycleMinutes)
      : Duration(minutes: productionCycleMinutes);

  Duration? get remainingCycleDuration {
    if (cycleEndsAt == null) {
      return null;
    }
    final remaining = cycleEndsAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Machine normalizedCycleStatus({DateTime? now}) {
    final referenceTime = now ?? DateTime.now();
    if (status == MachineStatus.inUse &&
        cycleEndsAt != null &&
        !cycleEndsAt!.isAfter(referenceTime)) {
      return copyWith(status: MachineStatus.readyForPickup);
    }
    return this;
  }

  Machine copyWith({
    int? id,
    String? name,
    String? type,
    int? capacityKg,
    double? price,
    String? status,
    Object? currentOrderId = _sentinel,
    Object? cycleStartedAt = _sentinel,
    Object? cycleEndsAt = _sentinel,
  }) {
    return Machine(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      capacityKg: capacityKg ?? this.capacityKg,
      price: price ?? this.price,
      status: status ?? this.status,
      currentOrderId: identical(currentOrderId, _sentinel)
          ? this.currentOrderId
          : currentOrderId as int?,
      cycleStartedAt: identical(cycleStartedAt, _sentinel)
          ? this.cycleStartedAt
          : cycleStartedAt as DateTime?,
      cycleEndsAt: identical(cycleEndsAt, _sentinel)
          ? this.cycleEndsAt
          : cycleEndsAt as DateTime?,
    );
  }
}

const _sentinel = Object();
