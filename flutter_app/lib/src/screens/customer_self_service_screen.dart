import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_pos_repository.dart';
import '../models/active_order_session.dart';
import '../models/machine.dart';
import '../models/payment_session.dart';
import '../widgets/machine_icon.dart';
import '../widgets/payment_status_sheet.dart';

class CustomerSelfServiceScreen extends StatefulWidget {
  const CustomerSelfServiceScreen({
    super.key,
    required this.repository,
    this.refreshInterval = const Duration(seconds: 1),
    this.postPaymentResetDelay = const Duration(seconds: 4),
  });

  final DemoPosRepository repository;
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
  Timer? _refreshTimer;
  Timer? _resetTimer;
  String? _dismissedSessionKey;
  String? _scheduledResetSessionKey;

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

  Machine? _machineById(int id) {
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
    final amount = (washer?.price ?? 0) + (dryer?.price ?? 0);

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

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Screen')),
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
                            Text('Wash option: ${session.washOption}'),
                            Text(
                              'Payment method: ${session.paymentMethod}',
                            ),
                            const SizedBox(height: 16),
                            if (washer != null)
                              _MachineAssignmentTile(
                                title: 'Washer Assigned',
                                machine: washer,
                              ),
                            if (dryer != null) ...[
                              const SizedBox(height: 12),
                              _MachineAssignmentTile(
                                title: 'Dryer Assigned',
                                machine: dryer,
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
                    '${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
