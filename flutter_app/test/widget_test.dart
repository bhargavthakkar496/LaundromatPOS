import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:laundromat_pos_flutter/src/app.dart';
import 'package:laundromat_pos_flutter/src/data/demo_pos_repository.dart';
import 'package:laundromat_pos_flutter/src/models/machine.dart';
import 'package:laundromat_pos_flutter/src/models/order.dart';
import 'package:laundromat_pos_flutter/src/services/machine_integration_service.dart';
import 'package:laundromat_pos_flutter/src/services/session_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('renders login form', (WidgetTester tester) async {
    final repository = DemoPosRepository();
    repository.seedDemoData();
    await tester.pumpWidget(
      LaundromatPosApp(
        repository: repository,
        sessionStore: SessionStore(),
        currentUser: null,
      ),
    );

    expect(find.text('Laundromat POS'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  test('operator repository can load paid receipt data after customer payment', () async {
    final operatorRepository = DemoPosRepository();
    await operatorRepository.initialize();

    final machines = await operatorRepository.getMachines();
    final washer = machines.firstWhere((machine) => machine.id == 1);
    final dryer = machines.firstWhere((machine) => machine.id == 2);

    final bookedSession = await operatorRepository.saveActiveOrderDraft(
      customerName: 'gaurang',
      customerPhone: '9033263550',
      loadSizeKg: 8,
      washOption: 'Gentle Wash',
      washer: washer,
      dryer: dryer,
      paymentMethod: 'Card',
    );
    expect(bookedSession.isDraft, isTrue);

    final customerRepository = DemoPosRepository();
    await customerRepository.initialize();

    final confirmedSession = await customerRepository.confirmActiveOrderSession(
      confirmedBy: 'Customer',
    );
    expect(confirmedSession, isNotNull);
    expect(confirmedSession!.isBooked, isTrue);

    final paidSession = await customerRepository.completeActiveOrderPayment(
      paymentReference: 'BOOK-TEST1234',
    );
    expect(paidSession, isNotNull);
    expect(paidSession!.isPaid, isTrue);

    final refreshedSession = await operatorRepository.getActiveOrderSession();
    expect(refreshedSession, isNotNull);
    expect(refreshedSession!.isPaid, isTrue);

    final historyItem = await operatorRepository.getOrderHistoryItemByOrderId(
      refreshedSession.orderId!,
    );
    expect(historyItem, isNotNull);
    expect(historyItem!.order.paymentStatus, PaymentStatus.paid);
    expect(historyItem.order.paymentReference, 'BOOK-TEST1234');
  });

  test('repository applies external machine integration events', () async {
    final integration = _FakeMachineIntegrationService();
    final repository = DemoPosRepository(machineIntegration: integration);
    await repository.initialize();

    integration.emit(
      const MachineIntegrationEvent(
        machineId: 1,
        type: MachineIntegrationEventType.statusChanged,
        status: MachineStatus.readyForPickup,
        source: 'test',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final machine = await repository.getMachineById(1);
    expect(machine, isNotNull);
    expect(machine!.status, MachineStatus.readyForPickup);
  });
}

class _FakeMachineIntegrationService implements MachineIntegrationService {
  final StreamController<MachineIntegrationEvent> _controller =
      StreamController<MachineIntegrationEvent>.broadcast();

  @override
  Stream<MachineIntegrationEvent> get events => _controller.stream;

  void emit(MachineIntegrationEvent event) {
    _controller.add(event);
  }

  @override
  Future<void> clearMachine({required Machine machine}) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Machine>> reconcileMachines(List<Machine> machines) async {
    return machines;
  }

  @override
  Future<void> startCycle({
    required Machine machine,
    required int orderId,
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {}
}
