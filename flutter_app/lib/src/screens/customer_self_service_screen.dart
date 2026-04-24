import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/active_order_session.dart';
import '../models/customer_profile.dart';
import '../models/machine.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../services/currency_formatter.dart';
import '../widgets/customer_details_form.dart';
import '../widgets/machine_icon.dart';
import '../widgets/payment_status_sheet.dart';

class CustomerSelfServiceScreen extends StatefulWidget {
  const CustomerSelfServiceScreen({
    super.key,
    required this.repository,
    this.refreshInterval = const Duration(seconds: 1),
    this.postPaymentResetDelay = const Duration(seconds: 4),
  });

  final PosRepository repository;
  final Duration? refreshInterval;
  final Duration postPaymentResetDelay;

  @override
  State<CustomerSelfServiceScreen> createState() =>
      _CustomerSelfServiceScreenState();
}

class _CustomerSelfServiceScreenState extends State<CustomerSelfServiceScreen> {
  ActiveOrderSession? _session;
  List<Machine> _machines = const [];
  bool _loading = true;
  bool _confirming = false;
  bool _processingPayment = false;
  bool _lookingUpProfile = false;
  int? _reorderingOrderId;
  Timer? _refreshTimer;
  Timer? _resetTimer;
  String? _dismissedSessionKey;
  String? _scheduledResetSessionKey;
  final TextEditingController _repeatCustomerPhoneController =
      TextEditingController();
  CustomerProfile? _repeatCustomerProfile;
  String? _repeatLookupMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
    final refreshInterval = widget.refreshInterval;
    if (refreshInterval != null) {
      _refreshTimer = Timer.periodic(refreshInterval, (_) {
        if (!mounted) {
          return;
        }
        _refresh(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _resetTimer?.cancel();
    _repeatCustomerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
      });
    }
    final machines = await widget.repository.getMachines();
    final session = await widget.repository.getActiveOrderSession();
    final visibleSession = _visibleSessionForCustomer(session);
    if (!mounted) {
      return;
    }
    setState(() {
      _machines = machines;
      _session = visibleSession;
      _loading = false;
    });
    _scheduleResetIfNeeded(visibleSession);
  }

  Machine? _machineById(int? id) {
    if (id == null) {
      return null;
    }
    for (final machine in _machines) {
      if (machine.id == id) {
        return machine;
      }
    }
    return null;
  }

  Future<void> _confirmFromCustomer() async {
    setState(() {
      _confirming = true;
    });
    final session = await widget.repository.confirmActiveOrderSession(
      confirmedBy: 'Customer',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _confirming = false;
    });
    _refresh(silent: true);
  }

  Future<void> _startPayment() async {
    final session = _session;
    if (session == null || !session.isBooked) {
      return;
    }

    final washer = _machineById(session.washerMachineId);
    final dryer = _machineById(session.dryerMachineId);
    final ironingStation = _machineById(session.ironingMachineId);
    final amount = (washer?.price ?? 0) +
        (dryer?.price ?? 0) +
        (ironingStation?.price ?? 0);

    setState(() {
      _processingPayment = true;
    });

    final paymentSession = await showModalBottomSheet<PaymentSession>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      builder: (context) => PaymentStatusSheet(
        repository: widget.repository,
        amount: amount,
        paymentMethod: session.paymentMethod,
        referencePrefix: 'BOOK',
      ),
    );

    if (!mounted) {
      return;
    }

    if (paymentSession == null || !paymentSession.isPaid) {
      setState(() {
        _processingPayment = false;
      });
      return;
    }

    final updated = await widget.repository.completeActiveOrderPayment(
      paymentReference: paymentSession.reference,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _session = updated;
      _processingPayment = false;
    });
    _scheduleResetIfNeeded(updated);
    _refresh(silent: true);
  }

  Future<void> _lookupRepeatCustomer() async {
    final phone = _repeatCustomerPhoneController.text.trim();
    final phoneError = CustomerDetailsForm.validatePhone(phone);
    if (phoneError != null) {
      setState(() {
        _repeatCustomerProfile = null;
        _repeatLookupMessage = phoneError;
      });
      return;
    }

    setState(() {
      _lookingUpProfile = true;
      _repeatLookupMessage = null;
    });

    final profile = await widget.repository.getCustomerProfileByPhone(phone);
    if (!mounted) {
      return;
    }

    setState(() {
      _lookingUpProfile = false;
      _repeatCustomerProfile = profile;
      _repeatLookupMessage = profile == null
          ? 'No repeat-customer profile was found for that phone number yet.'
          : null;
    });
  }

  Future<void> _repeatPreviousOrder(
    CustomerProfile profile,
    OrderHistoryItem item,
  ) async {
    if (_session != null && !_session!.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finish or clear the current order before starting a repeat order.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _reorderingOrderId = item.order.id;
    });

    final selectedServices = item.order.selectedServices.isNotEmpty
        ? item.order.selectedServices
        : <String>[item.order.serviceType];

    final builtSession = await widget.repository.saveActiveOrderDraft(
      customerName: profile.customer.fullName,
      customerPhone: profile.customer.phone,
      loadSizeKg:
          item.order.loadSizeKg ?? profile.customer.preferredWasherSizeKg ?? 8,
      selectedServices: selectedServices,
      washOption: item.order.washOption,
      washer: _machineById(item.machine.id) ?? item.machine,
      dryer: item.dryerMachine == null
          ? null
          : (_machineById(item.dryerMachine!.id) ?? item.dryerMachine),
      ironingStation: item.ironingMachine == null
          ? null
          : (_machineById(item.ironingMachine!.id) ?? item.ironingMachine),
      paymentMethod: item.order.paymentMethod,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _reorderingOrderId = null;
      _session = _visibleSessionForCustomer(builtSession);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Repeat order is ready and now visible on both customer and operator screens.',
        ),
      ),
    );
    _refresh(silent: true);
  }

  ActiveOrderSession? _visibleSessionForCustomer(ActiveOrderSession? session) {
    final sessionKey = _sessionKey(session);
    if (sessionKey == null) {
      _dismissedSessionKey = null;
      return null;
    }

    if (_dismissedSessionKey != null && _dismissedSessionKey != sessionKey) {
      _dismissedSessionKey = null;
    }

    if (session != null &&
        session.isPaid &&
        _dismissedSessionKey == sessionKey) {
      return null;
    }

    return session;
  }

  void _scheduleResetIfNeeded(ActiveOrderSession? session) {
    if (session == null || !session.isPaid) {
      _resetTimer?.cancel();
      _scheduledResetSessionKey = null;
      return;
    }

    final sessionKey = _sessionKey(session);
    if (sessionKey == null) {
      return;
    }
    if (_scheduledResetSessionKey == sessionKey) {
      return;
    }

    _resetTimer?.cancel();
    _scheduledResetSessionKey = sessionKey;

    _resetTimer = Timer(widget.postPaymentResetDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_sessionKey(_session) == sessionKey) {
          _dismissedSessionKey = sessionKey;
          _session = null;
        }
        if (_scheduledResetSessionKey == sessionKey) {
          _scheduledResetSessionKey = null;
        }
      });
    });
  }

  String? _sessionKey(ActiveOrderSession? session) {
    if (session == null) {
      return null;
    }
    final orderId = session.orderId?.toString() ?? 'no-order';
    final reference = session.paymentReference ?? 'no-reference';
    return '$orderId|$reference|${session.stage}';
  }

  Color _stageColor(ActiveOrderSession session) {
    if (session.isDraft) {
      return const Color(0xFFCA8A04);
    }
    if (session.isBooked) {
      return const Color(0xFF0E7490);
    }
    return const Color(0xFF2A9D8F);
  }

  String _stageLabel(ActiveOrderSession session) {
    if (session.isDraft) {
      return 'Awaiting Confirmation';
    }
    if (session.isBooked) {
      return 'Booked';
    }
    return 'Payment Confirmed';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final washer =
        session == null ? null : _machineById(session.washerMachineId);
    final dryer = session == null ? null : _machineById(session.dryerMachineId);
    final ironingStation =
        session == null ? null : _machineById(session.ironingMachineId);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.customerScreenTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E7490), Color(0xFF1F9CB4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laundry Order Journey',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Review your live order details, confirm the booking, and complete payment from this screen.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (session == null) ...[
                    _RepeatCustomerLookupCard(
                      phoneController: _repeatCustomerPhoneController,
                      loading: _lookingUpProfile,
                      message: _repeatLookupMessage,
                      profile: _repeatCustomerProfile,
                      reorderingOrderId: _reorderingOrderId,
                      onLookup: _lookupRepeatCustomer,
                      onRepeatOrder: (item) =>
                          _repeatPreviousOrder(_repeatCustomerProfile!, item),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (session == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'The operator has not pushed an order yet. Once an order is taken, it will appear here automatically.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Current Order',
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _stageColor(session).withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _stageLabel(session),
                                    style: TextStyle(
                                      color: _stageColor(session),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text('Customer: ${session.customerName}'),
                            Text('Phone: ${session.customerPhone}'),
                            Text('Load size: ${session.loadSizeKg}kg'),
                            Text(
                              'Services: ${session.selectedServices.join(', ')}',
                            ),
                            if (session.washOption != null)
                              Text('Wash option: ${session.washOption}'),
                            Text(
                              'Payment method: ${session.paymentMethod}',
                            ),
                            const SizedBox(height: 16),
                            if (washer != null && session.includesWashing)
                              _MachineAssignmentTile(
                                title: 'Washer Assigned',
                                machine: washer,
                              ),
                            if (dryer != null && session.includesDrying) ...[
                              const SizedBox(height: 12),
                              _MachineAssignmentTile(
                                title: 'Dryer Assigned',
                                machine: dryer,
                              ),
                            ],
                            if (ironingStation != null &&
                                session.includesIroning) ...[
                              const SizedBox(height: 12),
                              _MachineAssignmentTile(
                                title: 'Ironing Station Assigned',
                                machine: ironingStation,
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (session.isDraft)
                              FilledButton.icon(
                                onPressed:
                                    _confirming ? null : _confirmFromCustomer,
                                icon: const Icon(Icons.verified_outlined),
                                label: Text(
                                  _confirming
                                      ? 'Confirming...'
                                      : 'Confirm And Book Order',
                                ),
                              ),
                            if (session.isBooked) ...[
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow,
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'The order is booked. Payment can now be initiated from this customer screen only.',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed:
                                    _processingPayment ? null : _startPayment,
                                icon: const Icon(Icons.payments_outlined),
                                label: Text(
                                  _processingPayment
                                      ? 'Starting payment...'
                                      : 'Initiate Payment',
                                ),
                              ),
                            ],
                            if (session.isPaid) ...[
                              Card(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Confirmed',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Reference: ${session.paymentReference ?? 'Pending'}',
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'This confirmation is now visible on both the customer and operator screens.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MachineAssignmentTile extends StatelessWidget {
  const _MachineAssignmentTile({
    required this.title,
    required this.machine,
  });

  final String title;
  final Machine machine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          MachineIcon(machine: machine, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  machine.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                    '${machine.capacityKg}kg • ${CurrencyFormatter.formatAmountForContext(context, machine.price)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepeatCustomerLookupCard extends StatelessWidget {
  const _RepeatCustomerLookupCard({
    required this.phoneController,
    required this.loading,
    required this.message,
    required this.profile,
    required this.reorderingOrderId,
    required this.onLookup,
    required this.onRepeatOrder,
  });

  final TextEditingController phoneController;
  final bool loading;
  final String? message;
  final CustomerProfile? profile;
  final int? reorderingOrderId;
  final VoidCallback onLookup;
  final ValueChanged<OrderHistoryItem> onRepeatOrder;

  @override
  Widget build(BuildContext context) {
    final recentOrders = [...?profile?.orders]..sort(
        (left, right) => right.order.timestamp.compareTo(left.order.timestamp),
      );
    final lastOrder = recentOrders.isEmpty ? null : recentOrders.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Repeat Customer Quick Order',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Registered customers can enter their phone number to review past orders, saved preferences, and instantly rebuild a familiar order on both screens.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer phone number',
                      hintText: '9876543210',
                    ),
                    onSubmitted: (_) => onLookup(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: loading ? null : onLookup,
                  icon: const Icon(Icons.search_outlined),
                  label: Text(loading ? 'Looking up...' : 'Find Customer'),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (profile != null) ...[
              const SizedBox(height: 20),
              _RepeatCustomerProfileView(
                profile: profile!,
                lastOrder: lastOrder,
                reorderingOrderId: reorderingOrderId,
                onRepeatOrder: onRepeatOrder,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RepeatCustomerProfileView extends StatelessWidget {
  const _RepeatCustomerProfileView({
    required this.profile,
    required this.lastOrder,
    required this.reorderingOrderId,
    required this.onRepeatOrder,
  });

  final CustomerProfile profile;
  final OrderHistoryItem? lastOrder;
  final int? reorderingOrderId;
  final ValueChanged<OrderHistoryItem> onRepeatOrder;

  @override
  Widget build(BuildContext context) {
    final recentOrders = [...profile.orders]..sort(
        (left, right) => right.order.timestamp.compareTo(left.order.timestamp),
      );
    final visibleOrders = recentOrders.take(3).toList();
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.customer.fullName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(profile.customer.phone),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _RepeatStatPill(
                    label: 'Visits',
                    value: '${profile.totalVisits}',
                  ),
                  _RepeatStatPill(
                    label: 'Spent',
                    value: CurrencyFormatter.formatAmountForContext(
                      context,
                      profile.totalSpent,
                    ),
                  ),
                  _RepeatStatPill(
                    label: 'Preferred load',
                    value: profile.customer.preferredWasherSizeKg == null
                        ? 'Not set'
                        : '${profile.customer.preferredWasherSizeKg}kg',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Saved preferences: detergent ${profile.customer.preferredDetergentAddOn ?? 'Not set'}, dryer ${profile.customer.preferredDryerDurationMinutes == null ? 'Not set' : '${profile.customer.preferredDryerDurationMinutes} min'}.',
              ),
              if (lastOrder != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: reorderingOrderId == lastOrder!.order.id
                      ? null
                      : () => onRepeatOrder(lastOrder!),
                  icon: const Icon(Icons.history_toggle_off_outlined),
                  label: Text(
                    reorderingOrderId == lastOrder!.order.id
                        ? 'Building repeat order...'
                        : 'Repeat Last Order',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Previous Orders',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (visibleOrders.isEmpty)
          const Text('No previous orders are available yet.')
        else
          ...visibleOrders.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.machine.name} • ${CurrencyFormatter.formatAmountForContext(context, item.order.amount)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          dateFormat.format(item.order.timestamp),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Services: ${item.order.selectedServices.join(', ')}',
                    ),
                    if (item.order.washOption != null)
                      Text('Wash option: ${item.order.washOption}'),
                    Text('Payment method: ${item.order.paymentMethod}'),
                    if (item.dryerMachine != null)
                      Text('Dryer: ${item.dryerMachine!.name}'),
                    if (item.ironingMachine != null)
                      Text('Ironing: ${item.ironingMachine!.name}'),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: reorderingOrderId == item.order.id
                          ? null
                          : () => onRepeatOrder(item),
                      icon: const Icon(Icons.replay_outlined),
                      label: Text(
                        reorderingOrderId == item.order.id
                            ? 'Building order...'
                            : 'Use This Order',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RepeatStatPill extends StatelessWidget {
  const _RepeatStatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
