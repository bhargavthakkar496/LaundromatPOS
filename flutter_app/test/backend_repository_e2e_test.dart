import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:washpos_flutter/src/models/active_order_session.dart';
import 'package:washpos_flutter/src/data/backend_pos_repository.dart';
import 'package:washpos_flutter/src/models/machine.dart';
import 'package:washpos_flutter/src/services/backend_api_client.dart';
import 'package:washpos_flutter/src/services/session_store.dart';

const _runBackendSmoke = bool.fromEnvironment(
  'POS_RUN_BACKEND_SMOKE',
  defaultValue: false,
);
const _backendBaseUrl = String.fromEnvironment(
  'POS_BACKEND_BASE_URL',
  defaultValue: '',
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  test(
    'backend repository supports reservation and active order flows',
    () async {
      final sessionStore = SessionStore();
      final repository = BackendPosRepository(
        apiClient: BackendApiClient(
          baseUrl: _backendBaseUrl,
          sessionStore: sessionStore,
        ),
      );

      await repository.initialize();
      addTearDown(() async {
        await repository.dispose();
      });

      final authSession = await repository.login('admin', '1234');
      expect(authSession, isNotNull);
      await sessionStore.saveSession(authSession!);

      final existingSession = await repository.getActiveOrderSession();
      if (existingSession != null) {
        await repository.clearActiveOrderSession();
      }

      final customerPhone = _uniquePhone('6');
      final customer = await repository.saveWalkInCustomer(
        fullName: 'Flutter Backend Smoke',
        phone: customerPhone,
        preferredWasherSizeKg: 8,
        preferredDetergentAddOn: 'Softener',
        preferredDryerDurationMinutes: 30,
      );
      expect(customer.phone, customerPhone);

      final now = DateTime.now().toUtc();
      final reservationStart = now.add(const Duration(hours: 30));
      final reservationEnd = reservationStart.add(const Duration(hours: 1));
      final reservableWashers = await repository.getReservableMachines(
        machineType: 'washer',
        startTime: reservationStart,
        endTime: reservationEnd,
      );
      expect(reservableWashers, isNotEmpty);

      final reservation = await repository.createReservation(
        machine: reservableWashers.first,
        customer: customer,
        startTime: reservationStart,
        endTime: reservationEnd,
        preferredWasherSizeKg: 8,
        detergentAddOn: 'Softener',
        dryerDurationMinutes: 30,
      );
      expect(reservation.customerId, customer.id);
      expect(reservation.isBooked, isTrue);

      final profile = await repository.getCustomerProfileByPhone(customerPhone);
      expect(profile, isNotNull);
      expect(
        profile!.upcomingReservations.any(
          (item) => item.reservation.id == reservation.id,
        ),
        isTrue,
      );

      final machines = await repository.getMachines();
      final washer = machines.firstWhere(
        (machine) => machine.isWasher && machine.isAvailable,
      );
      final dryer = machines.firstWhere(
        (machine) => machine.isDryer && machine.isAvailable,
      );

      final draft = await repository.saveActiveOrderDraft(
        customerName: 'Flutter Backend Smoke',
        customerPhone: customerPhone,
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
      expect(draft.isDraft, isTrue);

      final confirmed = await repository.confirmActiveOrderSession(
        confirmedBy: 'Customer',
      );
      expect(confirmed, isNotNull);
      expect(confirmed!.isBooked, isTrue);
      expect(confirmed.orderId, isNotNull);

      final paymentReference =
          'BOOK-FLUTTER-${DateTime.now().millisecondsSinceEpoch}';
      final paid = await repository.completeActiveOrderPayment(
        paymentReference: paymentReference,
      );
      expect(paid, isNotNull);
      expect(paid!.isPaid, isTrue);

      final historyItem = await repository.getOrderHistoryItemByOrderId(
        paid.orderId!,
      );
      expect(historyItem, isNotNull);
      expect(historyItem!.order.paymentReference, paymentReference);
      expect(historyItem.order.paymentStatus, 'PAID');

      await repository.markMachinePickedUp(washer.id);
      await repository.clearActiveOrderSession();
    },
    skip: !_runBackendSmoke || _backendBaseUrl.trim().isEmpty,
  );
}

String _uniquePhone(String prefix) {
  final digits = '${DateTime.now().millisecondsSinceEpoch}'.padLeft(10, '0');
  return '$prefix${digits.substring(digits.length - 9)}';
}
