import '../models/active_order_session.dart';
import '../models/auth_session.dart';
import '../models/customer.dart';
import '../models/customer_profile.dart';
import '../models/machine.dart';
import '../models/machine_reservation.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../models/pos_user.dart';
import '../services/backend_api_client.dart';
import '../services/backend_serializers.dart';
import 'pos_repository.dart';

class BackendPosRepository implements PosRepository {
  BackendPosRepository({
    required BackendApiClient apiClient,
  }) : _apiClient = apiClient;

  final BackendApiClient _apiClient;

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
    return items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Machine>> getMachines() async {
    final items = await _apiClient.getJsonList('/machines');
    return items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Machine?> getMachineById(int machineId) async {
    try {
      final item = await _apiClient.getJson('/machines/$machineId');
      return decodeMachine(item);
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
    return items.map((item) => decodeMachine(item as Map<String, dynamic>)).toList();
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
}
