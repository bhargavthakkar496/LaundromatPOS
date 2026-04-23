import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:washpos_flutter/src/app.dart';
import 'package:washpos_flutter/src/data/demo_pos_repository.dart';
import 'package:washpos_flutter/src/models/active_order_session.dart';
import 'package:washpos_flutter/src/models/customer.dart';
import 'package:washpos_flutter/src/models/garment_item.dart';
import 'package:washpos_flutter/src/models/machine.dart';
import 'package:washpos_flutter/src/models/order.dart';
import 'package:washpos_flutter/src/models/receipt_data.dart';
import 'package:washpos_flutter/src/services/machine_integration_service.dart';
import 'package:washpos_flutter/src/services/session_store.dart';
import 'package:washpos_flutter/src/services/taffeta_tag_service.dart';

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
      WashPosApp(
        repository: repository,
        sessionStore: SessionStore(),
        currentSession: null,
      ),
    );

    expect(find.text('WashPOS'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  test('operator repository can load paid receipt data after customer payment',
      () async {
    final operatorRepository = DemoPosRepository();
    await operatorRepository.initialize();

    final machines = await operatorRepository.getMachines();
    final washer = machines.firstWhere((machine) => machine.id == 1);
    final dryer = machines.firstWhere((machine) => machine.id == 2);

    final bookedSession = await operatorRepository.saveActiveOrderDraft(
      customerName: 'gaurang',
      customerPhone: '9033263550',
      loadSizeKg: 8,
      selectedServices: const [
        LaundryService.washing,
        LaundryService.drying,
      ],
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

  test('garment manifest persists across draft and order creation', () async {
    final repository = DemoPosRepository();
    await repository.initialize();

    final machines = await repository.getMachines();
    final washer = machines.firstWhere((machine) => machine.id == 1);
    final dryer = machines.firstWhere((machine) => machine.id == 2);

    final draft = await repository.saveActiveOrderDraft(
      customerName: 'Asha',
      customerPhone: '9876543210',
      loadSizeKg: 8,
      selectedServices: const [
        LaundryService.washing,
        LaundryService.drying,
      ],
      garmentItems: const [
        GarmentItem(
          tagId: 'TAG-1001',
          garmentLabel: 'Shirt',
          quantity: 2,
          selectedServices: [
            LaundryService.washing,
            LaundryService.ironing,
          ],
          unitPrice: 63,
          status: GarmentItemStatus.received,
          sourceDeduplicationKey: 'TAG-1001',
        ),
        GarmentItem(
          tagId: 'TAG-1002',
          garmentLabel: 'Trouser',
          quantity: 1,
          selectedServices: [
            LaundryService.washing,
            LaundryService.drying,
          ],
          unitPrice: 75,
          status: GarmentItemStatus.received,
          sourceDeduplicationKey: 'TAG-1002',
        ),
      ],
      washOption: 'Gentle Wash',
      washer: washer,
      dryer: dryer,
      paymentMethod: 'Cash',
    );

    expect(draft.garmentItems, hasLength(2));

    final confirmed = await repository.confirmActiveOrderSession(
      confirmedBy: 'Operator',
    );
    expect(confirmed, isNotNull);
    expect(confirmed!.garmentItems, hasLength(2));

    final historyItem = await repository.getOrderHistoryItemByOrderId(
      confirmed.orderId!,
    );
    expect(historyItem, isNotNull);
    expect(historyItem!.order.garmentItems, hasLength(2));
    expect(historyItem.order.amount, 201);
  });

  test('taffeta tag jobs expand one print action per garment piece', () {
    final jobs = TaffetaTagService.buildPrintJobs(
      ReceiptData(
        order: Order(
          id: 77,
          machineId: 1,
          customerId: 1,
          createdByUserId: 1,
          serviceType: 'WASHING+DRYING',
          selectedServices: const [
            LaundryService.washing,
            LaundryService.drying,
          ],
          amount: 201,
          status: OrderStatus.booked,
          paymentMethod: 'Cash',
          paymentStatus: PaymentStatus.paid,
          paymentReference: 'ORD-77',
          timestamp: DateTime(2026, 4, 23, 11, 30),
          garmentItems: const [
            GarmentItem(
              tagId: 'TAG-1001',
              garmentLabel: 'Shirt',
              quantity: 2,
              selectedServices: [LaundryService.washing],
              unitPrice: 45,
              status: GarmentItemStatus.received,
              sourceDeduplicationKey: 'TAG-1001',
            ),
            GarmentItem(
              tagId: 'TAG-1002',
              garmentLabel: 'Trouser',
              quantity: 1,
              selectedServices: [LaundryService.drying],
              unitPrice: 30,
              status: GarmentItemStatus.received,
              sourceDeduplicationKey: 'TAG-1002',
            ),
          ],
        ),
        customer: const Customer(
          id: 1,
          fullName: 'Asha',
          phone: '9876543210',
        ),
        machine: const Machine(
          id: 1,
          name: 'Washer 01',
          type: 'Washer',
          capacityKg: 8,
          price: 120,
          status: MachineStatus.available,
        ),
      ),
    );

    expect(jobs, hasLength(3));
    expect(jobs.first.tagId, 'TAG-1001-1');
    expect(jobs[1].tagId, 'TAG-1001-2');
    expect(jobs.last.tagId, 'TAG-1002');
    expect(jobs.last.pieceLabel, '3/3');
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
