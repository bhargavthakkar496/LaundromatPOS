import 'package:flutter_test/flutter_test.dart';
import 'package:washpos_flutter/src/models/machine.dart';

void main() {
  group('Machine.normalizedCycleStatus', () {
    test('marks overdue running cycles as ready for pickup', () {
      final machine = Machine(
        id: 1,
        name: 'Washer 01',
        type: Machine.washerType,
        capacityKg: 8,
        price: 120,
        status: MachineStatus.inUse,
        currentOrderId: 13,
        cycleStartedAt: DateTime(2026, 4, 21, 18, 30),
        cycleEndsAt: DateTime(2026, 4, 21, 19, 0),
      );

      final normalized = machine.normalizedCycleStatus(
        now: DateTime(2026, 4, 21, 19, 0, 1),
      );

      expect(normalized.status, MachineStatus.readyForPickup);
      expect(normalized.currentOrderId, 13);
      expect(normalized.cycleEndsAt, machine.cycleEndsAt);
    });

    test('keeps active cycles running before their end time', () {
      final machine = Machine(
        id: 2,
        name: 'Dryer 01',
        type: Machine.dryerType,
        capacityKg: 10,
        price: 150,
        status: MachineStatus.inUse,
        cycleStartedAt: DateTime(2026, 4, 21, 18, 30),
        cycleEndsAt: DateTime(2026, 4, 21, 19, 0),
      );

      final normalized = machine.normalizedCycleStatus(
        now: DateTime(2026, 4, 21, 18, 59, 59),
      );

      expect(normalized.status, MachineStatus.inUse);
    });
  });
}
