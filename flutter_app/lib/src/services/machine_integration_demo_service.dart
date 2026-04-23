import 'dart:async';

import '../models/machine.dart';
import 'machine_integration_service.dart';

class DemoMachineIntegrationService implements MachineIntegrationService {
  final StreamController<MachineIntegrationEvent> _controller =
      StreamController<MachineIntegrationEvent>.broadcast();

  @override
  Stream<MachineIntegrationEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Machine>> reconcileMachines(List<Machine> machines) async {
    final now = DateTime.now();
    return machines
        .map((machine) => machine.normalizedCycleStatus(now: now))
        .toList();
  }

  @override
  Future<void> startCycle({
    required Machine machine,
    required int orderId,
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {
    _controller.add(
      MachineIntegrationEvent(
        machineId: machine.id,
        type: MachineIntegrationEventType.lifecycle,
        status: MachineStatus.inUse,
        currentOrderId: orderId,
        cycleStartedAt: startedAt,
        cycleEndsAt: endsAt,
        source: 'demo',
      ),
    );
  }

  @override
  Future<void> clearMachine({
    required Machine machine,
  }) async {
    _controller.add(
      MachineIntegrationEvent(
        machineId: machine.id,
        type: MachineIntegrationEventType.lifecycle,
        status: MachineStatus.available,
        clearOrderAssignment: true,
        clearCycleWindow: true,
        source: 'demo',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
