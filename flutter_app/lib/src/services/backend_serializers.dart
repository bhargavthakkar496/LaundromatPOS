import '../models/active_order_session.dart';
import '../models/auth_session.dart';
import '../models/customer.dart';
import '../models/customer_profile.dart';
import '../models/garment_item.dart';
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
import '../models/reservation_history_item.dart';
import '../models/staff.dart';

PosUser decodePosUser(Map<String, dynamic> json) {
  return PosUser(
    id: json['id'] as int,
    username: json['username'] as String,
    displayName: json['displayName'] as String,
    pin: json['pin'] as String? ?? '',
    role: json['role'] as String,
  );
}

AuthSession decodeAuthSession(Map<String, dynamic> json) {
  return AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    user: decodePosUser(json['user'] as Map<String, dynamic>),
  );
}

Map<String, Object?> encodeAuthSession(AuthSession session) {
  return {
    'accessToken': session.accessToken,
    'refreshToken': session.refreshToken,
    'expiresAt': session.expiresAt?.toIso8601String(),
    'user': {
      'id': session.user.id,
      'username': session.user.username,
      'displayName': session.user.displayName,
      'role': session.user.role,
    },
  };
}

Customer decodeCustomer(Map<String, dynamic> json) {
  return Customer(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    preferredWasherSizeKg: json['preferredWasherSizeKg'] as int?,
    preferredDetergentAddOn: json['preferredDetergentAddOn'] as String?,
    preferredDryerDurationMinutes:
        json['preferredDryerDurationMinutes'] as int?,
  );
}

InventoryDashboard decodeInventoryDashboard(Map<String, dynamic> json) {
  return InventoryDashboard(
    metrics: InventoryDashboardMetrics(
      lowStockCount: json['metrics']['lowStockCount'] as int,
      outOfStockCount: json['metrics']['outOfStockCount'] as int,
      stockValue: (json['metrics']['stockValue'] as num).toDouble(),
      pendingPurchaseOrders: json['metrics']['pendingPurchaseOrders'] as int,
      expiringSoonCount: json['metrics']['expiringSoonCount'] as int,
    ),
    categories: (json['categories'] as List<dynamic>? ?? const [])
        .map(
          (item) => InventoryCategorySummary(
            category: item['category'] as String,
            itemCount: item['itemCount'] as int,
            lowStockCount: item['lowStockCount'] as int,
            outOfStockCount: item['outOfStockCount'] as int,
          ),
        )
        .toList(),
    suppliers: (json['suppliers'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList(),
    branches: (json['branches'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList(),
    locations: (json['locations'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList(),
  );
}

InventoryItem decodeInventoryItem(Map<String, dynamic> json) {
  return InventoryItem(
    id: json['id'] as int,
    sku: json['sku'] as String,
    barcode: json['barcode'] as String?,
    name: json['name'] as String,
    category: json['category'] as String,
    supplier: json['supplier'] as String?,
    branch: json['branch'] as String,
    location: json['location'] as String,
    unit: json['unit'] as String,
    unitType: json['unitType'] as String,
    packSize: json['packSize'] as String?,
    quantityOnHand: json['quantityOnHand'] as int,
    reorderPoint: json['reorderPoint'] as int,
    parLevel: json['parLevel'] as int,
    unitCost: (json['unitCost'] as num).toDouble(),
    sellingPrice: json['sellingPrice'] == null
        ? null
        : (json['sellingPrice'] as num).toDouble(),
    stockValue: (json['stockValue'] as num).toDouble(),
    lastRestockedAt: json['lastRestockedAt'] == null
        ? null
        : DateTime.parse(json['lastRestockedAt'] as String),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String),
    stockStatus: json['stockStatus'] as String,
    isActive: json['isActive'] as bool,
    reorderUrgencyScore: json['reorderUrgencyScore'] as int,
    activeRestockRequestId: json['activeRestockRequestId'] as int?,
    activeRestockRequestStatus: json['activeRestockRequestStatus'] as String?,
    activeRestockRequestNumber: json['activeRestockRequestNumber'] as String?,
    activeRestockRequestedQuantity:
        json['activeRestockRequestedQuantity'] as int?,
    activeRestockOperatorRemarks:
        json['activeRestockOperatorRemarks'] as String?,
    activeRestockApprovedAt: json['activeRestockApprovedAt'] == null
        ? null
        : DateTime.parse(json['activeRestockApprovedAt'] as String),
  );
}

InventoryStockMovement decodeInventoryStockMovement(
  Map<String, dynamic> json,
) {
  return InventoryStockMovement(
    id: json['id'] as int,
    inventoryItemId: json['inventoryItemId'] as int,
    movementType: json['movementType'] as String,
    quantityDelta: json['quantityDelta'] as int,
    balanceAfter: json['balanceAfter'] as int,
    referenceType: json['referenceType'] as String?,
    referenceId: json['referenceId'] as String?,
    notes: json['notes'] as String?,
    performedByName: json['performedByName'] as String?,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
  );
}

InventoryRestockRequest decodeInventoryRestockRequest(
  Map<String, dynamic> json,
) {
  return InventoryRestockRequest(
    id: json['id'] as int,
    requestNumber: json['requestNumber'] as String,
    inventoryItemId: json['inventoryItemId'] as int,
    itemName: json['itemName'] as String,
    itemSku: json['itemSku'] as String,
    itemCategory: json['itemCategory'] as String,
    supplier: json['supplier'] as String?,
    branch: json['branch'] as String,
    location: json['location'] as String,
    unit: json['unit'] as String,
    requestedQuantity: json['requestedQuantity'] as int,
    status: json['status'] as String,
    requestNotes: json['requestNotes'] as String?,
    operatorRemarks: json['operatorRemarks'] as String?,
    requestedByName: json['requestedByName'] as String?,
    approvedByName: json['approvedByName'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    approvedAt: json['approvedAt'] == null
        ? null
        : DateTime.parse(json['approvedAt'] as String),
  );
}

MaintenanceRecord decodeMaintenanceRecord(Map<String, dynamic> json) {
  return MaintenanceRecord(
    id: json['id'] as int,
    machineId: json['machineId'] as int,
    issueTitle: json['issueTitle'] as String,
    issueDescription: json['issueDescription'] as String?,
    priority: json['priority'] as String,
    status: json['status'] as String,
    reportedByName: json['reportedByName'] as String?,
    startedByName: json['startedByName'] as String?,
    completedByName: json['completedByName'] as String?,
    reportedAt: DateTime.parse(json['reportedAt'] as String),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    resolutionNotes: json['resolutionNotes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

Machine decodeMachine(Map<String, dynamic> json) {
  return Machine(
    id: json['id'] as int,
    name: json['name'] as String,
    type: json['type'] as String,
    capacityKg: json['capacityKg'] as int,
    price: (json['price'] as num).toDouble(),
    status: json['status'] as String,
    currentOrderId: json['currentOrderId'] as int?,
    cycleStartedAt: json['cycleStartedAt'] == null
        ? null
        : DateTime.parse(json['cycleStartedAt'] as String),
    cycleEndsAt: json['cycleEndsAt'] == null
        ? null
        : DateTime.parse(json['cycleEndsAt'] as String),
  );
}

Order decodeOrder(Map<String, dynamic> json) {
  return Order(
    id: json['id'] as int,
    machineId: json['machineId'] as int,
    customerId: json['customerId'] as int,
    createdByUserId: json['createdByUserId'] as int?,
    serviceType: json['serviceType'] as String,
    selectedServices: (json['selectedServices'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList(),
    amount: (json['amount'] as num).toDouble(),
    status: json['status'] as String,
    paymentMethod: json['paymentMethod'] as String,
    paymentStatus: json['paymentStatus'] as String,
    paymentReference: json['paymentReference'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    loadSizeKg: json['loadSizeKg'] as int?,
    washOption: json['washOption'] as String?,
    dryerMachineId: json['dryerMachineId'] as int?,
    ironingMachineId: json['ironingMachineId'] as int?,
    garmentItems: (json['garmentItems'] as List<dynamic>? ?? const [])
        .map((item) => GarmentItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

MachineReservation decodeMachineReservation(Map<String, dynamic> json) {
  return MachineReservation(
    id: json['id'] as int,
    machineId: json['machineId'] as int,
    customerId: json['customerId'] as int,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    preferredWasherSizeKg: json['preferredWasherSizeKg'] as int?,
    detergentAddOn: json['detergentAddOn'] as String?,
    dryerDurationMinutes: json['dryerDurationMinutes'] as int?,
  );
}

OrderHistoryItem decodeOrderHistoryItem(Map<String, dynamic> json) {
  return OrderHistoryItem(
    order: decodeOrder(json['order'] as Map<String, dynamic>),
    machine: decodeMachine(json['machine'] as Map<String, dynamic>),
    customer: decodeCustomer(json['customer'] as Map<String, dynamic>),
    dryerMachine: json['dryerMachine'] == null
        ? null
        : decodeMachine(json['dryerMachine'] as Map<String, dynamic>),
    ironingMachine: json['ironingMachine'] == null
        ? null
        : decodeMachine(json['ironingMachine'] as Map<String, dynamic>),
  );
}

ReservationHistoryItem decodeReservationHistoryItem(Map<String, dynamic> json) {
  return ReservationHistoryItem(
    reservation: decodeMachineReservation(
      json['reservation'] as Map<String, dynamic>,
    ),
    machine: decodeMachine(json['machine'] as Map<String, dynamic>),
    customer: decodeCustomer(json['customer'] as Map<String, dynamic>),
  );
}

CustomerProfile decodeCustomerProfile(Map<String, dynamic> json) {
  final favoriteMachinesRaw =
      json['favoriteMachines'] as List<dynamic>? ?? const [];
  return CustomerProfile(
    customer: decodeCustomer(json['customer'] as Map<String, dynamic>),
    orders: (json['orders'] as List<dynamic>? ?? const [])
        .map((item) => decodeOrderHistoryItem(item as Map<String, dynamic>))
        .toList(),
    totalSpent: (json['totalSpent'] as num).toDouble(),
    totalVisits: json['totalVisits'] as int,
    favoriteMachines: favoriteMachinesRaw
        .map(
          (item) => FavoriteMachineStat(
            machine: decodeMachine(
              (item as Map<String, dynamic>)['machine'] as Map<String, dynamic>,
            ),
            usageCount: item['usageCount'] as int,
          ),
        )
        .toList(),
    upcomingReservations:
        (json['upcomingReservations'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  decodeReservationHistoryItem(item as Map<String, dynamic>),
            )
            .toList(),
  );
}

PaymentSession decodePaymentSession(Map<String, dynamic> json) {
  return PaymentSession(
    id: json['id'] as int,
    amount: (json['amount'] as num).toDouble(),
    paymentMethod: json['paymentMethod'] as String,
    reference: json['reference'] as String,
    qrPayload: json['qrPayload'] as String,
    status: json['status'] as String,
    attempt: json['attempt'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    checkedAt: DateTime.parse(json['checkedAt'] as String),
    failureReason: json['failureReason'] as String?,
  );
}

RefundRequest decodeRefundRequest(Map<String, dynamic> json) {
  return RefundRequest(
    id: json['id'] as int,
    orderId: json['orderId'] as int,
    customerName: json['customerName'] as String,
    customerPhone: json['customerPhone'] as String,
    machineName: json['machineName'] as String,
    amount: (json['amount'] as num).toDouble(),
    paymentMethod: json['paymentMethod'] as String,
    paymentReference: json['paymentReference'] as String,
    reason: json['reason'] as String,
    status: json['status'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String),
    requestedByName: json['requestedByName'] as String?,
    processedAt: json['processedAt'] == null
        ? null
        : DateTime.parse(json['processedAt'] as String),
    processedByName: json['processedByName'] as String?,
  );
}

StaffMember decodeStaffMember(Map<String, dynamic> json) {
  return StaffMember(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    role: json['role'] as String,
    phone: json['phone'] as String,
    hourlyRate: (json['hourlyRate'] as num).toDouble(),
    isActive: json['isActive'] as bool,
  );
}

StaffShift decodeStaffShift(Map<String, dynamic> json) {
  return StaffShift(
    id: json['id'] as int,
    staffId: json['staffId'] as int,
    shiftDate: DateTime.parse(json['shiftDate'] as String),
    startTimeLabel: json['startTimeLabel'] as String,
    endTimeLabel: json['endTimeLabel'] as String,
    branch: json['branch'] as String,
    assignment: json['assignment'] as String,
    hours: (json['hours'] as num).toDouble(),
  );
}

StaffLeaveRequest decodeStaffLeaveRequest(Map<String, dynamic> json) {
  return StaffLeaveRequest(
    id: json['id'] as int,
    staffId: json['staffId'] as int,
    staffName: json['staffName'] as String,
    leaveType: json['leaveType'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: DateTime.parse(json['endDate'] as String),
    status: json['status'] as String,
    reason: json['reason'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String),
    reviewedByName: json['reviewedByName'] as String?,
  );
}

StaffPayout decodeStaffPayout(Map<String, dynamic> json) {
  return StaffPayout(
    id: json['id'] as int,
    staffId: json['staffId'] as int,
    staffName: json['staffName'] as String,
    periodLabel: json['periodLabel'] as String,
    hoursWorked: (json['hoursWorked'] as num).toDouble(),
    grossAmount: (json['grossAmount'] as num).toDouble(),
    bonusAmount: (json['bonusAmount'] as num).toDouble(),
    deductionsAmount: (json['deductionsAmount'] as num).toDouble(),
    netAmount: (json['netAmount'] as num).toDouble(),
    status: json['status'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    paidAt: json['paidAt'] == null
        ? null
        : DateTime.parse(json['paidAt'] as String),
  );
}

PricingServiceFee decodePricingServiceFee(Map<String, dynamic> json) {
  return PricingServiceFee(
    serviceCode: json['serviceCode'] as String,
    displayName: json['displayName'] as String,
    amount: (json['amount'] as num).toDouble(),
    isEnabled: json['isEnabled'] as bool,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

PricingCampaign decodePricingCampaign(Map<String, dynamic> json) {
  return PricingCampaign(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String?,
    discountType: json['discountType'] as String,
    discountValue: (json['discountValue'] as num).toDouble(),
    appliesToService: json['appliesToService'] as String?,
    minOrderAmount: (json['minOrderAmount'] as num).toDouble(),
    isActive: json['isActive'] as bool,
    startsAt: json['startsAt'] == null
        ? null
        : DateTime.parse(json['startsAt'] as String),
    endsAt: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

PricingQuote decodePricingQuote(Map<String, dynamic> json) {
  return PricingQuote(
    machineSubtotal: (json['machineSubtotal'] as num).toDouble(),
    serviceFeeTotal: (json['serviceFeeTotal'] as num).toDouble(),
    discountTotal: (json['discountTotal'] as num).toDouble(),
    finalTotal: (json['finalTotal'] as num).toDouble(),
    appliedCampaigns: (json['appliedCampaigns'] as List<dynamic>? ?? const [])
        .map((item) => decodePricingCampaign(item as Map<String, dynamic>))
        .toList(),
    lines: (json['lines'] as List<dynamic>? ?? const [])
        .map(
          (item) => PricingQuoteLine(
            label: item['label'] as String,
            type: item['type'] as String,
            amount: (item['amount'] as num).toDouble(),
          ),
        )
        .toList(),
  );
}

ActiveOrderSession decodeActiveOrderSession(Map<String, dynamic> json) {
  return ActiveOrderSession.fromJson(json);
}
