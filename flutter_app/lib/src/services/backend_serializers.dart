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
import '../models/reservation_history_item.dart';

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
    preferredDryerDurationMinutes: json['preferredDryerDurationMinutes'] as int?,
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
  final favoriteMachinesRaw = json['favoriteMachines'] as List<dynamic>? ?? const [];
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
    upcomingReservations: (json['upcomingReservations'] as List<dynamic>? ?? const [])
        .map(
          (item) => decodeReservationHistoryItem(item as Map<String, dynamic>),
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

ActiveOrderSession decodeActiveOrderSession(Map<String, dynamic> json) {
  return ActiveOrderSession.fromJson(json);
}
