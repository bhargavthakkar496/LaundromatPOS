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

abstract class PosRepository {
  Future<void> initialize();

  Future<void> dispose();

  Future<AuthSession?> login(String username, String pin);

  Future<List<Machine>> getAvailableMachines();

  Future<List<Machine>> getMachines();

  Future<Machine?> getMachineById(int machineId);

  Future<Customer?> getCustomerByPhone(String phone);

  Future<Customer> saveWalkInCustomer({
    required String fullName,
    required String phone,
    int? preferredWasherSizeKg,
    String? preferredDetergentAddOn,
    int? preferredDryerDurationMinutes,
  });

  Future<List<Machine>> getReservableMachines({
    required String machineType,
    required DateTime startTime,
    required DateTime endTime,
  });

  Future<MachineReservation> createReservation({
    required Machine machine,
    required Customer customer,
    required DateTime startTime,
    required DateTime endTime,
    int? preferredWasherSizeKg,
    String? detergentAddOn,
    int? dryerDurationMinutes,
  });

  Future<Order> createPaidOrder({
    required Machine machine,
    required Customer customer,
    PosUser? user,
    required String paymentMethod,
    String referencePrefix = 'POS',
    String? paymentReference,
  });

  Future<PaymentSession> createPaymentSession({
    required double amount,
    required String paymentMethod,
    String referencePrefix = 'PAY',
    int attempt = 1,
    bool shouldFail = false,
  });

  Future<PaymentSession> pollPaymentSession(int sessionId);

  Future<List<OrderHistoryItem>> getOrderHistory();

  Future<OrderHistoryItem?> getOrderHistoryItemByOrderId(int orderId);

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
  });

  Future<ActiveOrderSession?> getActiveOrderSession();

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
  });

  Future<ActiveOrderSession?> confirmActiveOrderSession({
    required String confirmedBy,
    PosUser? user,
  });

  Future<ActiveOrderSession?> completeActiveOrderPayment({
    required String paymentReference,
  });

  Future<void> clearActiveOrderSession();

  Future<CustomerProfile?> getCustomerProfileByPhone(String phone);

  Future<void> markMachinePickedUp(int machineId);

  Future<Order?> markRefundProcessed(int orderId);
}
