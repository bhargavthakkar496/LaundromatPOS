// ignore_for_file: annotate_overrides

import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_order_session.dart';
import '../models/customer.dart';
import '../models/customer_profile.dart';
import '../models/machine.dart';
import '../models/machine_reservation.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../models/pos_user.dart';
import '../models/reservation_history_item.dart';
import '../models/auth_session.dart';
import '../services/machine_integration_factory.dart';
import '../services/machine_integration_service.dart';
import 'pos_repository.dart';

class DemoPosRepository implements PosRepository {
  static const _customersKey = 'customers_v1';
  static const _ordersKey = 'orders_v1';
  static const _machinesKey = 'machines_v1';
  static const _reservationsKey = 'reservations_v1';
  static const _activeOrderSessionKey = 'active_order_session_v1';
  static const _customerCounterKey = 'customer_counter_v1';
  static const _orderCounterKey = 'order_counter_v1';
  static const _paymentSessionCounterKey = 'payment_session_counter_v1';
  static const _reservationCounterKey = 'reservation_counter_v1';

  final List<PosUser> _users = [];
  final List<Machine> _machines = [];
  final List<Customer> _customers = [];
  final List<Order> _orders = [];
  final List<MachineReservation> _reservations = [];
  final Map<int, _PaymentSessionRecord> _paymentSessions = {};
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final MachineIntegrationService _machineIntegration;

  StreamSubscription<MachineIntegrationEvent>? _machineIntegrationSubscription;
  bool _machineIntegrationStarted = false;

  int _customerCounter = 0;
  int _orderCounter = 0;
  int _paymentSessionCounter = 0;
  int _reservationCounter = 0;

  DemoPosRepository({
    MachineIntegrationService? machineIntegration,
  }) : _machineIntegration =
            machineIntegration ?? createDefaultMachineIntegrationService();

  Future<void> initialize() async {
    await _loadPersistedState();
    if (_users.isEmpty) {
      seedDemoData();
      await _persistState();
    }
    await _ensureMachineIntegrationStarted();
  }

  Future<void> dispose() async {
    await _machineIntegrationSubscription?.cancel();
    await _machineIntegration.dispose();
  }

  void seedDemoData() {
    if (_users.isEmpty) {
      _users.add(
        const PosUser(
          id: 1,
          username: 'admin',
          displayName: 'Store Admin',
          pin: '1234',
          role: 'ADMIN',
        ),
      );
    }

    if (_machines.isEmpty) {
      _machines.addAll(const [
        Machine(
          id: 1,
          name: 'Washer 01',
          type: 'Washer',
          capacityKg: 8,
          price: 120,
          status: MachineStatus.available,
        ),
        Machine(
          id: 2,
          name: 'Dryer 02',
          type: 'Dryer',
          capacityKg: 10,
          price: 150,
          status: MachineStatus.available,
        ),
        Machine(
          id: 3,
          name: 'Washer 03',
          type: 'Washer',
          capacityKg: 12,
          price: 180,
          status: MachineStatus.maintenance,
        ),
        Machine(
          id: 4,
          name: 'Washer 04',
          type: 'Washer',
          capacityKg: 9,
          price: 130,
          status: MachineStatus.available,
        ),
        Machine(
          id: 5,
          name: 'Washer 05',
          type: 'Washer',
          capacityKg: 11,
          price: 165,
          status: MachineStatus.available,
        ),
        Machine(
          id: 6,
          name: 'Washer 06',
          type: 'Washer',
          capacityKg: 14,
          price: 210,
          status: MachineStatus.available,
        ),
        Machine(
          id: 7,
          name: 'Dryer 04',
          type: 'Dryer',
          capacityKg: 9,
          price: 135,
          status: MachineStatus.available,
        ),
        Machine(
          id: 8,
          name: 'Dryer 05',
          type: 'Dryer',
          capacityKg: 12,
          price: 170,
          status: MachineStatus.available,
        ),
        Machine(
          id: 9,
          name: 'Dryer 06',
          type: 'Dryer',
          capacityKg: 15,
          price: 220,
          status: MachineStatus.available,
        ),
        Machine(
          id: 10,
          name: 'Ironing Station 01',
          type: 'Ironing Station',
          capacityKg: 6,
          price: 80,
          status: MachineStatus.available,
        ),
        Machine(
          id: 11,
          name: 'Ironing Station 02',
          type: 'Ironing Station',
          capacityKg: 8,
          price: 95,
          status: MachineStatus.available,
        ),
        Machine(
          id: 12,
          name: 'Ironing Station 03',
          type: 'Ironing Station',
          capacityKg: 10,
          price: 110,
          status: MachineStatus.maintenance,
        ),
      ]);
    }

    if (_customers.isEmpty) {
      _customers.addAll(const [
        Customer(
          id: 1,
          fullName: 'Walk-in Customer',
          phone: '9999999999',
          preferredWasherSizeKg: 8,
          preferredDetergentAddOn: 'Fresh Scent',
          preferredDryerDurationMinutes: 25,
        ),
        Customer(
          id: 2,
          fullName: 'Anita Rao',
          phone: '9876543210',
          preferredWasherSizeKg: 11,
          preferredDetergentAddOn: 'Gentle Care',
          preferredDryerDurationMinutes: 35,
        ),
        Customer(
          id: 3,
          fullName: 'Rakesh Menon',
          phone: '9123456780',
          preferredWasherSizeKg: 9,
          preferredDetergentAddOn: 'Stain Guard',
          preferredDryerDurationMinutes: 25,
        ),
      ]);
    }

    if (_orders.isEmpty) {
      final now = DateTime.now();
      _orders.addAll([
        Order(
          id: 1,
          machineId: 1,
          customerId: 2,
          createdByUserId: 1,
          serviceType: 'WASH',
          selectedServices: const [
            LaundryService.washing,
            LaundryService.drying,
          ],
          amount: 255,
          status: OrderStatus.inProgress,
          paymentMethod: 'Counter Booking',
          paymentStatus: PaymentStatus.paid,
          paymentReference: 'ORD-SEED01',
          timestamp: now.subtract(const Duration(minutes: 14)),
          loadSizeKg: 11,
          washOption: 'Gentle Wash',
          dryerMachineId: 7,
        ),
        Order(
          id: 2,
          machineId: 4,
          customerId: 1,
          createdByUserId: 1,
          serviceType: 'WASH',
          selectedServices: const [
            LaundryService.washing,
            LaundryService.drying,
          ],
          amount: 300,
          status: OrderStatus.completed,
          paymentMethod: 'UPI QR',
          paymentStatus: PaymentStatus.paid,
          paymentReference: 'ORD-SEED02',
          timestamp: now.subtract(const Duration(days: 1, hours: 2)),
          loadSizeKg: 9,
          washOption: 'Specific Wash',
          dryerMachineId: 8,
        ),
        Order(
          id: 3,
          machineId: 5,
          customerId: 3,
          createdByUserId: 1,
          serviceType: 'WASH',
          selectedServices: const [
            LaundryService.washing,
            LaundryService.drying,
          ],
          amount: 330,
          status: OrderStatus.booked,
          paymentMethod: 'Counter Booking',
          paymentStatus: PaymentStatus.pending,
          paymentReference: 'ORD-SEED03',
          timestamp: now.add(const Duration(hours: 3)),
          loadSizeKg: 11,
          washOption: 'Gentle Wash',
          dryerMachineId: 9,
        ),
      ]);

      final machineIndex = _machines.indexWhere((item) => item.id == 1);
      if (machineIndex != -1) {
        _machines[machineIndex] = _machines[machineIndex].copyWith(
          status: MachineStatus.inUse,
          currentOrderId: 1,
          cycleStartedAt: now.subtract(const Duration(minutes: 14)),
          cycleEndsAt: now.add(const Duration(minutes: 21)),
        );
      }
    }

    _customerCounter = max(_customerCounter, _customers.length);
    _orderCounter = max(_orderCounter, _orders.length);
    _reservationCounter = max(_reservationCounter, _reservations.length);
  }

  Future<AuthSession?> login(String username, String pin) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    for (final user in _users) {
      if (user.username == username && user.pin == pin) {
        return AuthSession(
          accessToken: 'demo-token-${user.id}',
          refreshToken: 'demo-refresh-${user.id}',
          user: user,
        );
      }
    }

    return null;
  }

  Future<List<Machine>> getAvailableMachines() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _loadPersistedState();
    await _reconcileMachineStates();
    return _machines
        .where((machine) => machine.status == MachineStatus.available)
        .toList();
  }

  Future<List<Machine>> getMachines() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _loadPersistedState();
    await _reconcileMachineStates();
    return List<Machine>.from(_machines);
  }

  Future<Machine?> getMachineById(int machineId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    await _reconcileMachineStates();
    for (final machine in _machines) {
      if (machine.id == machineId) {
        return machine;
      }
    }
    return null;
  }

  Future<Customer?> getCustomerByPhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final normalizedPhone = phone.trim();
    for (final customer in _customers) {
      if (customer.phone == normalizedPhone) {
        return customer;
      }
    }
    return null;
  }

  Future<Customer> saveWalkInCustomer({
    required String fullName,
    required String phone,
    int? preferredWasherSizeKg,
    String? preferredDetergentAddOn,
    int? preferredDryerDurationMinutes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final normalizedPhone = phone.trim();
    final existingIndex = _customers.indexWhere(
      (customer) => customer.phone == normalizedPhone,
    );

    if (existingIndex != -1) {
      final existing = _customers[existingIndex];
      final updated = existing.copyWith(
        fullName: fullName,
        phone: normalizedPhone,
        preferredWasherSizeKg: preferredWasherSizeKg,
        preferredDetergentAddOn: preferredDetergentAddOn,
        preferredDryerDurationMinutes: preferredDryerDurationMinutes,
      );
      _customers[existingIndex] = updated;
      await _persistState();
      return updated;
    }

    final customer = Customer(
      id: ++_customerCounter,
      fullName: fullName,
      phone: normalizedPhone,
      preferredWasherSizeKg: preferredWasherSizeKg,
      preferredDetergentAddOn: preferredDetergentAddOn,
      preferredDryerDurationMinutes: preferredDryerDurationMinutes,
    );
    _customers.add(customer);
    await _persistState();
    return customer;
  }

  Future<List<Machine>> getReservableMachines({
    required String machineType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    await _reconcileMachineStates();
    return _machines.where((machine) {
      if (machine.type != machineType ||
          machine.status == MachineStatus.maintenance) {
        return false;
      }
      if (machine.status == MachineStatus.inUse &&
          machine.cycleEndsAt != null &&
          machine.cycleEndsAt!.isAfter(startTime)) {
        return false;
      }
      final hasReservationConflict = _reservations.any(
        (reservation) =>
            reservation.machineId == machine.id &&
            reservation.isBooked &&
            reservation.overlaps(startTime, endTime),
      );
      return !hasReservationConflict;
    }).toList();
  }

  Future<MachineReservation> createReservation({
    required Machine machine,
    required Customer customer,
    required DateTime startTime,
    required DateTime endTime,
    int? preferredWasherSizeKg,
    String? detergentAddOn,
    int? dryerDurationMinutes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await _loadPersistedState();
    final reservation = MachineReservation(
      id: ++_reservationCounter,
      machineId: machine.id,
      customerId: customer.id,
      startTime: startTime,
      endTime: endTime,
      status: ReservationStatus.booked,
      createdAt: DateTime.now(),
      preferredWasherSizeKg: preferredWasherSizeKg,
      detergentAddOn: detergentAddOn,
      dryerDurationMinutes: dryerDurationMinutes,
    );
    _reservations.insert(0, reservation);
    await _persistState();
    return reservation;
  }

  Future<Order> createPaidOrder({
    required Machine machine,
    required Customer customer,
    PosUser? user,
    required String paymentMethod,
    String referencePrefix = 'POS',
    String? paymentReference,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _loadPersistedState();
    final cycleStart = DateTime.now();
    final cycleEnd = cycleStart.add(machine.cycleDuration);
    final selectedServices = <String>[
      if (machine.isWasher) LaundryService.washing,
      if (machine.isDryer) LaundryService.drying,
      if (machine.isIroningStation) LaundryService.ironing,
    ];
    final order = Order(
      id: ++_orderCounter,
      machineId: machine.id,
      customerId: customer.id,
      createdByUserId: user?.id,
      serviceType: machine.type.toUpperCase(),
      selectedServices: selectedServices,
      amount: machine.price,
      status: OrderStatus.inProgress,
      paymentMethod: paymentMethod,
      paymentStatus: PaymentStatus.paid,
      paymentReference: paymentReference ?? _paymentReference(referencePrefix),
      timestamp: DateTime.now(),
      loadSizeKg: machine.capacityKg,
      washOption: machine.isWasher ? 'Standard Wash' : null,
    );
    _orders.insert(0, order);
    final machineIndex = _machines.indexWhere((item) => item.id == machine.id);
    if (machineIndex != -1) {
      _machines[machineIndex] = _machines[machineIndex].copyWith(
        status: MachineStatus.inUse,
        currentOrderId: order.id,
        cycleStartedAt: cycleStart,
        cycleEndsAt: cycleEnd,
      );
    }
    await _persistState();
    await _machineIntegration.startCycle(
      machine: machine,
      orderId: order.id,
      startedAt: cycleStart,
      endsAt: cycleEnd,
    );
    return order;
  }

  Future<PaymentSession> createPaymentSession({
    required double amount,
    required String paymentMethod,
    String referencePrefix = 'PAY',
    int attempt = 1,
    bool shouldFail = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final createdAt = DateTime.now();
    final record = _PaymentSessionRecord(
      id: ++_paymentSessionCounter,
      amount: amount,
      paymentMethod: paymentMethod,
      reference: _paymentReference(referencePrefix),
      qrPayload: 'upi://pay?am=${amount.toStringAsFixed(2)}',
      createdAt: createdAt,
      attempt: attempt,
      shouldFail: shouldFail,
    );
    _paymentSessions[record.id] = record;
    return _toPaymentSession(record, createdAt);
  }

  Future<PaymentSession> pollPaymentSession(int sessionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final record = _paymentSessions[sessionId];
    if (record == null) {
      throw StateError('Payment session not found: $sessionId');
    }
    return _toPaymentSession(record, DateTime.now());
  }

  Future<List<OrderHistoryItem>> getOrderHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _loadPersistedState();
    await _reconcileMachineStates();
    return _orders.map((order) {
      final machine =
          _machines.firstWhere((item) => item.id == order.machineId);
      final customer = _customers.firstWhere(
        (item) => item.id == order.customerId,
      );
      return OrderHistoryItem(
        order: order,
        machine: machine,
        customer: customer,
        dryerMachine: order.dryerMachineId == null
            ? null
            : _machines.firstWhere((item) => item.id == order.dryerMachineId),
        ironingMachine: order.ironingMachineId == null
            ? null
            : _machines.firstWhere((item) => item.id == order.ironingMachineId),
      );
    }).toList();
  }

  Future<OrderHistoryItem?> getOrderHistoryItemByOrderId(int orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    await _reconcileMachineStates();
    Order? foundOrder;
    for (final item in _orders) {
      if (item.id == orderId) {
        foundOrder = item;
      }
    }
    if (foundOrder == null) {
      return null;
    }
    final order = foundOrder;
    final customer =
        _customers.firstWhere((item) => item.id == order.customerId);
    final machine = _machines.firstWhere((item) => item.id == order.machineId);
    return OrderHistoryItem(
      order: order,
      machine: machine,
      customer: customer,
      dryerMachine: order.dryerMachineId == null
          ? null
          : _machines.firstWhere((item) => item.id == order.dryerMachineId),
      ironingMachine: order.ironingMachineId == null
          ? null
          : _machines.firstWhere((item) => item.id == order.ironingMachineId),
    );
  }

  Future<Order> createManualOrder({
    required String customerName,
    required String customerPhone,
    required int loadSizeKg,
    required List<String> selectedServices,
    String? washOption,
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required String orderStatus,
    String paymentMethod = 'Counter Booking',
    PosUser? user,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _loadPersistedState();
    final customer = await saveWalkInCustomer(
      fullName: customerName,
      phone: customerPhone,
      preferredWasherSizeKg: loadSizeKg,
    );
    final primaryMachine = washer ?? dryer ?? ironingStation;
    if (primaryMachine == null) {
      throw StateError('At least one machine assignment is required.');
    }
    final amount = [
      washer?.price,
      dryer?.price,
      ironingStation?.price,
    ].whereType<double>().fold<double>(0, (sum, value) => sum + value);
    final order = Order(
      id: ++_orderCounter,
      machineId: primaryMachine.id,
      customerId: customer.id,
      createdByUserId: user?.id,
      serviceType: selectedServices.map((item) => item.toUpperCase()).join('+'),
      selectedServices: selectedServices,
      amount: amount,
      status: orderStatus,
      paymentMethod: paymentMethod,
      paymentStatus: orderStatus == OrderStatus.booked
          ? PaymentStatus.pending
          : PaymentStatus.paid,
      paymentReference: _paymentReference('ORD'),
      timestamp: DateTime.now(),
      loadSizeKg: loadSizeKg,
      washOption: washOption,
      dryerMachineId: dryer?.id,
      ironingMachineId: ironingStation?.id,
    );
    _orders.insert(0, order);

    if (orderStatus == OrderStatus.inProgress) {
      final machineIndex =
          _machines.indexWhere((item) => item.id == primaryMachine.id);
      if (machineIndex != -1) {
        final cycleStart = DateTime.now();
        _machines[machineIndex] = _machines[machineIndex].copyWith(
          status: MachineStatus.inUse,
          currentOrderId: order.id,
          cycleStartedAt: cycleStart,
          cycleEndsAt: cycleStart.add(_machines[machineIndex].cycleDuration),
        );
        await _machineIntegration.startCycle(
          machine: _machines[machineIndex],
          orderId: order.id,
          startedAt: cycleStart,
          endsAt: cycleStart.add(_machines[machineIndex].cycleDuration),
        );
      }
    }

    await _persistState();
    return order;
  }

  Future<ActiveOrderSession?> getActiveOrderSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _loadPersistedState();
    final raw = await _preferences.getString(_activeOrderSessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return ActiveOrderSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<ActiveOrderSession> saveActiveOrderDraft({
    required String customerName,
    required String customerPhone,
    required int loadSizeKg,
    required List<String> selectedServices,
    String? washOption,
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required String paymentMethod,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final session = ActiveOrderSession(
      customerName: customerName,
      customerPhone: customerPhone,
      loadSizeKg: loadSizeKg,
      selectedServices: selectedServices,
      washOption: washOption,
      washerMachineId: washer?.id,
      dryerMachineId: dryer?.id,
      ironingMachineId: ironingStation?.id,
      paymentMethod: paymentMethod,
      stage: ActiveOrderSessionStage.draft,
      createdAt: DateTime.now(),
    );
    await _preferences.setString(
      _activeOrderSessionKey,
      jsonEncode(session.toJson()),
    );
    return session;
  }

  Future<ActiveOrderSession?> confirmActiveOrderSession({
    required String confirmedBy,
    PosUser? user,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final session = await getActiveOrderSession();
    if (session == null) {
      return null;
    }
    if (!session.isDraft) {
      return session;
    }

    final washer = session.washerMachineId == null
        ? null
        : await getMachineById(session.washerMachineId!);
    final dryer = session.dryerMachineId == null
        ? null
        : await getMachineById(session.dryerMachineId!);
    final ironingStation = session.ironingMachineId == null
        ? null
        : await getMachineById(session.ironingMachineId!);

    final order = await createManualOrder(
      customerName: session.customerName,
      customerPhone: session.customerPhone,
      loadSizeKg: session.loadSizeKg,
      selectedServices: session.selectedServices,
      washOption: session.washOption,
      washer: washer,
      dryer: dryer,
      ironingStation: ironingStation,
      orderStatus: OrderStatus.booked,
      paymentMethod: session.paymentMethod,
      user: user,
    );

    final bookedSession = session.copyWith(
      stage: ActiveOrderSessionStage.booked,
      confirmedBy: confirmedBy,
      orderId: order.id,
      createdAt: order.timestamp,
    );
    await _preferences.setString(
      _activeOrderSessionKey,
      jsonEncode(bookedSession.toJson()),
    );
    return bookedSession;
  }

  Future<ActiveOrderSession?> completeActiveOrderPayment({
    required String paymentReference,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final session = await getActiveOrderSession();
    if (session == null || session.orderId == null) {
      return null;
    }

    final orderIndex = _orders.indexWhere((item) => item.id == session.orderId);
    if (orderIndex == -1) {
      return null;
    }

    final updatedOrder = _orders[orderIndex].copyWith(
      status: OrderStatus.inProgress,
      paymentStatus: PaymentStatus.paid,
      paymentReference: paymentReference,
    );
    _orders[orderIndex] = updatedOrder;

    final startMachineId =
        session.washerMachineId ?? session.dryerMachineId ?? session.ironingMachineId;
    final machineIndex = _machines.indexWhere(
      (item) => item.id == startMachineId,
    );
    if (machineIndex != -1) {
      final cycleStart = DateTime.now();
      _machines[machineIndex] = _machines[machineIndex].copyWith(
        status: MachineStatus.inUse,
        currentOrderId: updatedOrder.id,
        cycleStartedAt: cycleStart,
        cycleEndsAt: cycleStart.add(_machines[machineIndex].cycleDuration),
      );
      await _machineIntegration.startCycle(
        machine: _machines[machineIndex],
        orderId: updatedOrder.id,
        startedAt: cycleStart,
        endsAt: cycleStart.add(_machines[machineIndex].cycleDuration),
      );
    }

    await _persistState();
    final paidSession = session.copyWith(
      stage: ActiveOrderSessionStage.paid,
      paymentReference: paymentReference,
    );
    await _preferences.setString(
      _activeOrderSessionKey,
      jsonEncode(paidSession.toJson()),
    );
    return paidSession;
  }

  Future<void> clearActiveOrderSession() async {
    await _preferences.remove(_activeOrderSessionKey);
  }

  Future<CustomerProfile?> getCustomerProfileByPhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _loadPersistedState();
    await _reconcileMachineStates();
    final normalizedPhone = phone.trim();
    Customer? foundCustomer;
    for (final item in _customers) {
      if (item.phone == normalizedPhone) {
        foundCustomer = item;
      }
    }
    if (foundCustomer == null) {
      return null;
    }
    final customer = foundCustomer;

    final orders =
        _orders.where((order) => order.customerId == customer.id).map((order) {
      final machine =
          _machines.firstWhere((item) => item.id == order.machineId);
      return OrderHistoryItem(
        order: order,
        machine: machine,
        customer: customer,
      );
    }).toList();

    final usageByMachine = <int, int>{};
    for (final item in orders) {
      usageByMachine.update(
        item.machine.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final favoriteMachines = usageByMachine.entries
        .map(
          (entry) => FavoriteMachineStat(
            machine: _machines.firstWhere((item) => item.id == entry.key),
            usageCount: entry.value,
          ),
        )
        .toList()
      ..sort((left, right) => right.usageCount.compareTo(left.usageCount));

    final upcomingReservations = _reservations
        .where(
          (reservation) =>
              reservation.customerId == customer.id &&
              reservation.isBooked &&
              reservation.endTime.isAfter(DateTime.now()),
        )
        .map(
          (reservation) => ReservationHistoryItem(
            reservation: reservation,
            machine: _machines.firstWhere(
              (item) => item.id == reservation.machineId,
            ),
            customer: customer,
          ),
        )
        .toList()
      ..sort(
        (left, right) => left.reservation.startTime.compareTo(
          right.reservation.startTime,
        ),
      );

    return CustomerProfile(
      customer: customer,
      orders: orders,
      totalSpent: orders.fold<double>(
        0,
        (total, item) => total + item.order.amount,
      ),
      totalVisits: orders.length,
      favoriteMachines: favoriteMachines.take(3).toList(),
      upcomingReservations: upcomingReservations,
    );
  }

  Future<void> markMachinePickedUp(int machineId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final machineIndex = _machines.indexWhere((item) => item.id == machineId);
    if (machineIndex == -1) {
      return;
    }
    _machines[machineIndex] = _machines[machineIndex].copyWith(
      status: MachineStatus.available,
      currentOrderId: null,
      cycleStartedAt: null,
      cycleEndsAt: null,
    );
    await _persistState();
    await _machineIntegration.clearMachine(machine: _machines[machineIndex]);
  }

  Future<Order?> markRefundProcessed(int orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final orderIndex = _orders.indexWhere((item) => item.id == orderId);
    if (orderIndex == -1) {
      return null;
    }
    final updated = _orders[orderIndex].copyWith(
      paymentStatus: PaymentStatus.refunded,
    );
    _orders[orderIndex] = updated;
    await _persistState();
    return updated;
  }

  String _paymentReference(String prefix) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final suffix =
        List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix-$suffix';
  }

  PaymentSession _toPaymentSession(
    _PaymentSessionRecord record,
    DateTime checkedAt,
  ) {
    final secondsElapsed = checkedAt.difference(record.createdAt).inSeconds;
    final status = secondsElapsed >= 8
        ? (record.shouldFail
            ? PaymentSessionStatus.failed
            : PaymentSessionStatus.paid)
        : secondsElapsed >= 4
            ? PaymentSessionStatus.processing
            : PaymentSessionStatus.awaitingScan;

    return PaymentSession(
      id: record.id,
      amount: record.amount,
      paymentMethod: record.paymentMethod,
      reference: record.reference,
      qrPayload: record.qrPayload,
      status: status,
      attempt: record.attempt,
      createdAt: record.createdAt,
      checkedAt: checkedAt,
      failureReason: status == PaymentSessionStatus.failed
          ? 'The bank did not confirm this payment in time. Please retry with the same QR flow.'
          : null,
    );
  }

  Future<void> _ensureMachineIntegrationStarted() async {
    if (_machineIntegrationStarted) {
      return;
    }
    _machineIntegrationStarted = true;
    await _machineIntegration.initialize();
    _machineIntegrationSubscription = _machineIntegration.events.listen(
      (event) async {
        await _applyMachineIntegrationEvent(event);
      },
    );
    await _reconcileMachineStates();
  }

  Future<void> _reconcileMachineStates() async {
    final reconciled = await _machineIntegration.reconcileMachines(
      List<Machine>.from(_machines),
    );
    if (_machinesEqual(_machines, reconciled)) {
      return;
    }
    _machines
      ..clear()
      ..addAll(reconciled);
    await _persistState();
  }

  Future<void> _applyMachineIntegrationEvent(
    MachineIntegrationEvent event,
  ) async {
    await _loadPersistedState();
    final machineIndex = _machines.indexWhere(
      (machine) => machine.id == event.machineId,
    );
    if (machineIndex == -1) {
      return;
    }

    final machine = _machines[machineIndex];
    _machines[machineIndex] = machine.copyWith(
      status: event.status ?? machine.status,
      currentOrderId: event.clearOrderAssignment
          ? null
          : event.currentOrderId ?? machine.currentOrderId,
      cycleStartedAt: event.clearCycleWindow
          ? null
          : event.cycleStartedAt ?? machine.cycleStartedAt,
      cycleEndsAt:
          event.clearCycleWindow ? null : event.cycleEndsAt ?? machine.cycleEndsAt,
    );
    await _persistState();
  }

  bool _machinesEqual(List<Machine> left, List<Machine> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      final leftMachine = left[index];
      final rightMachine = right[index];
      if (leftMachine.id != rightMachine.id ||
          leftMachine.status != rightMachine.status ||
          leftMachine.currentOrderId != rightMachine.currentOrderId ||
          leftMachine.cycleStartedAt != rightMachine.cycleStartedAt ||
          leftMachine.cycleEndsAt != rightMachine.cycleEndsAt) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadPersistedState() async {
    final customersJson = await _preferences.getString(_customersKey);
    final ordersJson = await _preferences.getString(_ordersKey);
    final machinesJson = await _preferences.getString(_machinesKey);
    final reservationsJson = await _preferences.getString(_reservationsKey);

    _customers
      ..clear()
      ..addAll(_decodeCustomers(customersJson));
    _orders
      ..clear()
      ..addAll(_decodeOrders(ordersJson));
    _machines
      ..clear()
      ..addAll(_decodeMachines(machinesJson));
    _reservations
      ..clear()
      ..addAll(_decodeReservations(reservationsJson));

    _customerCounter =
        await _preferences.getInt(_customerCounterKey) ?? _customers.length;
    _orderCounter =
        await _preferences.getInt(_orderCounterKey) ?? _orders.length;
    _paymentSessionCounter =
        await _preferences.getInt(_paymentSessionCounterKey) ?? 0;
    _reservationCounter = await _preferences.getInt(_reservationCounterKey) ??
        _reservations.length;
  }

  Future<void> _persistState() async {
    await _preferences.setString(
      _customersKey,
      jsonEncode(
        _customers
            .map(
              (customer) => {
                'id': customer.id,
                'fullName': customer.fullName,
                'phone': customer.phone,
                'preferredWasherSizeKg': customer.preferredWasherSizeKg,
                'preferredDetergentAddOn': customer.preferredDetergentAddOn,
                'preferredDryerDurationMinutes':
                    customer.preferredDryerDurationMinutes,
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _ordersKey,
      jsonEncode(
        _orders
            .map(
              (order) => {
                'id': order.id,
                'machineId': order.machineId,
                'customerId': order.customerId,
                'createdByUserId': order.createdByUserId,
                'serviceType': order.serviceType,
                'selectedServices': order.selectedServices,
                'amount': order.amount,
                'status': order.status,
                'paymentMethod': order.paymentMethod,
                'paymentStatus': order.paymentStatus,
                'paymentReference': order.paymentReference,
                'timestamp': order.timestamp.toIso8601String(),
                'loadSizeKg': order.loadSizeKg,
                'washOption': order.washOption,
                'dryerMachineId': order.dryerMachineId,
                'ironingMachineId': order.ironingMachineId,
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _machinesKey,
      jsonEncode(
        _machines
            .map(
              (machine) => {
                'id': machine.id,
                'name': machine.name,
                'type': machine.type,
                'capacityKg': machine.capacityKg,
                'price': machine.price,
                'status': machine.status,
                'currentOrderId': machine.currentOrderId,
                'cycleStartedAt': machine.cycleStartedAt?.toIso8601String(),
                'cycleEndsAt': machine.cycleEndsAt?.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _reservationsKey,
      jsonEncode(
        _reservations
            .map(
              (reservation) => {
                'id': reservation.id,
                'machineId': reservation.machineId,
                'customerId': reservation.customerId,
                'startTime': reservation.startTime.toIso8601String(),
                'endTime': reservation.endTime.toIso8601String(),
                'status': reservation.status,
                'createdAt': reservation.createdAt.toIso8601String(),
                'preferredWasherSizeKg': reservation.preferredWasherSizeKg,
                'detergentAddOn': reservation.detergentAddOn,
                'dryerDurationMinutes': reservation.dryerDurationMinutes,
              },
            )
            .toList(),
      ),
    );
    await _preferences.setInt(_customerCounterKey, _customerCounter);
    await _preferences.setInt(_orderCounterKey, _orderCounter);
    await _preferences.setInt(
      _paymentSessionCounterKey,
      _paymentSessionCounter,
    );
    await _preferences.setInt(_reservationCounterKey, _reservationCounter);
  }

  List<Customer> _decodeCustomers(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => Customer(
            id: item['id'] as int,
            fullName: item['fullName'] as String,
            phone: item['phone'] as String,
            preferredWasherSizeKg: item['preferredWasherSizeKg'] as int?,
            preferredDetergentAddOn: item['preferredDetergentAddOn'] as String?,
            preferredDryerDurationMinutes:
                item['preferredDryerDurationMinutes'] as int?,
          ),
        )
        .toList();
  }

  List<Order> _decodeOrders(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => Order(
            id: item['id'] as int,
            machineId: item['machineId'] as int,
            customerId: item['customerId'] as int,
            createdByUserId: item['createdByUserId'] as int?,
            serviceType: item['serviceType'] as String,
            selectedServices:
                (item['selectedServices'] as List<dynamic>? ?? const [])
                    .map((entry) => entry as String)
                    .toList(),
            amount: (item['amount'] as num).toDouble(),
            status: item['status'] as String,
            paymentMethod: item['paymentMethod'] as String,
            paymentStatus: item['paymentStatus'] as String,
            paymentReference: item['paymentReference'] as String,
            timestamp: DateTime.parse(item['timestamp'] as String),
            loadSizeKg: item['loadSizeKg'] as int?,
            washOption: item['washOption'] as String?,
            dryerMachineId: item['dryerMachineId'] as int?,
            ironingMachineId: item['ironingMachineId'] as int?,
          ),
        )
        .toList();
  }

  List<Machine> _decodeMachines(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => Machine(
            id: item['id'] as int,
            name: item['name'] as String,
            type: item['type'] as String,
            capacityKg: item['capacityKg'] as int,
            price: (item['price'] as num).toDouble(),
            status: item['status'] as String,
            currentOrderId: item['currentOrderId'] as int?,
            cycleStartedAt: item['cycleStartedAt'] == null
                ? null
                : DateTime.parse(item['cycleStartedAt'] as String),
            cycleEndsAt: item['cycleEndsAt'] == null
                ? null
                : DateTime.parse(item['cycleEndsAt'] as String),
          ),
        )
        .toList();
  }

  List<MachineReservation> _decodeReservations(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => MachineReservation(
            id: item['id'] as int,
            machineId: item['machineId'] as int,
            customerId: item['customerId'] as int,
            startTime: DateTime.parse(item['startTime'] as String),
            endTime: DateTime.parse(item['endTime'] as String),
            status: item['status'] as String,
            createdAt: DateTime.parse(item['createdAt'] as String),
            preferredWasherSizeKg: item['preferredWasherSizeKg'] as int?,
            detergentAddOn: item['detergentAddOn'] as String?,
            dryerDurationMinutes: item['dryerDurationMinutes'] as int?,
          ),
        )
        .toList();
  }
}

class _PaymentSessionRecord {
  const _PaymentSessionRecord({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
    required this.qrPayload,
    required this.createdAt,
    required this.attempt,
    required this.shouldFail,
  });

  final int id;
  final double amount;
  final String paymentMethod;
  final String reference;
  final String qrPayload;
  final DateTime createdAt;
  final int attempt;
  final bool shouldFail;
}
