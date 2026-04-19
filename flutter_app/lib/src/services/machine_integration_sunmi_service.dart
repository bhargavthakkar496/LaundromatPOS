import 'dart:async';

import 'package:flutter/services.dart';

import '../models/machine.dart';
import 'machine_integration_service.dart';

class SunmiMachineIntegrationService implements MachineIntegrationService {
  SunmiMachineIntegrationService({
    required MachineIntegrationService fallback,
  }) : _fallback = fallback;

  static const MethodChannel _methodChannel =
      MethodChannel('washpos/machine_integration');
  static const EventChannel _eventChannel =
      EventChannel('washpos/machine_integration/events');

  final MachineIntegrationService _fallback;
  final StreamController<MachineIntegrationEvent> _controller =
      StreamController<MachineIntegrationEvent>.broadcast();

  StreamSubscription<dynamic>? _nativeSubscription;
  StreamSubscription<MachineIntegrationEvent>? _fallbackSubscription;
  bool _nativeAvailable = false;

  @override
  Stream<MachineIntegrationEvent> get events => _controller.stream;

  @override
  Future<void> initialize() async {
    await _fallback.initialize();
    try {
      final available =
          await _methodChannel.invokeMethod<bool>('isAvailable') ?? false;
      _nativeAvailable = available;
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException {
      _nativeAvailable = false;
    }

    if (_nativeAvailable) {
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map<Object?, Object?>) {
            _controller.add(MachineIntegrationEvent.fromMap(event));
          }
        },
        onError: (_) {},
      );
      return;
    }

    _fallbackSubscription = _fallback.events.listen(_controller.add);
  }

  @override
  Future<List<Machine>> reconcileMachines(List<Machine> machines) async {
    if (_nativeAvailable) {
      return machines;
    }
    return _fallback.reconcileMachines(machines);
  }

  @override
  Future<void> startCycle({
    required Machine machine,
    required int orderId,
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {
    if (!_nativeAvailable) {
      await _fallback.startCycle(
        machine: machine,
        orderId: orderId,
        startedAt: startedAt,
        endsAt: endsAt,
      );
      return;
    }

    try {
      await _methodChannel.invokeMethod<void>('startCycle', {
        'machineId': machine.id,
        'machineType': machine.type,
        'orderId': orderId,
        'startedAt': startedAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
      });
    } on MissingPluginException {
      await _fallback.startCycle(
        machine: machine,
        orderId: orderId,
        startedAt: startedAt,
        endsAt: endsAt,
      );
    } on PlatformException {
      await _fallback.startCycle(
        machine: machine,
        orderId: orderId,
        startedAt: startedAt,
        endsAt: endsAt,
      );
    }
  }

  @override
  Future<void> clearMachine({
    required Machine machine,
  }) async {
    if (!_nativeAvailable) {
      await _fallback.clearMachine(machine: machine);
      return;
    }

    try {
      await _methodChannel.invokeMethod<void>('clearMachine', {
        'machineId': machine.id,
      });
    } on MissingPluginException {
      await _fallback.clearMachine(machine: machine);
    } on PlatformException {
      await _fallback.clearMachine(machine: machine);
    }
  }

  @override
  Future<void> dispose() async {
    await _nativeSubscription?.cancel();
    await _fallbackSubscription?.cancel();
    await _controller.close();
    await _fallback.dispose();
  }
}
