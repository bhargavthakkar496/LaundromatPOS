// ignore_for_file: annotate_overrides

import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_order_session.dart';
import '../models/customer.dart';
import '../models/customer_profile.dart';
import '../models/delivery_task.dart';
import '../models/garment_item.dart';
import '../models/inventory.dart';
import '../models/maintenance.dart';
import '../models/machine.dart';
import '../models/machine_reservation.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../models/pickup_task.dart';
import '../models/pos_user.dart';
import '../models/pricing.dart';
import '../models/refund_request.dart';
import '../models/reservation_history_item.dart';
import '../models/auth_session.dart';
import '../models/revenue.dart';
import '../models/staff.dart';
import '../services/machine_integration_factory.dart';
import '../services/machine_integration_service.dart';
import '../services/revenue_reporting_service.dart';
import 'pos_repository.dart';

class DemoPosRepository implements PosRepository {
  static const _customersKey = 'customers_v1';
  static const _ordersKey = 'orders_v1';
  static const _machinesKey = 'machines_v1';
  static const _reservationsKey = 'reservations_v1';
  static const _pricingServiceFeesKey = 'pricing_service_fees_v1';
  static const _pricingCampaignsKey = 'pricing_campaigns_v1';
  static const _maintenanceRecordsKey = 'maintenance_records_v1';
  static const _refundRequestsKey = 'refund_requests_v1';
  static const _deliveryTasksKey = 'delivery_tasks_v1';
  static const _pickupTasksKey = 'pickup_tasks_v1';
  static const _dayEndCheckoutsKey = 'day_end_checkouts_v1';
  static const _staffMembersKey = 'staff_members_v1';
  static const _staffShiftsKey = 'staff_shifts_v1';
  static const _staffLeaveRequestsKey = 'staff_leave_requests_v1';
  static const _staffPayoutsKey = 'staff_payouts_v1';
  static const _activeOrderSessionKey = 'active_order_session_v1';
  static const _customerCounterKey = 'customer_counter_v1';
  static const _orderCounterKey = 'order_counter_v1';
  static const _paymentSessionCounterKey = 'payment_session_counter_v1';
  static const _reservationCounterKey = 'reservation_counter_v1';
  static const _pricingCampaignCounterKey = 'pricing_campaign_counter_v1';
  static const _maintenanceRecordCounterKey = 'maintenance_record_counter_v1';
  static const _refundRequestCounterKey = 'refund_request_counter_v1';
  static const _dayEndCheckoutCounterKey = 'day_end_checkout_counter_v1';
  static const _staffShiftCounterKey = 'staff_shift_counter_v1';
  static const _staffLeaveRequestCounterKey = 'staff_leave_request_counter_v1';
  static const _staffPayoutCounterKey = 'staff_payout_counter_v1';

  final List<PosUser> _users = [];
  final List<Machine> _machines = [];
  final List<Customer> _customers = [];
  final List<Order> _orders = [];
  final List<MachineReservation> _reservations = [];
  final List<PricingServiceFee> _pricingServiceFees = [];
  final List<PricingCampaign> _pricingCampaigns = [];
  final List<MaintenanceRecord> _maintenanceRecords = [];
  final List<RefundRequest> _refundRequests = [];
  final List<DeliveryTask> _deliveryTasks = [];
  final List<PickupTask> _pickupTasks = [];
  final List<DayEndCheckout> _dayEndCheckouts = [];
  final List<StaffMember> _staffMembers = [];
  final List<StaffShift> _staffShifts = [];
  final List<StaffLeaveRequest> _staffLeaveRequests = [];
  final List<StaffPayout> _staffPayouts = [];
  final Map<int, _PaymentSessionRecord> _paymentSessions = {};
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final MachineIntegrationService _machineIntegration;

  StreamSubscription<MachineIntegrationEvent>? _machineIntegrationSubscription;
  bool _machineIntegrationStarted = false;

  int _customerCounter = 0;
  int _orderCounter = 0;
  int _paymentSessionCounter = 0;
  int _reservationCounter = 0;
  int _pricingCampaignCounter = 0;
  int _maintenanceRecordCounter = 0;
  int _refundRequestCounter = 0;
  int _dayEndCheckoutCounter = 0;
  int _staffShiftCounter = 0;
  int _staffLeaveRequestCounter = 0;
  int _staffPayoutCounter = 0;
  int _inventoryRestockRequestCounter = 0;
  final List<InventoryRestockRequest> _inventoryRestockRequests = [];
  final List<InventoryStockMovement> _inventoryStockMovements = [
    InventoryStockMovement(
      id: 1,
      inventoryItemId: 1,
      movementType: InventoryStockMovementType.received,
      quantityDelta: 12,
      balanceAfter: 12,
      referenceType: 'PO',
      referenceId: 'PO-INV-1001',
      notes: 'Supplier delivery for premium detergent shelf.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 10, 9),
    ),
    InventoryStockMovement(
      id: 2,
      inventoryItemId: 1,
      movementType: InventoryStockMovementType.consumed,
      quantityDelta: -4,
      balanceAfter: 8,
      referenceType: 'SHIFT_USAGE',
      referenceId: 'SHIFT-401',
      notes: 'Washer bay daily detergent consumption.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 13, 18),
    ),
    InventoryStockMovement(
      id: 3,
      inventoryItemId: 1,
      movementType: InventoryStockMovementType.damaged,
      quantityDelta: -1,
      balanceAfter: 7,
      referenceType: 'INCIDENT',
      referenceId: 'INC-DET-01',
      notes: 'One bag torn during unloading.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 14, 11),
    ),
    InventoryStockMovement(
      id: 4,
      inventoryItemId: 1,
      movementType: InventoryStockMovementType.consumed,
      quantityDelta: -2,
      balanceAfter: 5,
      referenceType: 'SHIFT_USAGE',
      referenceId: 'SHIFT-404',
      notes: 'Consumed during express wash cycle run.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 16, 18),
    ),
    InventoryStockMovement(
      id: 5,
      inventoryItemId: 2,
      movementType: InventoryStockMovementType.received,
      quantityDelta: 20,
      balanceAfter: 20,
      referenceType: 'PO',
      referenceId: 'PO-INV-1004',
      notes: 'Bulk detergent top-up from Sparkle Supply Co.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 4, 10),
    ),
    InventoryStockMovement(
      id: 6,
      inventoryItemId: 2,
      movementType: InventoryStockMovementType.transferred,
      quantityDelta: -4,
      balanceAfter: 16,
      referenceType: 'TRANSFER',
      referenceId: 'TRN-DET-22',
      notes: 'Moved cartons to branch floor stock.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 8, 14),
    ),
    InventoryStockMovement(
      id: 7,
      inventoryItemId: 2,
      movementType: InventoryStockMovementType.consumed,
      quantityDelta: -2,
      balanceAfter: 14,
      referenceType: 'SHIFT_USAGE',
      referenceId: 'SHIFT-395',
      notes: 'Routine stock issue to wash line.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 10, 19),
    ),
    InventoryStockMovement(
      id: 8,
      inventoryItemId: 5,
      movementType: InventoryStockMovementType.received,
      quantityDelta: 6,
      balanceAfter: 6,
      referenceType: 'PO',
      referenceId: 'PO-INV-1002',
      notes: 'Disinfectant delivery received.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 3, 9),
    ),
    InventoryStockMovement(
      id: 9,
      inventoryItemId: 5,
      movementType: InventoryStockMovementType.consumed,
      quantityDelta: -3,
      balanceAfter: 3,
      referenceType: 'SHIFT_USAGE',
      referenceId: 'SHIFT-399',
      notes: 'Sanitizing drum-clean cycle stock issue.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 7, 18),
    ),
    InventoryStockMovement(
      id: 10,
      inventoryItemId: 5,
      movementType: InventoryStockMovementType.damaged,
      quantityDelta: -1,
      balanceAfter: 2,
      referenceType: 'INCIDENT',
      referenceId: 'INC-DIS-03',
      notes: 'Bottle leak found during shelf check.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 4, 9, 12),
    ),
    InventoryStockMovement(
      id: 11,
      inventoryItemId: 6,
      movementType: InventoryStockMovementType.manualCorrection,
      quantityDelta: -2,
      balanceAfter: 2,
      referenceType: 'AUDIT',
      referenceId: 'AUD-2201',
      notes: 'Physical count corrected after audit variance.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 3, 28, 16),
    ),
    InventoryStockMovement(
      id: 12,
      inventoryItemId: 6,
      movementType: InventoryStockMovementType.consumed,
      quantityDelta: -2,
      balanceAfter: 0,
      referenceType: 'SHIFT_USAGE',
      referenceId: 'SHIFT-388',
      notes: 'Softener pouch stock fully consumed.',
      performedByName: 'Store Admin',
      occurredAt: DateTime(2026, 3, 30, 18),
    ),
  ];

  static final List<InventoryItem> _inventoryItems = [
    const InventoryItem(
      id: 1,
      sku: 'DET-ULTRA-5KG',
      barcode: '8901001000011',
      name: 'Ultra Wash Powder',
      category: 'Detergent',
      supplier: 'Sparkle Supply Co',
      branch: 'Main Branch',
      location: 'Aisle A1',
      unit: 'bags',
      unitType: 'PACKAGE',
      packSize: '5 kg bag',
      quantityOnHand: 5,
      reorderPoint: 8,
      parLevel: 12,
      unitCost: 410,
      sellingPrice: 560,
      stockValue: 2050,
      lastRestockedAt: null,
      expiresAt: null,
      stockStatus: InventoryStockStatus.low,
      isActive: true,
      reorderUrgencyScore: 3,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
    const InventoryItem(
      id: 2,
      sku: 'DET-ECO-4KG',
      barcode: '8901001000012',
      name: 'Eco Fresh Powder',
      category: 'Detergent',
      supplier: 'Sparkle Supply Co',
      branch: 'Main Branch',
      location: 'Aisle A1',
      unit: 'bags',
      unitType: 'PACKAGE',
      packSize: '4 kg bag',
      quantityOnHand: 14,
      reorderPoint: 6,
      parLevel: 10,
      unitCost: 360,
      sellingPrice: 495,
      stockValue: 5040,
      lastRestockedAt: null,
      expiresAt: null,
      stockStatus: InventoryStockStatus.healthy,
      isActive: true,
      reorderUrgencyScore: 0,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
    const InventoryItem(
      id: 3,
      sku: 'SOAP-HAND-12',
      barcode: '8901001000014',
      name: 'Hand Soap Backup',
      category: 'Soap',
      supplier: 'FreshFold Traders',
      branch: 'Main Branch',
      location: 'Aisle B2',
      unit: 'bars',
      unitType: 'UNIT',
      packSize: '12-bar sleeve',
      quantityOnHand: 4,
      reorderPoint: 6,
      parLevel: 10,
      unitCost: 34,
      sellingPrice: 48,
      stockValue: 136,
      lastRestockedAt: null,
      expiresAt: null,
      stockStatus: InventoryStockStatus.low,
      isActive: true,
      reorderUrgencyScore: 2,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
    const InventoryItem(
      id: 4,
      sku: 'LIQ-EXP-20L',
      barcode: '8901001000016',
      name: 'Express Liquid',
      category: 'Liquid',
      supplier: 'Sparkle Supply Co',
      branch: 'North Branch',
      location: 'Aisle C1',
      unit: 'canisters',
      unitType: 'LIQUID_CONTAINER',
      packSize: '20 L canister',
      quantityOnHand: 3,
      reorderPoint: 5,
      parLevel: 8,
      unitCost: 590,
      sellingPrice: null,
      stockValue: 1770,
      lastRestockedAt: null,
      expiresAt: null,
      stockStatus: InventoryStockStatus.low,
      isActive: true,
      reorderUrgencyScore: 2,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
    InventoryItem(
      id: 5,
      sku: 'DIS-WIPE-5L',
      barcode: '8901001000017',
      name: 'Wipe Down Spray',
      category: 'Disinfectant',
      supplier: 'CleanChem Distributors',
      branch: 'Main Branch',
      location: 'Aisle D1',
      unit: 'bottles',
      unitType: 'LIQUID_CONTAINER',
      packSize: '5 L bottle',
      quantityOnHand: 2,
      reorderPoint: 4,
      parLevel: 6,
      unitCost: 180,
      sellingPrice: null,
      stockValue: 360,
      lastRestockedAt: null,
      expiresAt: DateTime(2026, 4, 25),
      stockStatus: InventoryStockStatus.low,
      isActive: true,
      reorderUrgencyScore: 2,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
    InventoryItem(
      id: 6,
      sku: 'SOFT-BABY-5L',
      barcode: '8901001000022',
      name: 'Baby Soft Mix',
      category: 'Softener',
      supplier: 'FreshFold Traders',
      branch: 'North Branch',
      location: 'Aisle F2',
      unit: 'pouches',
      unitType: 'PACKAGE',
      packSize: '5 L pouch',
      quantityOnHand: 0,
      reorderPoint: 4,
      parLevel: 8,
      unitCost: 165,
      sellingPrice: 230,
      stockValue: 0,
      lastRestockedAt: null,
      expiresAt: DateTime(2026, 4, 29),
      stockStatus: InventoryStockStatus.outOfStock,
      isActive: true,
      reorderUrgencyScore: 4,
      activeRestockRequestId: null,
      activeRestockRequestStatus: null,
      activeRestockRequestNumber: null,
      activeRestockRequestedQuantity: null,
      activeRestockOperatorRemarks: null,
      activeRestockApprovedAt: null,
    ),
  ];

  DemoPosRepository({
    MachineIntegrationService? machineIntegration,
  }) : _machineIntegration =
            machineIntegration ?? createDefaultMachineIntegrationService();

  Future<void> initialize() async {
    await _loadPersistedState();
    var shouldPersist = false;
    if (_users.isEmpty) {
      seedDemoData();
      shouldPersist = true;
    }
    if (_pricingServiceFees.isEmpty) {
      _pricingServiceFees.addAll(_defaultPricingServiceFees());
      shouldPersist = true;
    }
    if (_maintenanceRecords.isEmpty) {
      final seededRecords = _defaultMaintenanceRecords();
      if (seededRecords.isNotEmpty) {
        _maintenanceRecords.addAll(seededRecords);
        _maintenanceRecordCounter = seededRecords
            .map((item) => item.id)
            .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);
        shouldPersist = true;
      }
    }
    if (_staffMembers.isEmpty) {
      _staffMembers.addAll(_defaultStaffMembers());
      shouldPersist = true;
    }
    if (_staffShifts.isEmpty) {
      final shifts = _defaultStaffShifts();
      if (shifts.isNotEmpty) {
        _staffShifts.addAll(shifts);
        _staffShiftCounter = shifts
            .map((item) => item.id)
            .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);
        shouldPersist = true;
      }
    }
    if (_staffLeaveRequests.isEmpty) {
      final leaveRequests = _defaultStaffLeaveRequests();
      if (leaveRequests.isNotEmpty) {
        _staffLeaveRequests.addAll(leaveRequests);
        _staffLeaveRequestCounter = leaveRequests
            .map((item) => item.id)
            .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);
        shouldPersist = true;
      }
    }
    if (_staffPayouts.isEmpty) {
      final payouts = _defaultStaffPayouts();
      if (payouts.isNotEmpty) {
        _staffPayouts.addAll(payouts);
        _staffPayoutCounter = payouts
            .map((item) => item.id)
            .fold<int>(0, (maxId, id) => id > maxId ? id : maxId);
        shouldPersist = true;
      }
    }
    if (_pricingCampaignCounter < _pricingCampaigns.length) {
      _pricingCampaignCounter = _pricingCampaigns.length;
      shouldPersist = true;
    }
    if (_maintenanceRecordCounter < _maintenanceRecords.length) {
      _maintenanceRecordCounter = _maintenanceRecords.length;
      shouldPersist = true;
    }
    if (_staffShiftCounter < _staffShifts.length) {
      _staffShiftCounter = _staffShifts.length;
      shouldPersist = true;
    }
    if (_staffLeaveRequestCounter < _staffLeaveRequests.length) {
      _staffLeaveRequestCounter = _staffLeaveRequests.length;
      shouldPersist = true;
    }
    if (_staffPayoutCounter < _staffPayouts.length) {
      _staffPayoutCounter = _staffPayouts.length;
      shouldPersist = true;
    }
    if (shouldPersist) {
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
    if (machine.status == MachineStatus.maintenance) {
      throw StateError('This machine is currently under maintenance.');
    }
    final cycleStart = DateTime.now();
    final cycleEnd = cycleStart.add(machine.cycleDuration);
    final selectedServices = <String>[
      if (machine.isWasher) LaundryService.washing,
      if (machine.isDryer) LaundryService.drying,
      if (machine.isIroningStation) LaundryService.ironing,
    ];
    final quote = _buildPricingQuote(
      washer: machine.isWasher ? machine : null,
      dryer: machine.isDryer ? machine : null,
      ironingStation: machine.isIroningStation ? machine : null,
      selectedServices: selectedServices,
    );
    final order = Order(
      id: ++_orderCounter,
      machineId: machine.id,
      customerId: customer.id,
      createdByUserId: user?.id,
      serviceType: machine.type.toUpperCase(),
      selectedServices: selectedServices,
      amount: quote.finalTotal,
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
    List<GarmentItem> garmentItems = const [],
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
    final assignedMachines =
        [washer, dryer, ironingStation].whereType<Machine>();
    if (assignedMachines
        .any((machine) => machine.status == MachineStatus.maintenance)) {
      throw StateError('One or more assigned machines are under maintenance.');
    }
    final amount = garmentItems.isNotEmpty
        ? garmentItems.fold<double>(0, (sum, item) => sum + item.lineTotal)
        : _buildPricingQuote(
            washer: washer,
            dryer: dryer,
            ironingStation: ironingStation,
            selectedServices: selectedServices,
          ).finalTotal;
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
      garmentItems: garmentItems,
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
    List<GarmentItem> garmentItems = const [],
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
      garmentItems: garmentItems,
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
      garmentItems: session.garmentItems,
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

    final startMachineId = session.washerMachineId ??
        session.dryerMachineId ??
        session.ironingMachineId;
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

  @override
  Future<InventoryDashboard> getInventoryDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final categories = <String, List<InventoryItem>>{};
    for (final item in _inventoryItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    return InventoryDashboard(
      metrics: InventoryDashboardMetrics(
        lowStockCount: _inventoryItems
            .where((item) => item.stockStatus == InventoryStockStatus.low)
            .length,
        outOfStockCount: _inventoryItems
            .where(
              (item) => item.stockStatus == InventoryStockStatus.outOfStock,
            )
            .length,
        stockValue: _inventoryItems.fold<double>(
          0,
          (sum, item) => sum + item.stockValue,
        ),
        pendingPurchaseOrders: 2 +
            _inventoryRestockRequests
                .where(
                  (item) =>
                      item.status == InventoryRestockRequestStatus.approved,
                )
                .length,
        expiringSoonCount:
            _inventoryItems.where((item) => item.expiresAt != null).length,
      ),
      categories: categories.entries
          .map(
            (entry) => InventoryCategorySummary(
              category: entry.key,
              itemCount: entry.value.length,
              lowStockCount: entry.value
                  .where((item) => item.stockStatus == InventoryStockStatus.low)
                  .length,
              outOfStockCount: entry.value
                  .where(
                    (item) =>
                        item.stockStatus == InventoryStockStatus.outOfStock,
                  )
                  .length,
            ),
          )
          .toList()
        ..sort((left, right) => left.category.compareTo(right.category)),
      suppliers: _inventoryItems
          .map((item) => item.supplier)
          .whereType<String>()
          .toSet()
          .toList()
        ..sort(),
      branches: _inventoryItems.map((item) => item.branch).toSet().toList()
        ..sort(),
      locations: _inventoryItems.map((item) => item.location).toSet().toList()
        ..sort(),
    );
  }

  @override
  Future<List<InventoryItem>> getInventoryItems({
    String? searchQuery,
    String? category,
    String? stockStatus,
    String? supplier,
    String? branch,
    String? location,
    String? sortBy,
    String? sortOrder,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final search = searchQuery?.trim().toLowerCase();
    final items = _inventoryItems.map(_withActiveRestockRequest).toList();
    final filtered = items.where((item) {
      final matchesSearch = search == null ||
          search.isEmpty ||
          item.name.toLowerCase().contains(search) ||
          item.sku.toLowerCase().contains(search);
      final matchesCategory =
          category == null || category.isEmpty || item.category == category;
      final matchesStockStatus = stockStatus == null ||
          stockStatus.isEmpty ||
          item.stockStatus == stockStatus;
      final matchesSupplier =
          supplier == null || supplier.isEmpty || item.supplier == supplier;
      final matchesBranch =
          branch == null || branch.isEmpty || item.branch == branch;
      final matchesLocation =
          location == null || location.isEmpty || item.location == location;
      return matchesSearch &&
          matchesCategory &&
          matchesStockStatus &&
          matchesSupplier &&
          matchesBranch &&
          matchesLocation;
    }).toList();

    int compare(InventoryItem left, InventoryItem right) {
      switch (sortBy) {
        case 'quantity':
          return left.quantityOnHand.compareTo(right.quantityOnHand);
        case 'lastRestockedAt':
          return (left.lastRestockedAt ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
            right.lastRestockedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
        case 'reorderUrgency':
        default:
          return left.reorderUrgencyScore.compareTo(right.reorderUrgencyScore);
      }
    }

    filtered.sort(compare);
    if ((sortOrder ?? 'desc') == 'desc') {
      return filtered.reversed.toList();
    }
    return filtered;
  }

  @override
  Future<List<InventoryStockMovement>> getInventoryItemMovements(
    int inventoryItemId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final items = _inventoryStockMovements
        .where((item) => item.inventoryItemId == inventoryItemId)
        .toList()
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return items;
  }

  @override
  Future<List<InventoryRestockRequest>> getInventoryRestockRequests({
    String? status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final filtered = _inventoryRestockRequests.where(
      (item) => status == null || status.isEmpty || item.status == status,
    );
    final requests = filtered.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return requests;
  }

  @override
  Future<InventoryRestockRequest> createInventoryRestockRequest({
    required int inventoryItemId,
    required int requestedQuantity,
    String? requestNotes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final item =
        _inventoryItems.firstWhere((entry) => entry.id == inventoryItemId);
    final existingPending = _inventoryRestockRequests.any(
      (entry) =>
          entry.inventoryItemId == inventoryItemId &&
          entry.status == InventoryRestockRequestStatus.pending,
    );
    if (existingPending) {
      throw StateError('A pending restock request already exists.');
    }

    _inventoryRestockRequestCounter += 1;
    final request = InventoryRestockRequest(
      id: _inventoryRestockRequestCounter,
      requestNumber: 'RSTK-${1000 + _inventoryRestockRequestCounter}',
      inventoryItemId: item.id,
      itemName: item.name,
      itemSku: item.sku,
      itemCategory: item.category,
      supplier: item.supplier,
      branch: item.branch,
      location: item.location,
      unit: item.unit,
      requestedQuantity: requestedQuantity,
      status: InventoryRestockRequestStatus.pending,
      requestNotes: requestNotes,
      operatorRemarks: null,
      requestedByName: 'Inventory Screen',
      approvedByName: null,
      createdAt: DateTime.now(),
      approvedAt: null,
    );
    _inventoryRestockRequests.add(request);
    return request;
  }

  @override
  Future<InventoryRestockRequest> approveInventoryRestockRequest({
    required int requestId,
    required String operatorRemarks,
    String? approverName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final requestIndex = _inventoryRestockRequests.indexWhere(
      (item) => item.id == requestId,
    );
    if (requestIndex == -1) {
      throw StateError('Restock request not found.');
    }
    final existing = _inventoryRestockRequests[requestIndex];
    final updated = InventoryRestockRequest(
      id: existing.id,
      requestNumber: existing.requestNumber,
      inventoryItemId: existing.inventoryItemId,
      itemName: existing.itemName,
      itemSku: existing.itemSku,
      itemCategory: existing.itemCategory,
      supplier: existing.supplier,
      branch: existing.branch,
      location: existing.location,
      unit: existing.unit,
      requestedQuantity: existing.requestedQuantity,
      status: InventoryRestockRequestStatus.approved,
      requestNotes: existing.requestNotes,
      operatorRemarks: operatorRemarks,
      requestedByName: existing.requestedByName,
      approvedByName: approverName,
      createdAt: existing.createdAt,
      approvedAt: DateTime.now(),
    );
    _inventoryRestockRequests[requestIndex] = updated;
    return updated;
  }

  @override
  Future<InventoryRestockRequest> markInventoryRestockRequestProcured({
    required int requestId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final requestIndex = _inventoryRestockRequests.indexWhere(
      (item) => item.id == requestId,
    );
    if (requestIndex == -1) {
      throw StateError('Restock request not found.');
    }
    final existing = _inventoryRestockRequests[requestIndex];
    if (existing.status != InventoryRestockRequestStatus.approved) {
      throw StateError(
          'Only approved restock requests can be marked procured.');
    }

    final itemIndex = _inventoryItems.indexWhere(
      (item) => item.id == existing.inventoryItemId,
    );
    if (itemIndex != -1) {
      final item = _inventoryItems[itemIndex];
      final replenishedQuantity =
          item.quantityOnHand + existing.requestedQuantity;
      final healthyQuantity = replenishedQuantity > item.reorderPoint
          ? replenishedQuantity
          : item.reorderPoint + 1;
      _inventoryItems[itemIndex] = InventoryItem(
        id: item.id,
        sku: item.sku,
        barcode: item.barcode,
        name: item.name,
        category: item.category,
        supplier: item.supplier,
        branch: item.branch,
        location: item.location,
        unit: item.unit,
        unitType: item.unitType,
        packSize: item.packSize,
        quantityOnHand: healthyQuantity,
        reorderPoint: item.reorderPoint,
        parLevel: item.parLevel,
        unitCost: item.unitCost,
        sellingPrice: item.sellingPrice,
        stockValue: healthyQuantity * item.unitCost,
        lastRestockedAt: DateTime.now(),
        expiresAt: item.expiresAt,
        stockStatus: InventoryStockStatus.healthy,
        isActive: item.isActive,
        reorderUrgencyScore: 0,
        activeRestockRequestId: null,
        activeRestockRequestStatus: null,
        activeRestockRequestNumber: null,
        activeRestockRequestedQuantity: null,
        activeRestockOperatorRemarks: null,
        activeRestockApprovedAt: null,
      );
      _inventoryStockMovements.add(
        InventoryStockMovement(
          id: _inventoryStockMovements.length + 1,
          inventoryItemId: item.id,
          movementType: InventoryStockMovementType.received,
          quantityDelta: existing.requestedQuantity,
          balanceAfter: healthyQuantity,
          referenceType: 'RESTOCK_REQUEST',
          referenceId: existing.requestNumber,
          notes: 'Stock received against approved procurement request.',
          performedByName: 'Store Admin',
          occurredAt: DateTime.now(),
        ),
      );
    }

    final updated = InventoryRestockRequest(
      id: existing.id,
      requestNumber: existing.requestNumber,
      inventoryItemId: existing.inventoryItemId,
      itemName: existing.itemName,
      itemSku: existing.itemSku,
      itemCategory: existing.itemCategory,
      supplier: existing.supplier,
      branch: existing.branch,
      location: existing.location,
      unit: existing.unit,
      requestedQuantity: existing.requestedQuantity,
      status: InventoryRestockRequestStatus.procured,
      requestNotes: existing.requestNotes,
      operatorRemarks: existing.operatorRemarks,
      requestedByName: existing.requestedByName,
      approvedByName: existing.approvedByName,
      createdAt: existing.createdAt,
      approvedAt: existing.approvedAt,
    );
    _inventoryRestockRequests[requestIndex] = updated;
    return updated;
  }

  @override
  Future<List<MaintenanceRecord>> getMaintenanceRecords(
      {String? status}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final normalizedStatus = status?.trim();
    final records = _maintenanceRecords.where((item) {
      if (normalizedStatus == null || normalizedStatus.isEmpty) {
        return true;
      }
      return item.status == normalizedStatus;
    }).toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return records;
  }

  @override
  Future<List<Machine>> getMaintenanceEligibleMachines() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return _machines
        .where((machine) => machine.status == MachineStatus.available)
        .toList();
  }

  @override
  Future<MaintenanceRecord> createMaintenanceRecord({
    required int machineId,
    required String issueTitle,
    String? issueDescription,
    String priority = MaintenancePriority.medium,
    String? reportedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final machineIndex = _machines.indexWhere((item) => item.id == machineId);
    if (machineIndex == -1) {
      throw StateError('Machine not found: $machineId');
    }
    if (_machines[machineIndex].status != MachineStatus.available) {
      throw StateError(
          'Only available machines can be marked for maintenance.');
    }
    final hasActiveRecord = _maintenanceRecords.any(
      (item) => item.machineId == machineId && !item.isCompleted,
    );
    if (hasActiveRecord) {
      throw StateError(
          'This machine already has an active maintenance record.');
    }

    final now = DateTime.now();
    final record = MaintenanceRecord(
      id: ++_maintenanceRecordCounter,
      machineId: machineId,
      issueTitle: issueTitle,
      issueDescription: issueDescription,
      priority: priority,
      status: MaintenanceStatus.marked,
      reportedByName: reportedByName,
      startedByName: null,
      completedByName: null,
      reportedAt: now,
      startedAt: null,
      completedAt: null,
      resolutionNotes: null,
      createdAt: now,
      updatedAt: now,
    );
    _maintenanceRecords.insert(0, record);
    _machines[machineIndex] = _machines[machineIndex].copyWith(
      status: MachineStatus.maintenance,
    );
    await _persistState();
    return record;
  }

  @override
  Future<MaintenanceRecord?> startMaintenanceRecord({
    required int recordId,
    String? startedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final recordIndex =
        _maintenanceRecords.indexWhere((item) => item.id == recordId);
    if (recordIndex == -1) {
      return null;
    }
    final existing = _maintenanceRecords[recordIndex];
    if (!existing.isMarked) {
      return existing;
    }
    final updated = existing.copyWith(
      status: MaintenanceStatus.inProgress,
      startedByName: startedByName,
      startedAt: existing.startedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _maintenanceRecords[recordIndex] = updated;
    await _persistState();
    return updated;
  }

  @override
  Future<MaintenanceRecord?> completeMaintenanceRecord({
    required int recordId,
    String? completedByName,
    String? resolutionNotes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final recordIndex =
        _maintenanceRecords.indexWhere((item) => item.id == recordId);
    if (recordIndex == -1) {
      return null;
    }
    final existing = _maintenanceRecords[recordIndex];
    if (existing.isCompleted) {
      return existing;
    }
    final now = DateTime.now();
    final updated = existing.copyWith(
      status: MaintenanceStatus.completed,
      startedAt: existing.startedAt ?? now,
      completedByName: completedByName,
      completedAt: now,
      resolutionNotes: resolutionNotes,
      updatedAt: now,
    );
    _maintenanceRecords[recordIndex] = updated;
    final machineIndex =
        _machines.indexWhere((item) => item.id == existing.machineId);
    if (machineIndex != -1) {
      _machines[machineIndex] = _machines[machineIndex].copyWith(
        status: MachineStatus.available,
        currentOrderId: null,
        cycleStartedAt: null,
        cycleEndsAt: null,
      );
    }
    await _persistState();
    return updated;
  }

  InventoryItem _withActiveRestockRequest(InventoryItem item) {
    final activeRequest = _inventoryRestockRequests
        .where(
          (entry) =>
              entry.inventoryItemId == item.id &&
              (entry.status == InventoryRestockRequestStatus.pending ||
                  entry.status == InventoryRestockRequestStatus.approved),
        )
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final latestRequest = activeRequest.isEmpty ? null : activeRequest.first;

    return InventoryItem(
      id: item.id,
      sku: item.sku,
      barcode: item.barcode,
      name: item.name,
      category: item.category,
      supplier: item.supplier,
      branch: item.branch,
      location: item.location,
      unit: item.unit,
      unitType: item.unitType,
      packSize: item.packSize,
      quantityOnHand: item.quantityOnHand,
      reorderPoint: item.reorderPoint,
      parLevel: item.parLevel,
      unitCost: item.unitCost,
      sellingPrice: item.sellingPrice,
      stockValue: item.stockValue,
      lastRestockedAt: item.lastRestockedAt,
      expiresAt: item.expiresAt,
      stockStatus:
          latestRequest?.status == InventoryRestockRequestStatus.approved
              ? InventoryStockStatus.inProcurement
              : item.quantityOnHand == 0
                  ? InventoryStockStatus.outOfStock
                  : item.quantityOnHand <= item.reorderPoint
                      ? InventoryStockStatus.low
                      : InventoryStockStatus.healthy,
      isActive: item.isActive,
      reorderUrgencyScore:
          latestRequest?.status == InventoryRestockRequestStatus.approved
              ? (item.reorderPoint > 0 ? item.reorderPoint : 1)
              : item.reorderUrgencyScore,
      activeRestockRequestId: latestRequest?.id,
      activeRestockRequestStatus: latestRequest?.status,
      activeRestockRequestNumber: latestRequest?.requestNumber,
      activeRestockRequestedQuantity: latestRequest?.requestedQuantity,
      activeRestockOperatorRemarks: latestRequest?.operatorRemarks,
      activeRestockApprovedAt: latestRequest?.approvedAt,
    );
  }

  Future<void> markMachinePickedUp(int machineId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final machineIndex = _machines.indexWhere((item) => item.id == machineId);
    if (machineIndex == -1) {
      return;
    }
    final orderId = _machines[machineIndex].currentOrderId;
    _machines[machineIndex] = _machines[machineIndex].copyWith(
      status: MachineStatus.available,
      currentOrderId: null,
      cycleStartedAt: null,
      cycleEndsAt: null,
    );
    if (orderId != null) {
      final pickupTaskIndex =
          _pickupTasks.indexWhere((item) => item.orderId == orderId);
      if (pickupTaskIndex >= 0) {
        _pickupTasks[pickupTaskIndex] = _pickupTasks[pickupTaskIndex].copyWith(
          status: PickupTaskStatus.pickedUp,
          updatedAt: DateTime.now(),
        );
      }
    }
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

  @override
  Future<Machine> updateMachinePrice({
    required int machineId,
    required double price,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await _loadPersistedState();
    final machineIndex = _machines.indexWhere((item) => item.id == machineId);
    if (machineIndex == -1) {
      throw StateError('Machine not found: $machineId');
    }
    _machines[machineIndex] = _machines[machineIndex].copyWith(price: price);
    await _persistState();
    return _machines[machineIndex];
  }

  @override
  Future<List<PricingServiceFee>> getPricingServiceFees() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    if (_pricingServiceFees.isEmpty) {
      _pricingServiceFees.addAll(_defaultPricingServiceFees());
      await _persistState();
    }
    return [..._pricingServiceFees]
      ..sort((left, right) => left.serviceCode.compareTo(right.serviceCode));
  }

  @override
  Future<PricingServiceFee> updatePricingServiceFee({
    required String serviceCode,
    required double amount,
    required bool isEnabled,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final feeIndex = _pricingServiceFees.indexWhere(
      (item) => item.serviceCode == serviceCode,
    );
    if (feeIndex == -1) {
      throw StateError('Pricing service fee not found: $serviceCode');
    }
    _pricingServiceFees[feeIndex] = _pricingServiceFees[feeIndex].copyWith(
      amount: amount,
      isEnabled: isEnabled,
      updatedAt: DateTime.now(),
    );
    await _persistState();
    return _pricingServiceFees[feeIndex];
  }

  @override
  Future<List<PricingCampaign>> getPricingCampaigns({
    bool activeOnly = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final campaigns = _pricingCampaigns
        .where(
          (item) => !activeOnly || item.isActive,
        )
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return campaigns;
  }

  @override
  Future<PricingCampaign> createPricingCampaign({
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    String? appliesToService,
    double minOrderAmount = 0,
    bool isActive = true,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    await _loadPersistedState();
    final now = DateTime.now();
    final campaign = PricingCampaign(
      id: ++_pricingCampaignCounter,
      name: name,
      description: description,
      discountType: discountType,
      discountValue: discountValue,
      appliesToService: appliesToService,
      minOrderAmount: minOrderAmount,
      isActive: isActive,
      startsAt: startsAt,
      endsAt: endsAt,
      createdAt: now,
      updatedAt: now,
    );
    _pricingCampaigns.insert(0, campaign);
    await _persistState();
    return campaign;
  }

  @override
  Future<PricingCampaign?> updatePricingCampaign({
    required int campaignId,
    String? name,
    String? description,
    String? discountType,
    double? discountValue,
    String? appliesToService,
    double? minOrderAmount,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final campaignIndex = _pricingCampaigns.indexWhere(
      (item) => item.id == campaignId,
    );
    if (campaignIndex == -1) {
      return null;
    }
    _pricingCampaigns[campaignIndex] =
        _pricingCampaigns[campaignIndex].copyWith(
      name: name,
      description: description,
      discountType: discountType,
      discountValue: discountValue,
      appliesToService: appliesToService,
      minOrderAmount: minOrderAmount,
      isActive: isActive,
      startsAt: startsAt,
      endsAt: endsAt,
      updatedAt: DateTime.now(),
    );
    await _persistState();
    return _pricingCampaigns[campaignIndex];
  }

  @override
  Future<PricingQuote> previewPricingQuote({
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required List<String> selectedServices,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return _buildPricingQuote(
      washer: washer,
      dryer: dryer,
      ironingStation: ironingStation,
      selectedServices: selectedServices,
    );
  }

  @override
  Future<List<RefundRequest>> getRefundRequests({String? status}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final normalizedStatus = status?.trim();
    final requests = _refundRequests.where((item) {
      if (normalizedStatus == null || normalizedStatus.isEmpty) {
        return true;
      }
      return item.status == normalizedStatus;
    }).toList()
      ..sort((left, right) => right.requestedAt.compareTo(left.requestedAt));
    return requests;
  }

  @override
  Future<RefundRequest> createRefundRequest({
    required int orderId,
    required String reason,
    String? requestedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();

    final existing = _refundRequests.where(
      (item) => item.orderId == orderId && item.isPending,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    final order = _orders.firstWhere((item) => item.id == orderId);
    final customer =
        _customers.firstWhere((item) => item.id == order.customerId);
    final machine = _machines.firstWhere((item) => item.id == order.machineId);

    _refundRequestCounter += 1;
    final request = RefundRequest(
      id: _refundRequestCounter,
      orderId: orderId,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      machineName: machine.name,
      amount: order.amount,
      paymentMethod: order.paymentMethod,
      paymentReference: order.paymentReference,
      reason: reason.trim(),
      status: RefundRequestStatus.pending,
      requestedAt: DateTime.now(),
      requestedByName: requestedByName,
    );

    _refundRequests.add(request);
    await _persistState();
    return request;
  }

  @override
  Future<RefundRequest?> markRefundRequestProcessed({
    required int requestId,
    String? processedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final requestIndex =
        _refundRequests.indexWhere((item) => item.id == requestId);
    if (requestIndex == -1) {
      return null;
    }

    final request = _refundRequests[requestIndex];
    await markRefundProcessed(request.orderId);
    await _loadPersistedState();

    final updated = request.copyWith(
      status: RefundRequestStatus.processed,
      processedAt: DateTime.now(),
      processedByName: processedByName,
    );
    _refundRequests[requestIndex] = updated;
    await _persistState();
    return updated;
  }

  @override
  Future<List<DeliveryTask>> getDeliveryTasks() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final tasks = [..._deliveryTasks]..sort((left, right) {
        final leftUpdated =
            left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightUpdated =
            right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightUpdated.compareTo(leftUpdated);
      });
    return tasks;
  }

  @override
  Future<DeliveryTask> saveDeliveryTask({
    required DeliveryTask task,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final normalized = task.copyWith(updatedAt: DateTime.now());
    final index =
        _deliveryTasks.indexWhere((item) => item.orderId == task.orderId);
    if (index >= 0) {
      _deliveryTasks[index] = normalized;
    } else {
      _deliveryTasks.add(normalized);
    }
    await _persistState();
    return normalized;
  }

  @override
  Future<List<PickupTask>> getPickupTasks() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final tasks = [..._pickupTasks]..sort((left, right) {
        final leftUpdated =
            left.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightUpdated =
            right.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightUpdated.compareTo(leftUpdated);
      });
    return tasks;
  }

  @override
  Future<PickupTask> savePickupTask({
    required PickupTask task,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final normalized = task.copyWith(updatedAt: DateTime.now());
    final index =
        _pickupTasks.indexWhere((item) => item.orderId == task.orderId);
    if (index >= 0) {
      _pickupTasks[index] = normalized;
    } else {
      _pickupTasks.add(normalized);
    }
    await _persistState();
    return normalized;
  }

  @override
  Future<List<DayEndCheckout>> getDayEndCheckouts({
    int limit = 30,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    final checkouts = [..._dayEndCheckouts]
      ..sort((left, right) => right.businessDate.compareTo(left.businessDate));
    return checkouts.take(limit).toList();
  }

  @override
  Future<DayEndCheckout> createDayEndCheckout({
    required DateTime businessDate,
    required double openingCash,
    required double closingCashCounted,
    String? notes,
    required String closedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();

    final normalizedDate = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );

    final existingIndex = _dayEndCheckouts.indexWhere(
      (item) =>
          item.businessDate.year == normalizedDate.year &&
          item.businessDate.month == normalizedDate.month &&
          item.businessDate.day == normalizedDate.day,
    );
    final id = existingIndex >= 0
        ? _dayEndCheckouts[existingIndex].id
        : ++_dayEndCheckoutCounter;

    final checkout = RevenueReportingService.buildDayEndCheckout(
      id: id,
      businessDate: normalizedDate,
      openingCash: openingCash,
      closingCashCounted: closingCashCounted,
      notes: notes,
      closedByName: closedByName,
      history: await getOrderHistory(),
      refundRequests: await getRefundRequests(),
    );

    if (existingIndex >= 0) {
      _dayEndCheckouts[existingIndex] = checkout;
    } else {
      _dayEndCheckouts.add(checkout);
    }
    await _persistState();
    return checkout;
  }

  @override
  Future<List<StaffMember>> getStaffMembers() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return [..._staffMembers]..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<List<StaffShift>> getStaffShifts({
    required DateTime start,
    required DateTime end,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return _staffShifts.where((item) {
      final day = DateTime(
          item.shiftDate.year, item.shiftDate.month, item.shiftDate.day);
      return !day.isBefore(start) && day.isBefore(end);
    }).toList()
      ..sort((a, b) => a.shiftDate.compareTo(b.shiftDate));
  }

  @override
  Future<StaffShift> saveStaffShift({
    int? shiftId,
    required int staffId,
    required DateTime shiftDate,
    required String startTimeLabel,
    required String endTimeLabel,
    required String branch,
    required String assignment,
    required double hours,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final normalizedDate =
        DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
    final shift = StaffShift(
      id: shiftId ?? ++_staffShiftCounter,
      staffId: staffId,
      shiftDate: normalizedDate,
      startTimeLabel: startTimeLabel,
      endTimeLabel: endTimeLabel,
      branch: branch,
      assignment: assignment,
      hours: hours,
    );
    final index = _staffShifts.indexWhere((item) => item.id == shift.id);
    if (index >= 0) {
      _staffShifts[index] = shift;
    } else {
      _staffShifts.add(shift);
    }
    await _persistState();
    return shift;
  }

  @override
  Future<List<StaffLeaveRequest>> getStaffLeaveRequests(
      {String? status}) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return _staffLeaveRequests.where((item) {
      if (status == null || status.isEmpty) {
        return true;
      }
      return item.status == status;
    }).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  @override
  Future<StaffLeaveRequest?> updateStaffLeaveRequestStatus({
    required int leaveRequestId,
    required String status,
    String? reviewedByName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final index =
        _staffLeaveRequests.indexWhere((item) => item.id == leaveRequestId);
    if (index == -1) {
      return null;
    }
    final updated = _staffLeaveRequests[index].copyWith(
      status: status,
      reviewedByName: reviewedByName,
    );
    _staffLeaveRequests[index] = updated;
    await _persistState();
    return updated;
  }

  @override
  Future<List<StaffPayout>> getStaffPayouts() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _loadPersistedState();
    return [..._staffPayouts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<StaffPayout> createStaffPayout({
    required int staffId,
    required String periodLabel,
    required double hoursWorked,
    required double bonusAmount,
    required double deductionsAmount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _loadPersistedState();
    final staff = _staffMembers.firstWhere((item) => item.id == staffId);
    final grossAmount = hoursWorked * staff.hourlyRate;
    final payout = StaffPayout(
      id: ++_staffPayoutCounter,
      staffId: staffId,
      staffName: staff.fullName,
      periodLabel: periodLabel,
      hoursWorked: hoursWorked,
      grossAmount: grossAmount,
      bonusAmount: bonusAmount,
      deductionsAmount: deductionsAmount,
      netAmount: grossAmount + bonusAmount - deductionsAmount,
      status: StaffPayoutStatus.scheduled,
      createdAt: DateTime.now(),
    );
    _staffPayouts.add(payout);
    await _persistState();
    return payout;
  }

  @override
  Future<StaffPayout?> markStaffPayoutPaid({
    required int payoutId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _loadPersistedState();
    final index = _staffPayouts.indexWhere((item) => item.id == payoutId);
    if (index == -1) {
      return null;
    }
    final updated = _staffPayouts[index].copyWith(
      status: StaffPayoutStatus.paid,
      paidAt: DateTime.now(),
    );
    _staffPayouts[index] = updated;
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
      cycleEndsAt: event.clearCycleWindow
          ? null
          : event.cycleEndsAt ?? machine.cycleEndsAt,
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
    final pricingServiceFeesJson = await _preferences.getString(
      _pricingServiceFeesKey,
    );
    final pricingCampaignsJson = await _preferences.getString(
      _pricingCampaignsKey,
    );
    final maintenanceRecordsJson = await _preferences.getString(
      _maintenanceRecordsKey,
    );
    final refundRequestsJson = await _preferences.getString(_refundRequestsKey);
    final deliveryTasksJson = await _preferences.getString(_deliveryTasksKey);
    final pickupTasksJson = await _preferences.getString(_pickupTasksKey);
    final dayEndCheckoutsJson = await _preferences.getString(
      _dayEndCheckoutsKey,
    );
    final staffMembersJson = await _preferences.getString(_staffMembersKey);
    final staffShiftsJson = await _preferences.getString(_staffShiftsKey);
    final staffLeaveRequestsJson = await _preferences.getString(
      _staffLeaveRequestsKey,
    );
    final staffPayoutsJson = await _preferences.getString(_staffPayoutsKey);

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
    _pricingServiceFees
      ..clear()
      ..addAll(_decodePricingServiceFees(pricingServiceFeesJson));
    _pricingCampaigns
      ..clear()
      ..addAll(_decodePricingCampaigns(pricingCampaignsJson));
    _maintenanceRecords
      ..clear()
      ..addAll(_decodeMaintenanceRecords(maintenanceRecordsJson));
    _refundRequests
      ..clear()
      ..addAll(_decodeRefundRequests(refundRequestsJson));
    _deliveryTasks
      ..clear()
      ..addAll(_decodeDeliveryTasks(deliveryTasksJson));
    _pickupTasks
      ..clear()
      ..addAll(_decodePickupTasks(pickupTasksJson));
    _dayEndCheckouts
      ..clear()
      ..addAll(_decodeDayEndCheckouts(dayEndCheckoutsJson));
    _staffMembers
      ..clear()
      ..addAll(_decodeStaffMembers(staffMembersJson));
    _staffShifts
      ..clear()
      ..addAll(_decodeStaffShifts(staffShiftsJson));
    _staffLeaveRequests
      ..clear()
      ..addAll(_decodeStaffLeaveRequests(staffLeaveRequestsJson));
    _staffPayouts
      ..clear()
      ..addAll(_decodeStaffPayouts(staffPayoutsJson));

    _customerCounter =
        await _preferences.getInt(_customerCounterKey) ?? _customers.length;
    _orderCounter =
        await _preferences.getInt(_orderCounterKey) ?? _orders.length;
    _paymentSessionCounter =
        await _preferences.getInt(_paymentSessionCounterKey) ?? 0;
    _reservationCounter = await _preferences.getInt(_reservationCounterKey) ??
        _reservations.length;
    _pricingCampaignCounter =
        await _preferences.getInt(_pricingCampaignCounterKey) ??
            _pricingCampaigns.length;
    _maintenanceRecordCounter =
        await _preferences.getInt(_maintenanceRecordCounterKey) ??
            _maintenanceRecords.length;
    _refundRequestCounter =
        await _preferences.getInt(_refundRequestCounterKey) ??
            _refundRequests.length;
    _dayEndCheckoutCounter =
        await _preferences.getInt(_dayEndCheckoutCounterKey) ??
            _dayEndCheckouts.length;
    _staffShiftCounter =
        await _preferences.getInt(_staffShiftCounterKey) ?? _staffShifts.length;
    _staffLeaveRequestCounter =
        await _preferences.getInt(_staffLeaveRequestCounterKey) ??
            _staffLeaveRequests.length;
    _staffPayoutCounter = await _preferences.getInt(_staffPayoutCounterKey) ??
        _staffPayouts.length;
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
                'garmentItems':
                    order.garmentItems.map((item) => item.toJson()).toList(),
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
    await _preferences.setString(
      _pricingServiceFeesKey,
      jsonEncode(
        _pricingServiceFees
            .map(
              (fee) => {
                'serviceCode': fee.serviceCode,
                'displayName': fee.displayName,
                'amount': fee.amount,
                'isEnabled': fee.isEnabled,
                'updatedAt': fee.updatedAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _pricingCampaignsKey,
      jsonEncode(
        _pricingCampaigns
            .map(
              (campaign) => {
                'id': campaign.id,
                'name': campaign.name,
                'description': campaign.description,
                'discountType': campaign.discountType,
                'discountValue': campaign.discountValue,
                'appliesToService': campaign.appliesToService,
                'minOrderAmount': campaign.minOrderAmount,
                'isActive': campaign.isActive,
                'startsAt': campaign.startsAt?.toIso8601String(),
                'endsAt': campaign.endsAt?.toIso8601String(),
                'createdAt': campaign.createdAt.toIso8601String(),
                'updatedAt': campaign.updatedAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _maintenanceRecordsKey,
      jsonEncode(
        _maintenanceRecords
            .map(
              (record) => {
                'id': record.id,
                'machineId': record.machineId,
                'issueTitle': record.issueTitle,
                'issueDescription': record.issueDescription,
                'priority': record.priority,
                'status': record.status,
                'reportedByName': record.reportedByName,
                'startedByName': record.startedByName,
                'completedByName': record.completedByName,
                'reportedAt': record.reportedAt.toIso8601String(),
                'startedAt': record.startedAt?.toIso8601String(),
                'completedAt': record.completedAt?.toIso8601String(),
                'resolutionNotes': record.resolutionNotes,
                'createdAt': record.createdAt.toIso8601String(),
                'updatedAt': record.updatedAt.toIso8601String(),
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _refundRequestsKey,
      jsonEncode(
        _refundRequests
            .map(
              (request) => {
                'id': request.id,
                'orderId': request.orderId,
                'customerName': request.customerName,
                'customerPhone': request.customerPhone,
                'machineName': request.machineName,
                'amount': request.amount,
                'paymentMethod': request.paymentMethod,
                'paymentReference': request.paymentReference,
                'reason': request.reason,
                'status': request.status,
                'requestedAt': request.requestedAt.toIso8601String(),
                'requestedByName': request.requestedByName,
                'processedAt': request.processedAt?.toIso8601String(),
                'processedByName': request.processedByName,
              },
            )
            .toList(),
      ),
    );
    await _preferences.setString(
      _deliveryTasksKey,
      jsonEncode(_deliveryTasks.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _pickupTasksKey,
      jsonEncode(_pickupTasks.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _dayEndCheckoutsKey,
      jsonEncode(
        _dayEndCheckouts.map((checkout) => checkout.toJson()).toList(),
      ),
    );
    await _preferences.setString(
      _staffMembersKey,
      jsonEncode(_staffMembers.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _staffShiftsKey,
      jsonEncode(_staffShifts.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _staffLeaveRequestsKey,
      jsonEncode(_staffLeaveRequests.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _staffPayoutsKey,
      jsonEncode(_staffPayouts.map((item) => item.toJson()).toList()),
    );
    await _preferences.setInt(_customerCounterKey, _customerCounter);
    await _preferences.setInt(_orderCounterKey, _orderCounter);
    await _preferences.setInt(
      _paymentSessionCounterKey,
      _paymentSessionCounter,
    );
    await _preferences.setInt(_reservationCounterKey, _reservationCounter);
    await _preferences.setInt(
        _pricingCampaignCounterKey, _pricingCampaignCounter);
    await _preferences.setInt(
      _maintenanceRecordCounterKey,
      _maintenanceRecordCounter,
    );
    await _preferences.setInt(_refundRequestCounterKey, _refundRequestCounter);
    await _preferences.setInt(
      _dayEndCheckoutCounterKey,
      _dayEndCheckoutCounter,
    );
    await _preferences.setInt(_staffShiftCounterKey, _staffShiftCounter);
    await _preferences.setInt(
      _staffLeaveRequestCounterKey,
      _staffLeaveRequestCounter,
    );
    await _preferences.setInt(_staffPayoutCounterKey, _staffPayoutCounter);
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
            garmentItems:
                (item['garmentItems'] as List<dynamic>? ?? const [])
                    .map(
                      (entry) =>
                          GarmentItem.fromJson(entry as Map<String, dynamic>),
                    )
                    .toList(),
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

  List<PricingServiceFee> _decodePricingServiceFees(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => PricingServiceFee(
            serviceCode: item['serviceCode'] as String,
            displayName: item['displayName'] as String,
            amount: (item['amount'] as num).toDouble(),
            isEnabled: item['isEnabled'] as bool,
            updatedAt: DateTime.parse(item['updatedAt'] as String),
          ),
        )
        .toList();
  }

  List<PricingCampaign> _decodePricingCampaigns(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => PricingCampaign(
            id: item['id'] as int,
            name: item['name'] as String,
            description: item['description'] as String?,
            discountType: item['discountType'] as String,
            discountValue: (item['discountValue'] as num).toDouble(),
            appliesToService: item['appliesToService'] as String?,
            minOrderAmount: (item['minOrderAmount'] as num).toDouble(),
            isActive: item['isActive'] as bool,
            startsAt: item['startsAt'] == null
                ? null
                : DateTime.parse(item['startsAt'] as String),
            endsAt: item['endsAt'] == null
                ? null
                : DateTime.parse(item['endsAt'] as String),
            createdAt: DateTime.parse(item['createdAt'] as String),
            updatedAt: DateTime.parse(item['updatedAt'] as String),
          ),
        )
        .toList();
  }

  List<MaintenanceRecord> _decodeMaintenanceRecords(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => MaintenanceRecord(
            id: item['id'] as int,
            machineId: item['machineId'] as int,
            issueTitle: item['issueTitle'] as String,
            issueDescription: item['issueDescription'] as String?,
            priority: item['priority'] as String,
            status: item['status'] as String,
            reportedByName: item['reportedByName'] as String?,
            startedByName: item['startedByName'] as String?,
            completedByName: item['completedByName'] as String?,
            reportedAt: DateTime.parse(item['reportedAt'] as String),
            startedAt: item['startedAt'] == null
                ? null
                : DateTime.parse(item['startedAt'] as String),
            completedAt: item['completedAt'] == null
                ? null
                : DateTime.parse(item['completedAt'] as String),
            resolutionNotes: item['resolutionNotes'] as String?,
            createdAt: DateTime.parse(item['createdAt'] as String),
            updatedAt: DateTime.parse(item['updatedAt'] as String),
          ),
        )
        .toList();
  }

  List<RefundRequest> _decodeRefundRequests(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => RefundRequest(
            id: item['id'] as int,
            orderId: item['orderId'] as int,
            customerName: item['customerName'] as String,
            customerPhone: item['customerPhone'] as String,
            machineName: item['machineName'] as String,
            amount: (item['amount'] as num).toDouble(),
            paymentMethod: item['paymentMethod'] as String,
            paymentReference: item['paymentReference'] as String,
            reason: item['reason'] as String,
            status: item['status'] as String,
            requestedAt: DateTime.parse(item['requestedAt'] as String),
            requestedByName: item['requestedByName'] as String?,
            processedAt: item['processedAt'] == null
                ? null
                : DateTime.parse(item['processedAt'] as String),
            processedByName: item['processedByName'] as String?,
          ),
        )
        .toList();
  }

  List<DayEndCheckout> _decodeDayEndCheckouts(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => DayEndCheckout.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  List<DeliveryTask> _decodeDeliveryTasks(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => DeliveryTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<PickupTask> _decodePickupTasks(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => PickupTask.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<StaffMember> _decodeStaffMembers(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => StaffMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<StaffShift> _decodeStaffShifts(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => StaffShift.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<StaffLeaveRequest> _decodeStaffLeaveRequests(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => StaffLeaveRequest.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  List<StaffPayout> _decodeStaffPayouts(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => StaffPayout.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<StaffMember> _defaultStaffMembers() {
    return const [
      StaffMember(
        id: 1,
        fullName: 'Store Admin',
        role: StaffRole.admin,
        phone: '9999999999',
        hourlyRate: 220,
        isActive: true,
      ),
      StaffMember(
        id: 2,
        fullName: 'Kiran Patel',
        role: StaffRole.cashier,
        phone: '9876500011',
        hourlyRate: 120,
        isActive: true,
      ),
      StaffMember(
        id: 3,
        fullName: 'Meera Shah',
        role: StaffRole.manager,
        phone: '9876500012',
        hourlyRate: 180,
        isActive: true,
      ),
      StaffMember(
        id: 4,
        fullName: 'Ravi Solanki',
        role: StaffRole.technician,
        phone: '9876500013',
        hourlyRate: 150,
        isActive: true,
      ),
      StaffMember(
        id: 5,
        fullName: 'Neha Joshi',
        role: StaffRole.support,
        phone: '9876500014',
        hourlyRate: 110,
        isActive: true,
      ),
    ];
  }

  List<StaffShift> _defaultStaffShifts() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return [
      StaffShift(
        id: 1,
        staffId: 2,
        shiftDate: start,
        startTimeLabel: '08:00',
        endTimeLabel: '16:00',
        branch: 'Main Branch',
        assignment: 'Front counter and handover',
        hours: 8,
      ),
      StaffShift(
        id: 2,
        staffId: 3,
        shiftDate: start,
        startTimeLabel: '10:00',
        endTimeLabel: '18:00',
        branch: 'Main Branch',
        assignment: 'Floor supervision and approvals',
        hours: 8,
      ),
      StaffShift(
        id: 3,
        staffId: 4,
        shiftDate: start.add(const Duration(days: 1)),
        startTimeLabel: '09:00',
        endTimeLabel: '17:00',
        branch: 'North Branch',
        assignment: 'Machine servicing round',
        hours: 8,
      ),
      StaffShift(
        id: 4,
        staffId: 5,
        shiftDate: start.add(const Duration(days: 2)),
        startTimeLabel: '12:00',
        endTimeLabel: '20:00',
        branch: 'Main Branch',
        assignment: 'Customer support and pickup queue',
        hours: 8,
      ),
    ];
  }

  List<StaffLeaveRequest> _defaultStaffLeaveRequests() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return [
      StaffLeaveRequest(
        id: 1,
        staffId: 2,
        staffName: 'Kiran Patel',
        leaveType: 'Casual Leave',
        startDate: start.add(const Duration(days: 3)),
        endDate: start.add(const Duration(days: 4)),
        status: StaffLeaveStatus.pending,
        reason: 'Family function out of town.',
        requestedAt: start.subtract(const Duration(days: 1)),
      ),
      StaffLeaveRequest(
        id: 2,
        staffId: 4,
        staffName: 'Ravi Solanki',
        leaveType: 'Sick Leave',
        startDate: start.subtract(const Duration(days: 2)),
        endDate: start.subtract(const Duration(days: 1)),
        status: StaffLeaveStatus.approved,
        reason: 'Recovery after viral fever.',
        requestedAt: start.subtract(const Duration(days: 4)),
        reviewedByName: 'Store Admin',
      ),
    ];
  }

  List<StaffPayout> _defaultStaffPayouts() {
    return [
      StaffPayout(
        id: 1,
        staffId: 2,
        staffName: 'Kiran Patel',
        periodLabel: '01 Apr - 15 Apr',
        hoursWorked: 96,
        grossAmount: 11520,
        bonusAmount: 600,
        deductionsAmount: 200,
        netAmount: 11920,
        status: StaffPayoutStatus.scheduled,
        createdAt: DateTime(2026, 4, 15, 18),
      ),
      StaffPayout(
        id: 2,
        staffId: 4,
        staffName: 'Ravi Solanki',
        periodLabel: '01 Apr - 15 Apr',
        hoursWorked: 88,
        grossAmount: 13200,
        bonusAmount: 450,
        deductionsAmount: 0,
        netAmount: 13650,
        status: StaffPayoutStatus.paid,
        createdAt: DateTime(2026, 4, 15, 18),
        paidAt: DateTime(2026, 4, 16, 11),
      ),
    ];
  }

  List<PricingServiceFee> _defaultPricingServiceFees() {
    final now = DateTime.now();
    return [
      PricingServiceFee(
        serviceCode: LaundryService.washing,
        displayName: 'Washing Service Fee',
        amount: 15,
        isEnabled: true,
        updatedAt: now,
      ),
      PricingServiceFee(
        serviceCode: LaundryService.drying,
        displayName: 'Drying Service Fee',
        amount: 10,
        isEnabled: true,
        updatedAt: now,
      ),
      PricingServiceFee(
        serviceCode: LaundryService.ironing,
        displayName: 'Ironing Service Fee',
        amount: 20,
        isEnabled: true,
        updatedAt: now,
      ),
    ];
  }

  List<MaintenanceRecord> _defaultMaintenanceRecords() {
    final maintenanceMachines = _machines
        .where((machine) => machine.status == MachineStatus.maintenance)
        .toList();
    if (maintenanceMachines.isEmpty) {
      return const [];
    }

    final now = DateTime.now();
    return [
      if (maintenanceMachines.isNotEmpty)
        MaintenanceRecord(
          id: 1,
          machineId: maintenanceMachines.first.id,
          issueTitle: 'Door latch inspection',
          issueDescription:
              'Front door latch is loose and needs calibration before the next booking.',
          priority: MaintenancePriority.high,
          status: MaintenanceStatus.marked,
          reportedByName: 'Store Admin',
          startedByName: null,
          completedByName: null,
          reportedAt: now.subtract(const Duration(hours: 4)),
          startedAt: null,
          completedAt: null,
          resolutionNotes: null,
          createdAt: now.subtract(const Duration(hours: 4)),
          updatedAt: now.subtract(const Duration(hours: 4)),
        ),
      if (maintenanceMachines.length > 1)
        MaintenanceRecord(
          id: 2,
          machineId: maintenanceMachines[1].id,
          issueTitle: 'Heating plate replacement',
          issueDescription:
              'Ironing plate temperature is inconsistent and needs a replacement part fitted.',
          priority: MaintenancePriority.medium,
          status: MaintenanceStatus.inProgress,
          reportedByName: 'Store Admin',
          startedByName: 'Technician Team',
          completedByName: null,
          reportedAt: now.subtract(const Duration(days: 1)),
          startedAt: now.subtract(const Duration(hours: 6)),
          completedAt: null,
          resolutionNotes: null,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
    ];
  }

  PricingQuote _buildPricingQuote({
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required List<String> selectedServices,
  }) {
    final machines =
        [washer, dryer, ironingStation].whereType<Machine>().toList();
    final machineSubtotal = machines.fold<double>(
      0,
      (sum, machine) => sum + machine.price,
    );
    final enabledFees = _pricingServiceFees
        .where(
          (fee) => fee.isEnabled && selectedServices.contains(fee.serviceCode),
        )
        .toList();
    final serviceFeeTotal = enabledFees.fold<double>(
      0,
      (sum, fee) => sum + fee.amount,
    );
    final baseTotal = machineSubtotal + serviceFeeTotal;
    final now = DateTime.now();
    final appliedCampaigns = _pricingCampaigns.where((campaign) {
      if (!campaign.isActive) {
        return false;
      }
      if (campaign.startsAt != null && campaign.startsAt!.isAfter(now)) {
        return false;
      }
      if (campaign.endsAt != null && campaign.endsAt!.isBefore(now)) {
        return false;
      }
      if (campaign.minOrderAmount > baseTotal) {
        return false;
      }
      if (campaign.appliesToService == null ||
          campaign.appliesToService == 'ALL') {
        return true;
      }
      return selectedServices.contains(campaign.appliesToService);
    }).toList();

    var discountTotal = 0.0;
    final lines = <PricingQuoteLine>[
      ...machines.map(
        (machine) => PricingQuoteLine(
          label: machine.name,
          type: PricingLineType.machine,
          amount: machine.price,
        ),
      ),
      ...enabledFees.map(
        (fee) => PricingQuoteLine(
          label: fee.displayName,
          type: PricingLineType.serviceFee,
          amount: fee.amount,
        ),
      ),
    ];

    for (final campaign in appliedCampaigns) {
      final rawDiscount = campaign.discountType == PricingDiscountType.percent
          ? baseTotal * (campaign.discountValue / 100)
          : campaign.discountValue;
      final applied = rawDiscount > (baseTotal - discountTotal)
          ? (baseTotal - discountTotal)
          : rawDiscount;
      if (applied <= 0) {
        continue;
      }
      discountTotal += applied;
      lines.add(
        PricingQuoteLine(
          label: campaign.name,
          type: PricingLineType.discount,
          amount: -applied,
        ),
      );
    }

    return PricingQuote(
      machineSubtotal: machineSubtotal,
      serviceFeeTotal: serviceFeeTotal,
      discountTotal: discountTotal,
      finalTotal: (baseTotal - discountTotal).clamp(0, double.infinity),
      appliedCampaigns: appliedCampaigns,
      lines: lines,
    );
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
