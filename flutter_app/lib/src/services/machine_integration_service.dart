import 'dart:async';

import '../models/machine.dart';

class MachineIntegrationEventType {
  static const statusChanged = 'STATUS_CHANGED';
  static const telemetry = 'TELEMETRY';
  static const lifecycle = 'LIFECYCLE';
}

class MachineIntegrationEvent {
  const MachineIntegrationEvent({
    required this.machineId,
    required this.type,
    this.status,
    this.currentOrderId,
    this.cycleStartedAt,
    this.cycleEndsAt,
    this.clearOrderAssignment = false,
    this.clearCycleWindow = false,
    this.source = 'integration',
    this.metadata = const <String, Object?>{},
  });

  final int machineId;
  final String type;
  final String? status;
  final int? currentOrderId;
  final DateTime? cycleStartedAt;
  final DateTime? cycleEndsAt;
  final bool clearOrderAssignment;
  final bool clearCycleWindow;
  final String source;
  final Map<String, Object?> metadata;

  factory MachineIntegrationEvent.fromMap(Map<Object?, Object?> raw) {
    DateTime? parseDate(Object? value) {
      if (value is! String || value.isEmpty) {
        return null;
      }
      return DateTime.tryParse(value);
    }

    return MachineIntegrationEvent(
      machineId: raw['machineId'] as int,
      type: (raw['type'] as String?) ?? MachineIntegrationEventType.telemetry,
      status: raw['status'] as String?,
      currentOrderId: raw['currentOrderId'] as int?,
      cycleStartedAt: parseDate(raw['cycleStartedAt']),
      cycleEndsAt: parseDate(raw['cycleEndsAt']),
      clearOrderAssignment:
          (raw['clearOrderAssignment'] as bool?) ?? false,
      clearCycleWindow: (raw['clearCycleWindow'] as bool?) ?? false,
      source: (raw['source'] as String?) ?? 'sunmi',
      metadata: Map<String, Object?>.from(
        (raw['metadata'] as Map<Object?, Object?>?) ?? const {},
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'machineId': machineId,
      'type': type,
      'status': status,
      'currentOrderId': currentOrderId,
      'cycleStartedAt': cycleStartedAt?.toIso8601String(),
      'cycleEndsAt': cycleEndsAt?.toIso8601String(),
      'clearOrderAssignment': clearOrderAssignment,
      'clearCycleWindow': clearCycleWindow,
      'source': source,
      'metadata': metadata,
    };
  }
}

abstract class MachineIntegrationService {
  Stream<MachineIntegrationEvent> get events;

  Future<void> initialize();

  Future<List<Machine>> reconcileMachines(List<Machine> machines);

  Future<void> startCycle({
    required Machine machine,
    required int orderId,
    required DateTime startedAt,
    required DateTime endsAt,
  });

  Future<void> clearMachine({
    required Machine machine,
  });

  Future<void> dispose();
}
