import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/staff.dart';
import '../services/currency_formatter.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({
    super.key,
    required this.repository,
    required this.managerName,
  });

  final PosRepository repository;
  final String managerName;

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  List<StaffMember> _staffMembers = const [];
  List<StaffShift> _staffShifts = const [];
  List<StaffLeaveRequest> _leaveRequests = const [];
  List<StaffPayout> _payouts = const [];
  DateTime _rosterWeekStart = _startOfWeek(DateTime.now());
  bool _loading = true;
  int? _updatingLeaveId;
  int? _markingPayoutId;
  bool _savingShift = false;
  bool _creatingPayout = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    final start = _rosterWeekStart;
    final end = start.add(const Duration(days: 7));
    final results = await Future.wait([
      widget.repository.getStaffMembers(),
      widget.repository.getStaffShifts(start: start, end: end),
      widget.repository.getStaffLeaveRequests(),
      widget.repository.getStaffPayouts(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _staffMembers = results[0] as List<StaffMember>;
      _staffShifts = results[1] as List<StaffShift>;
      _leaveRequests = results[2] as List<StaffLeaveRequest>;
      _payouts = results[3] as List<StaffPayout>;
      _loading = false;
    });
  }

  Future<void> _changeWeek(int offsetDays) async {
    setState(() {
      _rosterWeekStart = _rosterWeekStart.add(Duration(days: offsetDays));
    });
    await _loadData(showLoading: false);
  }

  Future<void> _openShiftComposer() async {
    if (_staffMembers.isEmpty) {
      return;
    }
    var selectedStaffId = _staffMembers.first.id;
    var selectedDate = _rosterWeekStart;
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '17:00');
    final branchController = TextEditingController(text: 'Main Branch');
    final assignmentController = TextEditingController();
    final hoursController = TextEditingController(text: '8');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Roster Shift'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedStaffId,
                      decoration: const InputDecoration(labelText: 'Staff'),
                      items: _staffMembers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.fullName} • ${item.role}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStaffId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Shift Date'),
                      subtitle: Text(_dateFormat.format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: startController,
                      decoration: const InputDecoration(labelText: 'Start'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: endController,
                      decoration: const InputDecoration(labelText: 'End'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: branchController,
                      decoration: const InputDecoration(labelText: 'Branch'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: assignmentController,
                      decoration:
                          const InputDecoration(labelText: 'Assignment'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Hours'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save Shift'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      startController.dispose();
      endController.dispose();
      branchController.dispose();
      assignmentController.dispose();
      hoursController.dispose();
      return;
    }

    setState(() => _savingShift = true);
    try {
      await widget.repository.saveStaffShift(
        staffId: selectedStaffId,
        shiftDate: selectedDate,
        startTimeLabel: startController.text.trim(),
        endTimeLabel: endController.text.trim(),
        branch: branchController.text.trim(),
        assignment: assignmentController.text.trim(),
        hours: double.tryParse(hoursController.text.trim()) ?? 8,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Roster shift added to the week plan.')),
      );
      await _loadData(showLoading: false);
    } finally {
      startController.dispose();
      endController.dispose();
      branchController.dispose();
      assignmentController.dispose();
      hoursController.dispose();
      if (mounted) {
        setState(() => _savingShift = false);
      }
    }
  }

  Future<void> _reviewLeave(StaffLeaveRequest request, String status) async {
    setState(() => _updatingLeaveId = request.id);
    try {
      await widget.repository.updateStaffLeaveRequestStatus(
        leaveRequestId: request.id,
        status: status,
        reviewedByName: widget.managerName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Leave request ${request.id} updated to $status.')),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() => _updatingLeaveId = null);
      }
    }
  }

  Future<void> _openPayoutComposer() async {
    if (_staffMembers.isEmpty) {
      return;
    }
    var selectedStaffId = _staffMembers.first.id;
    final periodController = TextEditingController(text: '16 Apr - 30 Apr');
    final hoursController = TextEditingController(text: '96');
    final bonusController = TextEditingController(text: '0');
    final deductionsController = TextEditingController(text: '0');

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Prepare Staff Payout'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedStaffId,
                      decoration: const InputDecoration(labelText: 'Staff'),
                      items: _staffMembers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text('${item.fullName} • ${item.role}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedStaffId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: periodController,
                      decoration:
                          const InputDecoration(labelText: 'Pay Period'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Hours Worked'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bonusController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Bonus Amount'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deductionsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Deductions'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create Payout'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      periodController.dispose();
      hoursController.dispose();
      bonusController.dispose();
      deductionsController.dispose();
      return;
    }

    setState(() => _creatingPayout = true);
    try {
      await widget.repository.createStaffPayout(
        staffId: selectedStaffId,
        periodLabel: periodController.text.trim(),
        hoursWorked: double.tryParse(hoursController.text.trim()) ?? 0,
        bonusAmount: double.tryParse(bonusController.text.trim()) ?? 0,
        deductionsAmount:
            double.tryParse(deductionsController.text.trim()) ?? 0,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff payout prepared successfully.')),
      );
      await _loadData(showLoading: false);
    } finally {
      periodController.dispose();
      hoursController.dispose();
      bonusController.dispose();
      deductionsController.dispose();
      if (mounted) {
        setState(() => _creatingPayout = false);
      }
    }
  }

  Future<void> _markPayoutPaid(StaffPayout payout) async {
    setState(() => _markingPayoutId = payout.id);
    try {
      await widget.repository.markStaffPayoutPaid(payoutId: payout.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${payout.staffName} payout marked paid.')),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() => _markingPayoutId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingLeaves = _leaveRequests
        .where((item) => item.status == StaffLeaveStatus.pending)
        .length;
    final scheduledPayoutTotal = _payouts
        .where((item) => item.status == StaffPayoutStatus.scheduled)
        .fold<double>(0, (sum, item) => sum + item.netAmount);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.staff),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Roster'),
              Tab(text: 'Leave'),
              Tab(text: 'Payout'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF136C84), Color(0xFF1C9AB0)],
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Staff Control Desk',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Plan the weekly roster, review leave exposure, and settle payroll from one manager-facing workspace.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _StaffMetricPill(
                              label: 'Active Staff',
                              value:
                                  '${_staffMembers.where((item) => item.isActive).length}',
                            ),
                            _StaffMetricPill(
                              label: 'Pending Leaves',
                              value: '$pendingLeaves',
                            ),
                            _StaffMetricPill(
                              label: 'Scheduled Payouts',
                              value:
                                  CurrencyFormatter.formatAmountForContext(
                                    context,
                                    scheduledPayoutTotal,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRosterTab(),
                        _buildLeaveTab(),
                        _buildPayoutTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRosterTab() {
    final shiftsByStaff = <int, List<StaffShift>>{};
    for (final shift in _staffShifts) {
      shiftsByStaff.putIfAbsent(shift.staffId, () => []).add(shift);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeWeek(-7),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Roster Week: ${_dateFormat.format(_rosterWeekStart)} - ${_dateFormat.format(_rosterWeekStart.add(const Duration(days: 6)))}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeWeek(7),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _savingShift ? null : _openShiftComposer,
                  icon: const Icon(Icons.add_task_outlined),
                  label: Text(_savingShift ? 'Saving...' : 'Add Shift'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._staffMembers.map((staff) {
          final shifts = shiftsByStaff[staff.id] ?? const [];
          final totalHours =
              shifts.fold<double>(0, (sum, item) => sum + item.hours);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${staff.fullName} • ${staff.role}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text('Weekly Hours: ${totalHours.toStringAsFixed(0)}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (shifts.isEmpty)
                      const Text('No roster entry planned for this week yet.')
                    else
                      ...shifts.map(
                        (shift) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                Text(_dateFormat.format(shift.shiftDate)),
                                Text(
                                    '${shift.startTimeLabel} - ${shift.endTimeLabel}'),
                                Text(shift.branch),
                                Text(shift.assignment),
                                Text('${shift.hours.toStringAsFixed(1)} hrs'),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLeaveTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: _leaveRequests.map((request) {
        final canReview = request.status == StaffLeaveStatus.pending;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${request.staffName} • ${request.leaveType}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusBadge(label: request.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${_dateFormat.format(request.startDate)} - ${_dateFormat.format(request.endDate)}',
                      ),
                      Text('${request.dayCount} day(s)'),
                      Text(
                          'Requested ${_dateFormat.format(request.requestedAt)}'),
                      if (request.reviewedByName != null)
                        Text('Reviewed by ${request.reviewedByName}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(request.reason),
                  if (canReview) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: _updatingLeaveId == request.id
                              ? null
                              : () => _reviewLeave(
                                    request,
                                    StaffLeaveStatus.rejected,
                                  ),
                          child: Text(
                            _updatingLeaveId == request.id
                                ? 'Updating...'
                                : 'Reject',
                          ),
                        ),
                        FilledButton(
                          onPressed: _updatingLeaveId == request.id
                              ? null
                              : () => _reviewLeave(
                                    request,
                                    StaffLeaveStatus.approved,
                                  ),
                          child: Text(
                            _updatingLeaveId == request.id
                                ? 'Updating...'
                                : 'Approve',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPayoutTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Staff Payout Register',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _creatingPayout ? null : _openPayoutComposer,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label:
                      Text(_creatingPayout ? 'Preparing...' : 'Create Payout'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ..._payouts.map((payout) {
          final canMarkPaid = payout.status == StaffPayoutStatus.scheduled;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${payout.staffName} • ${payout.periodLabel}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _StatusBadge(label: payout.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text('Hours: ${payout.hoursWorked.toStringAsFixed(1)}'),
                        Text(
                            'Gross: ${CurrencyFormatter.formatAmountForContext(context, payout.grossAmount)}'),
                        Text(
                            'Bonus: ${CurrencyFormatter.formatAmountForContext(context, payout.bonusAmount)}'),
                        Text(
                            'Deductions: ${CurrencyFormatter.formatAmountForContext(context, payout.deductionsAmount)}'),
                        Text(
                          'Net: ${CurrencyFormatter.formatAmountForContext(context, payout.netAmount)}',
                        ),
                      ],
                    ),
                    if (payout.paidAt != null) ...[
                      const SizedBox(height: 10),
                      Text('Paid on ${_dateFormat.format(payout.paidAt!)}'),
                    ],
                    if (canMarkPaid) ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _markingPayoutId == payout.id
                            ? null
                            : () => _markPayoutPaid(payout),
                        child: Text(
                          _markingPayoutId == payout.id
                              ? 'Updating...'
                              : 'Mark Paid',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  static DateTime _startOfWeek(DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return start.subtract(Duration(days: start.weekday - 1));
  }
}

class _StaffMetricPill extends StatelessWidget {
  const _StaffMetricPill({
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
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
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      StaffLeaveStatus.approved ||
      StaffPayoutStatus.paid =>
        const Color(0xFF2A9D8F),
      StaffLeaveStatus.rejected => const Color(0xFFB42318),
      _ => const Color(0xFFD97706),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
