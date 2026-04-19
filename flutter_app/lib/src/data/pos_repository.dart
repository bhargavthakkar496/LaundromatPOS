import '../models/active_order_session.dart';
import '../models/auth_session.dart';
import '../models/customer.dart';
import '../models/customer_profile.dart';
import '../models/inventory.dart';
import '../models/maintenance.dart';
import '../models/machine.dart';
import '../models/machine_reservation.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../models/pos_user.dart';
import '../models/pricing.dart';
import '../models/refund_request.dart';

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

  Future<InventoryDashboard> getInventoryDashboard();

  Future<List<InventoryItem>> getInventoryItems({
    String? searchQuery,
    String? category,
    String? stockStatus,
    String? supplier,
    String? branch,
    String? location,
    String? sortBy,
    String? sortOrder,
  });

  Future<List<InventoryStockMovement>> getInventoryItemMovements(
    int inventoryItemId,
  );

  Future<List<InventoryRestockRequest>> getInventoryRestockRequests({
    String? status,
  });

  Future<InventoryRestockRequest> createInventoryRestockRequest({
    required int inventoryItemId,
    required int requestedQuantity,
    String? requestNotes,
  });

  Future<InventoryRestockRequest> approveInventoryRestockRequest({
    required int requestId,
    required String operatorRemarks,
    String? approverName,
  });

  Future<InventoryRestockRequest> markInventoryRestockRequestProcured({
    required int requestId,
  });

  Future<List<MaintenanceRecord>> getMaintenanceRecords({
    String? status,
  });

  Future<List<Machine>> getMaintenanceEligibleMachines();

  Future<MaintenanceRecord> createMaintenanceRecord({
    required int machineId,
    required String issueTitle,
    String? issueDescription,
    String priority = MaintenancePriority.medium,
    String? reportedByName,
  });

  Future<MaintenanceRecord?> startMaintenanceRecord({
    required int recordId,
    String? startedByName,
  });

  Future<MaintenanceRecord?> completeMaintenanceRecord({
    required int recordId,
    String? completedByName,
    String? resolutionNotes,
  });

  Future<void> markMachinePickedUp(int machineId);

  Future<Order?> markRefundProcessed(int orderId);

  Future<Machine> updateMachinePrice({
    required int machineId,
    required double price,
  });

  Future<List<PricingServiceFee>> getPricingServiceFees();

  Future<PricingServiceFee> updatePricingServiceFee({
    required String serviceCode,
    required double amount,
    required bool isEnabled,
  });

  Future<List<PricingCampaign>> getPricingCampaigns({
    bool activeOnly = false,
  });

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
  });

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
  });

  Future<PricingQuote> previewPricingQuote({
    Machine? washer,
    Machine? dryer,
    Machine? ironingStation,
    required List<String> selectedServices,
  });

  Future<List<RefundRequest>> getRefundRequests({
    String? status,
  });

  Future<RefundRequest> createRefundRequest({
    required int orderId,
    required String reason,
    String? requestedByName,
  });

  Future<RefundRequest?> markRefundRequestProcessed({
    required int requestId,
    String? processedByName,
  });
}
