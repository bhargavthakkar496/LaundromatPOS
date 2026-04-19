import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/pos_repository.dart';
import '../models/active_order_session.dart';
import '../models/machine.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/pos_user.dart';
import '../models/refund_request.dart';
import '../models/revenue.dart';
import '../services/revenue_report_service.dart';
import '../services/revenue_reporting_service.dart';

class RevenueDashboardScreen extends StatefulWidget {
  const RevenueDashboardScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final PosRepository repository;
  final PosUser user;

  @override
  State<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends State<RevenueDashboardScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _openingCashController =
      TextEditingController(text: '0');
  final TextEditingController _countedCashController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  List<OrderHistoryItem> _history = const [];
  List<RefundRequest> _refundRequests = const [];
  List<DayEndCheckout> _checkouts = const [];
  bool _loading = true;
  bool _printingReport = false;
  bool _submittingDayEnd = false;
  DateTime _rangeStart = _startOfDay(DateTime.now());
  DateTime _rangeEnd = _startOfDay(DateTime.now()).add(const Duration(days: 1));
  DateTime _dayEndDate = _startOfDay(DateTime.now());
  String _rangePreset = 'TODAY';
  String _paymentMethodFilter = 'ALL';
  String _paymentStatusFilter = 'ALL';
  String _serviceFilter = 'ALL';
  String _machineTypeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _openingCashController.dispose();
    _countedCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }
    final results = await Future.wait([
      widget.repository.getOrderHistory(),
      widget.repository.getRefundRequests(),
      widget.repository.getDayEndCheckouts(),
    ]);

    if (!mounted) {
      return;
    }
    setState(() {
      _history = results[0] as List<OrderHistoryItem>;
      _refundRequests = results[1] as List<RefundRequest>;
      _checkouts = results[2] as List<DayEndCheckout>;
      _loading = false;
    });
  }

  List<OrderHistoryItem> get _filteredTransactions =>
      RevenueReportingService.filterTransactions(
        history: _history,
        start: _rangeStart,
        end: _rangeEnd,
        paymentMethod: _paymentMethodFilter,
        paymentStatus: _paymentStatusFilter,
        service: _serviceFilter,
        machineType: _machineTypeFilter,
        searchQuery: _searchController.text,
      );

  List<RefundRequest> get _filteredRefunds {
    final orderIds = _filteredTransactions.map((item) => item.order.id).toSet();
    return _refundRequests
        .where((item) => orderIds.contains(item.orderId))
        .toList();
  }

  RevenueSummary get _summary => RevenueReportingService.buildSummary(
        transactions: _filteredTransactions,
        refundRequests: _filteredRefunds,
      );

  double get _openingCash =>
      double.tryParse(_openingCashController.text.trim()) ?? 0;

  double get _countedCash =>
      double.tryParse(_countedCashController.text.trim()) ?? 0;

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: _rangeStart,
        end: _rangeEnd.subtract(const Duration(days: 1)),
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _rangePreset = 'CUSTOM';
      _rangeStart = _startOfDay(picked.start);
      _rangeEnd = _startOfDay(picked.end).add(const Duration(days: 1));
    });
  }

  void _applyRangePreset(String preset) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    setState(() {
      _rangePreset = preset;
      switch (preset) {
        case 'TODAY':
          _rangeStart = today;
          _rangeEnd = today.add(const Duration(days: 1));
          break;
        case 'YESTERDAY':
          _rangeStart = today.subtract(const Duration(days: 1));
          _rangeEnd = today;
          break;
        case 'LAST7':
          _rangeStart = today.subtract(const Duration(days: 6));
          _rangeEnd = today.add(const Duration(days: 1));
          break;
        default:
          break;
      }
    });
  }

  Future<void> _pickDayEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dayEndDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _dayEndDate = _startOfDay(picked);
    });
  }

  Future<void> _printRevenueReport() async {
    setState(() {
      _printingReport = true;
    });
    try {
      final bytes = await RevenueReportService.buildRevenueReportPdf(
        summary: _summary,
        transactions: _filteredTransactions,
        rangeStart: _rangeStart,
        rangeEnd: _rangeEnd,
        filters: {
          'Payment': _paymentMethodFilter,
          'Status': _paymentStatusFilter,
          'Service': _serviceFilter,
          'Machine': _machineTypeFilter,
          'Search': _searchController.text.trim(),
        },
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'washpos-revenue-report',
      );
    } finally {
      if (mounted) {
        setState(() {
          _printingReport = false;
        });
      }
    }
  }

  Future<void> _printDayEndCheckout(DayEndCheckout checkout) async {
    final bytes = await RevenueReportService.buildDayEndCheckoutPdf(checkout);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'washpos-day-end-${checkout.id}',
    );
  }

  Future<void> _submitDayEndCheckout() async {
    setState(() {
      _submittingDayEnd = true;
    });
    try {
      final checkout = await widget.repository.createDayEndCheckout(
        businessDate: _dayEndDate,
        openingCash: _openingCash,
        closingCashCounted: _countedCash,
        notes: _notesController.text,
        closedByName: widget.user.displayName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Day-end checkout for ${_dateFormat.format(_dayEndDate)} saved with variance INR ${checkout.cashVariance.toStringAsFixed(0)}.',
          ),
        ),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _submittingDayEnd = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final filteredTransactions = _filteredTransactions;
    final dayEndPreview = RevenueReportingService.buildDayEndCheckout(
      id: 0,
      businessDate: _dayEndDate,
      openingCash: _openingCash,
      closingCashCounted: _countedCash,
      notes: _notesController.text,
      closedByName: widget.user.displayName,
      history: _history,
      refundRequests: _refundRequests,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue & Day End'),
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
                _buildHero(summary),
                const SizedBox(height: 20),
                _buildFilters(),
                const SizedBox(height: 20),
                _buildSummaryCards(summary),
                const SizedBox(height: 20),
                _buildBreakdowns(summary),
                const SizedBox(height: 20),
                _buildTransactions(filteredTransactions),
                const SizedBox(height: 20),
                _buildDayEndSection(dayEndPreview),
                const SizedBox(height: 20),
                _buildRecentCheckouts(),
              ],
            ),
    );
  }

  Widget _buildHero(RevenueSummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C6E7D), Color(0xFF119AB0)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260C6E7D),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue Command Center',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Slice revenue by date, payment method, service, and machine type, then print a clean report or close the day with drawer reconciliation.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroPill(
                  label: 'Net Revenue',
                  value: 'INR ${summary.netRevenue.toStringAsFixed(0)}'),
              _HeroPill(
                  label: 'Transactions', value: '${summary.transactionCount}'),
              _HeroPill(
                  label: 'Pending Refunds',
                  value: '${summary.pendingRefundCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
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
                    'Revenue Segregation Filters',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _printingReport ? null : _printRevenueReport,
                  icon: const Icon(Icons.print_outlined),
                  label:
                      Text(_printingReport ? 'Preparing...' : 'Print Report'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RangeChip(
                  label: 'Today',
                  selected: _rangePreset == 'TODAY',
                  onSelected: () => _applyRangePreset('TODAY'),
                ),
                _RangeChip(
                  label: 'Yesterday',
                  selected: _rangePreset == 'YESTERDAY',
                  onSelected: () => _applyRangePreset('YESTERDAY'),
                ),
                _RangeChip(
                  label: 'Last 7 Days',
                  selected: _rangePreset == 'LAST7',
                  onSelected: () => _applyRangePreset('LAST7'),
                ),
                _RangeChip(
                  label: 'Custom Range',
                  selected: _rangePreset == 'CUSTOM',
                  onSelected: _pickCustomRange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FilterDropdown(
                  label: 'Payment',
                  value: _paymentMethodFilter,
                  values: const [
                    'ALL',
                    'Cash',
                    'Card',
                    'UPI QR',
                    'Counter Booking'
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentMethodFilter = value),
                ),
                _FilterDropdown(
                  label: 'Status',
                  value: _paymentStatusFilter,
                  values: const [
                    'ALL',
                    PaymentStatus.paid,
                    PaymentStatus.refunded
                  ],
                  onChanged: (value) =>
                      setState(() => _paymentStatusFilter = value),
                ),
                _FilterDropdown(
                  label: 'Service',
                  value: _serviceFilter,
                  values: const [
                    'ALL',
                    LaundryService.washing,
                    LaundryService.drying,
                    LaundryService.ironing,
                  ],
                  onChanged: (value) => setState(() => _serviceFilter = value),
                ),
                _FilterDropdown(
                  label: 'Machine Type',
                  value: _machineTypeFilter,
                  values: const [
                    'ALL',
                    Machine.washerType,
                    Machine.dryerType,
                    Machine.ironingStationType,
                  ],
                  onChanged: (value) =>
                      setState(() => _machineTypeFilter = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText:
                    'Search by customer, machine, payment reference, or payment method',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Active range: ${_dateFormat.format(_rangeStart)} to ${_dateFormat.format(_rangeEnd.subtract(const Duration(milliseconds: 1)))}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526777),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(RevenueSummary summary) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
            label: 'Gross Revenue',
            value: 'INR ${summary.grossRevenue.toStringAsFixed(0)}',
            tone: const Color(0xFF0E7490)),
        _MetricCard(
            label: 'Refunded',
            value: 'INR ${summary.refundedRevenue.toStringAsFixed(0)}',
            tone: const Color(0xFFB42318)),
        _MetricCard(
            label: 'Net Revenue',
            value: 'INR ${summary.netRevenue.toStringAsFixed(0)}',
            tone: const Color(0xFF2A9D8F)),
        _MetricCard(
            label: 'Average Ticket',
            value: 'INR ${summary.averageTicket.toStringAsFixed(0)}',
            tone: const Color(0xFF7C3AED)),
        _MetricCard(
            label: 'Cash Net',
            value: 'INR ${summary.cashNet.toStringAsFixed(0)}',
            tone: const Color(0xFFD97706)),
        _MetricCard(
            label: 'Digital Net',
            value:
                'INR ${(summary.cardNet + summary.upiNet + summary.otherNet).toStringAsFixed(0)}',
            tone: const Color(0xFF1D4ED8)),
      ],
    );
  }

  Widget _buildBreakdowns(RevenueSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = constraints.maxWidth < 980;
        final children = [
          _BreakdownCard(title: 'Payment Mix', items: summary.paymentBreakdown),
          _BreakdownCard(title: 'Service Mix', items: summary.serviceBreakdown),
          _BreakdownCard(
              title: 'Machine Type Mix', items: summary.machineTypeBreakdown),
          _BreakdownCard(
              title: 'Top Machines', items: summary.topMachineBreakdown),
        ];
        if (useSingleColumn) {
          return Column(
            children: children
                .map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: child,
                    ))
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTransactions(List<OrderHistoryItem> transactions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Pullout',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Filtered transactions are ready for audit review and printable reporting.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526777),
                  ),
            ),
            const SizedBox(height: 14),
            if (transactions.isEmpty)
              const Text('No transactions match the current revenue filters.')
            else
              ...transactions.take(20).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                                '${item.customer.fullName} • ${item.machine.name}'),
                            Text(item.order.paymentReference),
                            Text(item.order.paymentMethod),
                            Text(item.order.paymentStatus),
                            Text('INR ${item.order.amount.toStringAsFixed(0)}'),
                            Text(_dateTimeFormat.format(item.order.timestamp)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayEndSection(DayEndCheckout preview) {
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
                    'Day-End Checkout',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDayEndDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_dateFormat.format(_dayEndDate)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reconcile the drawer, store notes, and lock in a printable closeout snapshot for the selected business day.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526777),
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CashInput(
                  controller: _openingCashController,
                  label: 'Opening Cash',
                  onChanged: (_) => setState(() {}),
                ),
                _CashInput(
                  controller: _countedCashController,
                  label: 'Counted Drawer Cash',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              onChanged: (_) => setState(() {}),
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Manager notes',
                hintText:
                    'Shift handover note, variance reason, pending follow-up, or cash movement explanation.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Expected Drawer',
                  value: 'INR ${preview.expectedDrawerCash.toStringAsFixed(0)}',
                  tone: const Color(0xFFD97706),
                ),
                _MetricCard(
                  label: 'Variance',
                  value: 'INR ${preview.cashVariance.toStringAsFixed(0)}',
                  tone: preview.cashVariance == 0
                      ? const Color(0xFF2A9D8F)
                      : const Color(0xFFB42318),
                ),
                _MetricCard(
                  label: 'Pending Refund Exposure',
                  value:
                      'INR ${preview.pendingRefundAmount.toStringAsFixed(0)}',
                  tone: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submittingDayEnd ? null : _submitDayEndCheckout,
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: Text(
                _submittingDayEnd
                    ? 'Closing Day...'
                    : 'Complete Day-End Checkout',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCheckouts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Day-End Closures',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_checkouts.isEmpty)
              const Text('No day-end checkout has been recorded yet.')
            else
              ..._checkouts.map(
                (checkout) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _dateFormat.format(checkout.businessDate),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _printDayEndCheckout(checkout),
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Print'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                                'Net: INR ${checkout.netRevenue.toStringAsFixed(0)}'),
                            Text(
                                'Cash: INR ${checkout.cashNet.toStringAsFixed(0)}'),
                            Text(
                                'Variance: INR ${checkout.cashVariance.toStringAsFixed(0)}'),
                            Text('Closed by: ${checkout.closedByName}'),
                            Text(_dateTimeFormat.format(checkout.closedAt)),
                          ],
                        ),
                        if ((checkout.notes ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Notes: ${checkout.notes!}'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<RevenueBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text(
                  'No revenue data in this segment for the current filters.')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.label)),
                      Text('${item.orderCount} orders'),
                      const SizedBox(width: 12),
                      Text(
                        'INR ${item.amount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
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

class _CashInput extends StatelessWidget {
  const _CashInput({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'INR ',
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (selected) {
          if (selected != null) {
            onChanged(selected);
          }
        },
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
