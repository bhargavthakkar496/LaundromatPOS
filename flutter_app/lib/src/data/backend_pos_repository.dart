import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_order_session.dart';
import '../models/auth_session.dart';
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
import '../models/revenue.dart';
import '../models/staff.dart';
import '../services/backend_api_client.dart';
import '../services/backend_serializers.dart';
import '../services/revenue_reporting_service.dart';
import 'pos_repository.dart';

class BackendPosRepository implements PosRepository {
  BackendPosRepository({
    required BackendApiClient apiClient,
  }) : _apiClient = apiClient;

  static const _dayEndCheckoutsKey = 'backend_day_end_checkouts_v1';
  static const _deliveryTasksKey = 'backend_delivery_tasks_v1';
  static const _pickupTasksKey = 'backend_pickup_tasks_v1';
  static const _dayEndCheckoutCounterKey =
      'backend_day_end_checkout_counter_v1';

  final BackendApiClient _apiClient;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  List<Machine> _normalizeMachineCycles(List<Machine> machines) {
    final now = DateTime.now();
    return machines
        .map((machine) => machine.normalizedCycleStatus(now: now))
        .toList();
  }

  Machine _normalizeMachineCycle(Machine machine) {
    return machine.normalizedCycleStatus(now: DateTime.now());
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<AuthSession?> login(String username, String pin) async {
    try {
      final response = await _apiClient.postJson(
        '/auth/login',
        authenticated: false,
        body: {
          'username': username,
          'pin': pin,
        },
      );
      return decodeAuthSession(response);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<List<Machine>> getAvailableMachines() async {
    final items = await _apiClient.getJsonList(
      '/machines',
      queryParameters: {'status': MachineStatus.available},
    );
    return _normalizeMachineCycles(
      items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<List<Machine>> getMachines() async {
    final items = await _apiClient.getJsonList('/machines');
    return _normalizeMachineCycles(
      items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<Machine?> getMachineById(int machineId) async {
    try {
      final item = await _apiClient.getJson('/machines/$machineId');
      return _normalizeMachineCycle(decodeMachine(item));
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<Customer?> getCustomerByPhone(String phone) async {
    try {
      final item = await _apiClient.getJson(
        '/customers/by-phone',
        queryParameters: {'phone': phone},
      );
      return decodeCustomer(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<Customer> saveWalkInCustomer({
    required String fullName,
    required String phone,
    int? preferredWasherSizeKg,
    String? preferredDetergentAddOn,
    int? preferredDryerDurationMinutes,
  }) async {
    final item = await _apiClient.postJson(
      '/customers/walk-in',
      body: {
        'fullName': fullName,
        'phone': phone,
        'preferredWasherSizeKg': preferredWasherSizeKg,
        'preferredDetergentAddOn': preferredDetergentAddOn,
        'preferredDryerDurationMinutes': preferredDryerDurationMinutes,
      },
    );
    return decodeCustomer(item);
  }

  @override
  Future<List<Machine>> getReservableMachines({
    required String machineType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final items = await _apiClient.getJsonList(
      '/machines/reservable',
      queryParameters: {
        'machineType': machineType,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      },
    );
    return _normalizeMachineCycles(
      items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Future<MachineReservation> createReservation({
    required Machine machine,
    required Customer customer,
    required DateTime startTime,
    required DateTime endTime,
    int? preferredWasherSizeKg,
    String? detergentAddOn,
    int? dryerDurationMinutes,
  }) async {
    final item = await _apiClient.postJson(
      '/reservations',
      body: {
        'machineId': machine.id,
        'customerId': customer.id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'preferredWasherSizeKg': preferredWasherSizeKg,
        'detergentAddOn': detergentAddOn,
        'dryerDurationMinutes': dryerDurationMinutes,
      },
    );
    return decodeMachineReservation(item);
  }

  @override
  Future<Order> createPaidOrder({
    required Machine machine,
    required Customer customer,
    PosUser? user,
    required String paymentMethod,
    String referencePrefix = 'POS',
    String? paymentReference,
  }) async {
    final item = await _apiClient.postJson(
      '/orders/paid',
      body: {
        'machineId': machine.id,
        'customerId': customer.id,
        'createdByUserId': user?.id,
        'paymentMethod': paymentMethod,
        'referencePrefix': referencePrefix,
        'paymentReference': paymentReference,
      },
    );
    return decodeOrder(item);
  }

  @override
  Future<PaymentSession> createPaymentSession({
    required double amount,
    required String paymentMethod,
    String referencePrefix = 'PAY',
    int attempt = 1,
    bool shouldFail = false,
  }) async {
    final item = await _apiClient.postJson(
      '/payments/sessions',
      body: {
        'amount': amount,
        'paymentMethod': paymentMethod,
        'referencePrefix': referencePrefix,
        'attempt': attempt,
        'shouldFail': shouldFail,
      },
    );
    return decodePaymentSession(item);
  }

  @override
  Future<PaymentSession> pollPaymentSession(int sessionId) async {
    final item = await _apiClient.getJson('/payments/sessions/$sessionId');
    return decodePaymentSession(item);
  }

  @override
  Future<List<OrderHistoryItem>> getOrderHistory() async {
    final items = await _apiClient.getJsonList('/orders/history');
    return items
        .map((item) => decodeOrderHistoryItem(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OrderHistoryItem?> getOrderHistoryItemByOrderId(int orderId) async {
    try {
      final item = await _apiClient.getJson('/orders/$orderId/history-item');
      return decodeOrderHistoryItem(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
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
    final item = await _apiClient.postJson(
      '/orders/manual',
      body: {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'loadSizeKg': loadSizeKg,
        'selectedServices': selectedServices,
        'garmentItems': garmentItems.map((item) => item.toJson()).toList(),
        'washOption': washOption,
        'washerMachineId': washer?.id,
        'dryerMachineId': dryer?.id,
        'ironingMachineId': ironingStation?.id,
        'orderStatus': orderStatus,
        'paymentMethod': paymentMethod,
        'createdByUserId': user?.id,
      },
    );
    return decodeOrder(item);
  }

  @override
  Future<ActiveOrderSession?> getActiveOrderSession() async {
    try {
      final item = await _apiClient.getJson('/active-order-session');
      return decodeActiveOrderSession(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
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
    final item = await _apiClient.postJson(
      '/active-order-session/draft',
      body: {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'loadSizeKg': loadSizeKg,
        'selectedServices': selectedServices,
        'garmentItems': garmentItems.map((item) => item.toJson()).toList(),
        'washOption': washOption,
        'washerMachineId': washer?.id,
        'dryerMachineId': dryer?.id,
        'ironingMachineId': ironingStation?.id,
        'paymentMethod': paymentMethod,
      },
    );
    return decodeActiveOrderSession(item);
  }

  @override
  Future<ActiveOrderSession?> confirmActiveOrderSession({
    required String confirmedBy,
    PosUser? user,
  }) async {
    try {
      final item = await _apiClient.postJson(
        '/active-order-session/confirm',
        body: {
          'confirmedBy': confirmedBy,
          'userId': user?.id,
        },
      );
      return decodeActiveOrderSession(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<ActiveOrderSession?> completeActiveOrderPayment({
    required String paymentReference,
  }) async {
    try {
      final item = await _apiClient.postJson(
        '/active-order-session/payment',
        body: {'paymentReference': paymentReference},
      );
      return decodeActiveOrderSession(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<void> clearActiveOrderSession() async {
    await _apiClient.delete('/active-order-session');
  }

  @override
  Future<CustomerProfile?> getCustomerProfileByPhone(String phone) async {
    try {
      final item = await _apiClient.getJson(
        '/customers/profile',
        queryParameters: {'phone': phone},
      );
      return decodeCustomerProfile(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<InventoryDashboard> getInventoryDashboard() async {
    final item = await _apiClient.getJson('/inventory/dashboard');
    return decodeInventoryDashboard(item);
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
    final queryParameters = <String, String>{};
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      queryParameters['q'] = searchQuery.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      queryParameters['category'] = category.trim();
    }
    if (stockStatus != null && stockStatus.trim().isNotEmpty) {
      queryParameters['stockStatus'] = stockStatus.trim();
    }
    if (supplier != null && supplier.trim().isNotEmpty) {
      queryParameters['supplier'] = supplier.trim();
    }
    if (branch != null && branch.trim().isNotEmpty) {
      queryParameters['branch'] = branch.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      queryParameters['location'] = location.trim();
    }
    if (sortBy != null && sortBy.trim().isNotEmpty) {
      queryParameters['sortBy'] = sortBy.trim();
    }
    if (sortOrder != null && sortOrder.trim().isNotEmpty) {
      queryParameters['sortOrder'] = sortOrder.trim();
    }

    final items = await _apiClient.getJsonList(
      '/inventory/items',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    return items
        .map((item) => decodeInventoryItem(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<InventoryStockMovement>> getInventoryItemMovements(
    int inventoryItemId,
  ) async {
    final items = await _apiClient.getJsonList(
      '/inventory/items/$inventoryItemId/movements',
    );
    return items
        .map(
          (item) => decodeInventoryStockMovement(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<List<InventoryRestockRequest>> getInventoryRestockRequests({
    String? status,
  }) async {
    final queryParameters = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      queryParameters['status'] = status.trim();
    }

    final items = await _apiClient.getJsonList(
      '/inventory/restock-requests',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    return items
        .map(
          (item) => decodeInventoryRestockRequest(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<InventoryRestockRequest> createInventoryRestockRequest({
    required int inventoryItemId,
    required int requestedQuantity,
    String? requestNotes,
  }) async {
    final body = <String, Object>{
      'inventoryItemId': inventoryItemId,
      'requestedQuantity': requestedQuantity,
    };
    if (requestNotes != null && requestNotes.trim().isNotEmpty) {
      body['requestNotes'] = requestNotes.trim();
    }

    final item = await _apiClient.postJson(
      '/inventory/restock-requests',
      body: body,
    );
    return decodeInventoryRestockRequest(item);
  }

  @override
  Future<InventoryRestockRequest> approveInventoryRestockRequest({
    required int requestId,
    required String operatorRemarks,
    String? approverName,
  }) async {
    final item = await _apiClient.postJson(
      '/inventory/restock-requests/$requestId/approve',
      body: {
        'operatorRemarks': operatorRemarks,
        'approverName': approverName,
      },
    );
    return decodeInventoryRestockRequest(item);
  }

  @override
  Future<InventoryRestockRequest> markInventoryRestockRequestProcured({
    required int requestId,
  }) async {
    final item = await _apiClient.postJson(
      '/inventory/restock-requests/$requestId/procure',
    );
    return decodeInventoryRestockRequest(item);
  }

  @override
  Future<List<MaintenanceRecord>> getMaintenanceRecords(
      {String? status}) async {
    final items = await _apiClient.getJsonList(
      '/maintenance/records',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
    return items
        .map((item) => decodeMaintenanceRecord(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Machine>> getMaintenanceEligibleMachines() async {
    final items =
        await _apiClient.getJsonList('/maintenance/eligible-machines');
    return items
        .map((item) => decodeMachine(item as Map<String, dynamic>))
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
    final item = await _apiClient.postJson(
      '/maintenance/records',
      body: {
        'machineId': machineId,
        'issueTitle': issueTitle,
        'issueDescription': issueDescription,
        'priority': priority,
        'reportedByName': reportedByName,
      },
    );
    return decodeMaintenanceRecord(item);
  }

  @override
  Future<MaintenanceRecord?> startMaintenanceRecord({
    required int recordId,
    String? startedByName,
  }) async {
    try {
      final item = await _apiClient.postJson(
        '/maintenance/records/$recordId/start',
        body: {
          'startedByName': startedByName,
        },
      );
      return decodeMaintenanceRecord(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<MaintenanceRecord?> completeMaintenanceRecord({
    required int recordId,
    String? completedByName,
    String? resolutionNotes,
  }) async {
    try {
      final item = await _apiClient.postJson(
        '/maintenance/records/$recordId/complete',
        body: {
          'completedByName': completedByName,
          'resolutionNotes': resolutionNotes,
        },
      );
      return decodeMaintenanceRecord(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<void> markMachinePickedUp(int machineId) async {
    await _apiClient.postJson('/machines/$machineId/pickup');
  }

  @override
  Future<Order?> markRefundProcessed(int orderId) async {
    try {
      final item = await _apiClient.postJson('/orders/$orderId/refund');
      return decodeOrder(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<Machine> updateMachinePrice({
    required int machineId,
    required double price,
  }) async {
    final item = await _apiClient.patchJson(
      '/pricing/machines/$machineId',
      body: {'price': price},
    );
    return decodeMachine(item);
  }

  @override
  Future<List<PricingServiceFee>> getPricingServiceFees() async {
    final items = await _apiClient.getJsonList('/pricing/service-fees');
    return items
        .map((item) => decodePricingServiceFee(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PricingServiceFee> updatePricingServiceFee({
    required String serviceCode,
    required double amount,
    required bool isEnabled,
  }) async {
    final item = await _apiClient.patchJson(
      '/pricing/service-fees/$serviceCode',
      body: {
        'amount': amount,
        'isEnabled': isEnabled,
      },
    );
    return decodePricingServiceFee(item);
  }

  @override
  Future<List<PricingCampaign>> getPricingCampaigns({
    bool activeOnly = false,
  }) async {
    final items = await _apiClient.getJsonList(
      '/pricing/campaigns',
      queryParameters: activeOnly ? {'activeOnly': 'true'} : null,
    );
    return items
        .map((item) => decodePricingCampaign(item as Map<String, dynamic>))
        .toList();
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
    final item = await _apiClient.postJson(
      '/pricing/campaigns',
      body: {
        'name': name,
        'description': description,
        'discountType': discountType,
        'discountValue': discountValue,
        'appliesToService': appliesToService,
        'minOrderAmount': minOrderAmount,
        'isActive': isActive,
        'startsAt': startsAt?.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
      },
    );
    return decodePricingCampaign(item);
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
    try {
      final item = await _apiClient.patchJson(
        '/pricing/campaigns/$campaignId',
        body: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (discountType != null) 'discountType': discountType,
          if (discountValue != null) 'discountValue': discountValue,
          if (appliesToService != null) 'appliesToService': appliesToService,
          if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
          if (isActive != null) 'isActive': isActive,
          if (startsAt != null) 'startsAt': startsAt.toIso8601String(),
          if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
        },
      );
      return decodePricingCampaign(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<PricingQuote> previewPricingQuote({
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required List<String> selectedServices,
  }) async {
    final item = await _apiClient.postJson(
      '/pricing/quote',
      body: {
        'washerMachineId': washer?.id,
        'dryerMachineId': dryer?.id,
        'ironingMachineId': ironingStation?.id,
        'selectedServices': selectedServices,
      },
    );
    return decodePricingQuote(item);
  }

  @override
  Future<List<RefundRequest>> getRefundRequests({String? status}) async {
    final items = await _apiClient.getJsonList(
      '/refund-requests',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return items
        .map((item) => decodeRefundRequest(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<RefundRequest> createRefundRequest({
    required int orderId,
    required String reason,
    String? requestedByName,
  }) async {
    final item = await _apiClient.postJson(
      '/refund-requests',
      body: {
        'orderId': orderId,
        'reason': reason,
        if (requestedByName != null) 'requestedByName': requestedByName,
      },
    );
    return decodeRefundRequest(item);
  }

  @override
  Future<RefundRequest?> markRefundRequestProcessed({
    required int requestId,
    String? processedByName,
  }) async {
    try {
      final item = await _apiClient.postJson(
        '/refund-requests/$requestId/process',
        body: {
          if (processedByName != null) 'processedByName': processedByName,
        },
      );
      return decodeRefundRequest(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<List<DeliveryTask>> getDeliveryTasks() async {
    final raw = await _preferences.getString(_deliveryTasksKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final tasks = (jsonDecode(raw) as List<dynamic>)
        .map((item) => DeliveryTask.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((left, right) {
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
    final items = [...await getDeliveryTasks()];
    final normalized = task.copyWith(updatedAt: DateTime.now());
    final index = items.indexWhere((item) => item.orderId == task.orderId);
    if (index >= 0) {
      items[index] = normalized;
    } else {
      items.add(normalized);
    }
    await _preferences.setString(
      _deliveryTasksKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    return normalized;
  }

  @override
  Future<List<PickupTask>> getPickupTasks() async {
    final raw = await _preferences.getString(_pickupTasksKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final tasks = (jsonDecode(raw) as List<dynamic>)
        .map((item) => PickupTask.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((left, right) {
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
    final items = [...await getPickupTasks()];
    final normalized = task.copyWith(updatedAt: DateTime.now());
    final index = items.indexWhere((item) => item.orderId == task.orderId);
    if (index >= 0) {
      items[index] = normalized;
    } else {
      items.add(normalized);
    }
    await _preferences.setString(
      _pickupTasksKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    return normalized;
  }

  @override
  Future<List<DayEndCheckout>> getDayEndCheckouts({
    int limit = 30,
  }) async {
    final raw = await _preferences.getString(_dayEndCheckoutsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((item) => DayEndCheckout.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((left, right) => right.businessDate.compareTo(left.businessDate));
    return decoded.take(limit).toList();
  }

  @override
  Future<DayEndCheckout> createDayEndCheckout({
    required DateTime businessDate,
    required double openingCash,
    required double closingCashCounted,
    String? notes,
    required String closedByName,
  }) async {
    final checkouts = [...await getDayEndCheckouts(limit: 200)];
    final normalizedDate = DateTime(
      businessDate.year,
      businessDate.month,
      businessDate.day,
    );
    final existingIndex = checkouts.indexWhere(
      (item) =>
          item.businessDate.year == normalizedDate.year &&
          item.businessDate.month == normalizedDate.month &&
          item.businessDate.day == normalizedDate.day,
    );
    final nextCounter = await _preferences.getInt(_dayEndCheckoutCounterKey) ??
        checkouts.length;
    final id =
        existingIndex >= 0 ? checkouts[existingIndex].id : nextCounter + 1;

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
      checkouts[existingIndex] = checkout;
    } else {
      checkouts.add(checkout);
      await _preferences.setInt(_dayEndCheckoutCounterKey, id);
    }

    await _preferences.setString(
      _dayEndCheckoutsKey,
      jsonEncode(checkouts.map((item) => item.toJson()).toList()),
    );
    return checkout;
  }

  @override
  Future<List<StaffMember>> getStaffMembers() async {
    final items = await _apiClient.getJsonList('/staff/members');
    return items
        .map((item) => decodeStaffMember(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<StaffShift>> getStaffShifts({
    required DateTime start,
    required DateTime end,
  }) async {
    final items = await _apiClient.getJsonList(
      '/staff/shifts',
      queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    return items
        .map((item) => decodeStaffShift(item as Map<String, dynamic>))
        .toList();
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
    final item = await _apiClient.postJson(
      '/staff/shifts',
      body: {
        if (shiftId != null) 'shiftId': shiftId,
        'staffId': staffId,
        'shiftDate': DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
        ).toIso8601String(),
        'startTimeLabel': startTimeLabel,
        'endTimeLabel': endTimeLabel,
        'branch': branch,
        'assignment': assignment,
        'hours': hours,
      },
    );
    return decodeStaffShift(item);
  }

  @override
  Future<List<StaffLeaveRequest>> getStaffLeaveRequests(
      {String? status}) async {
    final items = await _apiClient.getJsonList(
      '/staff/leave-requests',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return items
        .map((item) => decodeStaffLeaveRequest(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StaffLeaveRequest?> updateStaffLeaveRequestStatus({
    required int leaveRequestId,
    required String status,
    String? reviewedByName,
  }) async {
    try {
      final item = await _apiClient.patchJson(
        '/staff/leave-requests/$leaveRequestId',
        body: {
          'status': status,
          'reviewedByName': reviewedByName,
        },
      );
      return decodeStaffLeaveRequest(item);
    } on BackendApiException {
      return null;
    }
  }

  @override
  Future<List<StaffPayout>> getStaffPayouts() async {
    final items = await _apiClient.getJsonList('/staff/payouts');
    return items
        .map((item) => decodeStaffPayout(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StaffPayout> createStaffPayout({
    required int staffId,
    required String periodLabel,
    required double hoursWorked,
    required double bonusAmount,
    required double deductionsAmount,
  }) async {
    final item = await _apiClient.postJson(
      '/staff/payouts',
      body: {
        'staffId': staffId,
        'periodLabel': periodLabel,
        'hoursWorked': hoursWorked,
        'bonusAmount': bonusAmount,
        'deductionsAmount': deductionsAmount,
      },
    );
    return decodeStaffPayout(item);
  }

  @override
  Future<StaffPayout?> markStaffPayoutPaid({required int payoutId}) async {
    try {
      final item = await _apiClient.postJson('/staff/payouts/$payoutId/pay');
      return decodeStaffPayout(item);
    } on BackendApiException {
      return null;
    }
  }
}
