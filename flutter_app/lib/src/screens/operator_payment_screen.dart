import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/active_order_session.dart';
import '../models/machine.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/payment_session.dart';
import '../models/pos_user.dart';
import '../models/refund_request.dart';
import '../services/currency_formatter.dart';
import '../widgets/payment_status_sheet.dart';

class OperatorPaymentScreen extends StatefulWidget {
  const OperatorPaymentScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final PosRepository repository;
  final PosUser user;

  @override
  State<OperatorPaymentScreen> createState() => _OperatorPaymentScreenState();
}

class _OperatorPaymentScreenState extends State<OperatorPaymentScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final DateFormat _dayFormat = DateFormat('dd MMM yyyy');

  ActiveOrderSession? _activeSession;
  List<Machine> _machines = const [];
  List<OrderHistoryItem> _history = const [];
  List<RefundRequest> _refundRequests = const [];
  bool _loading = true;
  bool _processingActivePayment = false;
  int? _creatingRefundRequestOrderId;
  DateTime _selectedReportDate = DateTime.now();
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    final results = await Future.wait([
      widget.repository.getActiveOrderSession(),
      widget.repository.getMachines(),
      widget.repository.getOrderHistory(),
      widget.repository.getRefundRequests(status: RefundRequestStatus.pending),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _activeSession = results[0] as ActiveOrderSession?;
      _machines = results[1] as List<Machine>;
      _history = results[2] as List<OrderHistoryItem>;
      _refundRequests = results[3] as List<RefundRequest>;
      _loading = false;
    });
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

  double _sessionAmount(ActiveOrderSession session) {
    return (_machineById(session.washerMachineId)?.price ?? 0) +
        (_machineById(session.dryerMachineId)?.price ?? 0) +
        (_machineById(session.ironingMachineId)?.price ?? 0);
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _pickReportDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedReportDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedReportDate = picked;
    });
  }

  Future<void> _startActivePayment() async {
    final session = _activeSession;
    if (session == null || !session.isBooked) {
      return;
    }

    setState(() {
      _processingActivePayment = true;
    });

    final paymentSession = await showModalBottomSheet<PaymentSession>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PaymentStatusSheet(
        repository: widget.repository,
        amount: _sessionAmount(session),
        paymentMethod: session.paymentMethod,
        referencePrefix: 'OPR',
      ),
    );

    if (!mounted) {
      return;
    }

    if (paymentSession == null || !paymentSession.isPaid) {
      setState(() {
        _processingActivePayment = false;
      });
      return;
    }

    await widget.repository.completeActiveOrderPayment(
      paymentReference: paymentSession.reference,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _processingActivePayment = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Operator payment completed successfully.')),
    );
    _loadData(showLoading: false);
  }

  Future<void> _requestRefund(OrderHistoryItem item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Refund Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.customer.fullName} • ${item.order.paymentReference}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason for refund',
                hintText:
                    'Customer was overcharged, duplicate payment, quality complaint, or service issue.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length < 5) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Send To Refund Queue'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null) {
      return;
    }

    setState(() {
      _creatingRefundRequestOrderId = item.order.id;
    });

    await widget.repository.createRefundRequest(
      orderId: item.order.id,
      reason: reason,
      requestedByName: widget.user.displayName,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _creatingRefundRequestOrderId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refund request pushed to the Refunds queue.'),
      ),
    );
    _loadData(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final pendingRefundOrderIds = _refundRequests
        .where((item) => item.isPending)
        .map((item) => item.orderId)
        .toSet();
    final reportItems = _history
        .where((item) => _isSameDate(item.order.timestamp, _selectedReportDate))
        .toList();
    final grossCollection = reportItems.fold<double>(
      0,
      (sum, item) => sum + item.order.amount,
    );
    final refundedTotal = reportItems
        .where((item) => item.order.paymentStatus == PaymentStatus.refunded)
        .fold<double>(0, (sum, item) => sum + item.order.amount);
    final netCollection = grossCollection - refundedTotal;
    final cardTotal = reportItems
        .where((item) => item.order.paymentMethod == 'Card')
        .fold<double>(0, (sum, item) => sum + item.order.amount);
    final cashTotal = reportItems
        .where((item) => item.order.paymentMethod == 'Cash')
        .fold<double>(0, (sum, item) => sum + item.order.amount);
    final upiTotal = reportItems
        .where((item) => item.order.paymentMethod == 'UPI QR')
        .fold<double>(0, (sum, item) => sum + item.order.amount);

    final historyItems = _history.where((item) {
      final matchesSearch = query.isEmpty ||
          item.customer.fullName.toLowerCase().contains(query) ||
          item.customer.phone.toLowerCase().contains(query) ||
          item.order.paymentReference.toLowerCase().contains(query) ||
          item.order.paymentMethod.toLowerCase().contains(query) ||
          item.machine.name.toLowerCase().contains(query);
      final matchesFilter =
          _statusFilter == 'ALL' || item.order.paymentStatus == _statusFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.operatorPayments),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadData(showLoading: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E7490), Color(0xFF1F9CB4)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Operations Desk',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Handle the live operator checkout, search prior customer payments, and send refund cases into the refund queue from one place.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildActivePaymentCard(context),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Date-wise Payment Aggregate',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickReportDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label:
                                  Text(_dayFormat.format(_selectedReportDate)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _ReportMetricCard(
                              label: 'Transactions',
                              value: '${reportItems.length}',
                              tone: const Color(0xFF0E7490),
                            ),
                            _ReportMetricCard(
                              label: 'Gross',
                              value:
                                  CurrencyFormatter.formatAmountForContext(
                                    context,
                                    grossCollection,
                                  ),
                              tone: const Color(0xFF2A9D8F),
                            ),
                            _ReportMetricCard(
                              label: 'Refunded',
                              value: CurrencyFormatter.formatAmountForContext(
                                context,
                                refundedTotal,
                              ),
                              tone: const Color(0xFFB42318),
                            ),
                            _ReportMetricCard(
                              label: 'Net',
                              value: CurrencyFormatter.formatAmountForContext(
                                context,
                                netCollection,
                              ),
                              tone: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MethodChip(label: 'UPI QR', total: upiTotal),
                            _MethodChip(label: 'Card', total: cardTotal),
                            _MethodChip(label: 'Cash', total: cashTotal),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Past Customer Payments',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText:
                                'Search by customer, phone, reference, machine, or payment method',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip('ALL', 'All'),
                            _buildStatusChip(PaymentStatus.paid, 'Paid'),
                            _buildStatusChip(
                              PaymentStatus.refunded,
                              'Refunded',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (historyItems.isEmpty)
                          const Text(
                              'No payment records match the current search.')
                        else
                          ...historyItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PaymentHistoryCard(
                                item: item,
                                formattedDate: _dateTimeFormat
                                    .format(item.order.timestamp),
                                refundQueued: pendingRefundOrderIds
                                    .contains(item.order.id),
                                creatingRefund: _creatingRefundRequestOrderId ==
                                    item.order.id,
                                onRequestRefund: item.order.paymentStatus ==
                                            PaymentStatus.paid &&
                                        !pendingRefundOrderIds.contains(
                                          item.order.id,
                                        )
                                    ? () => _requestRefund(item)
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActivePaymentCard(BuildContext context) {
    final session = _activeSession;
    if (session == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'No active operator-side order is waiting for payment right now.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final washer = _machineById(session.washerMachineId);
    final dryer = _machineById(session.dryerMachineId);
    final ironingStation = _machineById(session.ironingMachineId);
    final amount = _sessionAmount(session);
    final stageLabel = session.isBooked
        ? 'Booked and ready for payment'
        : session.isPaid
            ? 'Payment already completed'
            : 'Draft order awaiting confirmation';
    final stageColor = session.isBooked
        ? const Color(0xFF0E7490)
        : session.isPaid
            ? const Color(0xFF2A9D8F)
            : const Color(0xFFCA8A04);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Live Operator Checkout',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stageLabel,
                    style: TextStyle(
                      color: stageColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailPill(label: 'Customer', value: session.customerName),
                _DetailPill(label: 'Phone', value: session.customerPhone),
                _DetailPill(
                  label: 'Amount',
                  value: CurrencyFormatter.formatAmountForContext(
                    context,
                    amount,
                  ),
                ),
                _DetailPill(label: 'Payment', value: session.paymentMethod),
                _DetailPill(
                  label: 'Services',
                  value: session.selectedServices.join(', '),
                ),
                if (washer != null)
                  _DetailPill(label: 'Washer', value: washer.name),
                if (dryer != null)
                  _DetailPill(label: 'Dryer', value: dryer.name),
                if (ironingStation != null)
                  _DetailPill(label: 'Ironing', value: ironingStation.name),
              ],
            ),
            if (session.isBooked) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    _processingActivePayment ? null : _startActivePayment,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  _processingActivePayment
                      ? 'Processing Payment...'
                      : 'Start Operator Payment',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _statusFilter == value,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.label, required this.total});

  final String label;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${CurrencyFormatter.formatAmountForContext(context, total)}',
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.item,
    required this.formattedDate,
    required this.refundQueued,
    required this.creatingRefund,
    required this.onRequestRefund,
  });

  final OrderHistoryItem item;
  final String formattedDate;
  final bool refundQueued;
  final bool creatingRefund;
  final VoidCallback? onRequestRefund;

  @override
  Widget build(BuildContext context) {
    final isRefunded = item.order.paymentStatus == PaymentStatus.refunded;
    final tone = isRefunded
        ? const Color(0xFFB42318)
        : refundQueued
            ? const Color(0xFFD97706)
            : const Color(0xFF2A9D8F);
    final statusLabel = isRefunded
        ? 'Refunded'
        : refundQueued
            ? 'Refund Requested'
            : 'Paid';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.customer.fullName} • ${item.machine.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                Text('Phone: ${item.customer.phone}'),
                Text('Reference: ${item.order.paymentReference}'),
                Text('Method: ${item.order.paymentMethod}'),
                Text(
                  'Amount: ${CurrencyFormatter.formatAmountForContext(context, item.order.amount)}',
                ),
                Text(formattedDate),
              ],
            ),
            if (onRequestRefund != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: creatingRefund ? null : onRequestRefund,
                icon: const Icon(Icons.reply_all_rounded),
                label: Text(
                  creatingRefund
                      ? 'Sending To Refund Queue...'
                      : 'Create Refund Request',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
