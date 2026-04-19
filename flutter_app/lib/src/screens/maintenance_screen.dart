import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../models/maintenance.dart';
import '../models/machine.dart';
import '../models/pos_user.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final PosRepository repository;
  final PosUser user;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM, hh:mm a');

  List<Machine> _machines = const [];
  List<Machine> _eligibleMachines = const [];
  List<MaintenanceRecord> _records = const [];
  bool _loading = true;
  int? _creatingMachineId;
  int? _startingRecordId;
  int? _completingRecordId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    final results = await Future.wait([
      widget.repository.getMachines(),
      widget.repository.getMaintenanceEligibleMachines(),
      widget.repository.getMaintenanceRecords(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _machines = results[0] as List<Machine>;
      _eligibleMachines = results[1] as List<Machine>;
      _records = results[2] as List<MaintenanceRecord>;
      _loading = false;
    });
  }

  Machine? _machineById(int machineId) {
    for (final machine in _machines) {
      if (machine.id == machineId) {
        return machine;
      }
    }
    return null;
  }

  Future<void> _markForMaintenance(Machine machine) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var priority = MaintenancePriority.medium;

    final payload = await showDialog<_MaintenanceDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Mark ${machine.name} For Maintenance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Issue title',
                    hintText:
                        'Motor noise, heat issue, door lock, sensor fault',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Issue description',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: MaintenancePriority.low,
                      child: Text('Low'),
                    ),
                    DropdownMenuItem(
                      value: MaintenancePriority.medium,
                      child: Text('Medium'),
                    ),
                    DropdownMenuItem(
                      value: MaintenancePriority.high,
                      child: Text('High'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      priority = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final issueTitle = titleController.text.trim();
                if (issueTitle.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  _MaintenanceDraft(
                    issueTitle: issueTitle,
                    issueDescription: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    priority: priority,
                  ),
                );
              },
              child: const Text('Mark Device'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();

    if (payload == null) {
      return;
    }

    setState(() {
      _creatingMachineId = machine.id;
    });

    try {
      await widget.repository.createMaintenanceRecord(
        machineId: machine.id,
        issueTitle: payload.issueTitle,
        issueDescription: payload.issueDescription,
        priority: payload.priority,
        reportedByName: widget.user.displayName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${machine.name} moved into maintenance.'),
        ),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _creatingMachineId = null;
        });
      }
    }
  }

  Future<void> _startMaintenance(MaintenanceRecord record) async {
    setState(() {
      _startingRecordId = record.id;
    });
    try {
      await widget.repository.startMaintenanceRecord(
        recordId: record.id,
        startedByName: widget.user.displayName,
      );
      if (!mounted) {
        return;
      }
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _startingRecordId = null;
        });
      }
    }
  }

  Future<void> _completeMaintenance(MaintenanceRecord record) async {
    final controller = TextEditingController();
    final resolution = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Maintenance'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Resolution notes',
            hintText:
                'What was fixed and what was verified before returning this device to service?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Complete & Return'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (resolution == null) {
      return;
    }

    setState(() {
      _completingRecordId = record.id;
    });
    try {
      await widget.repository.completeMaintenanceRecord(
        recordId: record.id,
        completedByName: widget.user.displayName,
        resolutionNotes: resolution,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Maintenance completed and device returned to service.'),
        ),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _completingRecordId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final markedRecords = _records.where((item) => item.isMarked).toList();
    final inProgressRecords =
        _records.where((item) => item.isInProgress).toList();
    final completedRecords =
        _records.where((item) => item.isCompleted).toList();
    final maintenanceMachines = _machines
        .where((machine) => machine.status == MachineStatus.maintenance)
        .length;
    final availableMachines = _machines
        .where((machine) => machine.status == MachineStatus.available)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Desk'),
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
                      colors: [Color(0xFF6B5B95), Color(0xFF8C7AB8)],
                    ),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device Maintenance Workflow',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Mark washers, dryers, and ironing stations for maintenance, push them into ongoing work, then return them to available service once completed.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MaintenanceMetricCard(
                              label: 'Marked',
                              value: '${markedRecords.length}'),
                          _MaintenanceMetricCard(
                              label: 'Ongoing',
                              value: '${inProgressRecords.length}'),
                          _MaintenanceMetricCard(
                              label: 'In Maintenance',
                              value: '$maintenanceMachines'),
                          _MaintenanceMetricCard(
                              label: 'Available', value: '$availableMachines'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildEligibleDevicesSection(),
                const SizedBox(height: 20),
                _buildActiveMaintenanceSection(
                  title: 'Marked For Maintenance',
                  description:
                      'These devices are already blocked from service and waiting for a technician to begin work.',
                  records: markedRecords,
                  buildAction: (record) => FilledButton.tonalIcon(
                    onPressed: _startingRecordId == record.id
                        ? null
                        : () => _startMaintenance(record),
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(
                      _startingRecordId == record.id
                          ? 'Starting...'
                          : 'Start Work',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildActiveMaintenanceSection(
                  title: 'Ongoing Maintenance',
                  description:
                      'These devices remain unavailable while work is in progress. Completing the record returns the device to available status across the app.',
                  records: inProgressRecords,
                  buildAction: (record) => FilledButton.icon(
                    onPressed: _completingRecordId == record.id
                        ? null
                        : () => _completeMaintenance(record),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _completingRecordId == record.id
                          ? 'Completing...'
                          : 'Complete & Return To Service',
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
                          'Maintenance Completed',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed jobs remain here as history, while the device is immediately available again in the rest of the app.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (completedRecords.isEmpty)
                          const Text('No completed maintenance records yet.')
                        else
                          ...completedRecords.take(8).map(
                                (record) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MaintenanceRecordCard(
                                    machine: _machineById(record.machineId),
                                    record: record,
                                    subtitle: record.resolutionNotes,
                                    footer:
                                        'Completed ${record.completedAt == null ? '' : _dateFormat.format(record.completedAt!)}',
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

  Widget _buildEligibleDevicesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Select any currently available washer, dryer, or ironing station and move it into maintenance. The device status changes to maintenance immediately.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_eligibleMachines.isEmpty)
              const Text(
                  'No devices are currently available to mark for maintenance.')
            else
              ..._eligibleMachines.map(
                (machine) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(machine.name),
                      subtitle: Text(
                          '${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}'),
                      trailing: FilledButton.tonalIcon(
                        onPressed: _creatingMachineId == machine.id
                            ? null
                            : () => _markForMaintenance(machine),
                        icon: const Icon(Icons.build_circle_outlined),
                        label: Text(
                          _creatingMachineId == machine.id
                              ? 'Marking...'
                              : 'Mark For Maintenance',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMaintenanceSection({
    required String title,
    required String description,
    required List<MaintenanceRecord> records,
    required Widget Function(MaintenanceRecord record) buildAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Text('Nothing in this stage right now.')
            else
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MaintenanceRecordCard(
                    machine: _machineById(record.machineId),
                    record: record,
                    subtitle: record.issueDescription,
                    footer: record.startedAt == null
                        ? 'Reported ${_dateFormat.format(record.reportedAt)}'
                        : 'Started ${_dateFormat.format(record.startedAt!)}',
                    action: buildAction(record),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceDraft {
  const _MaintenanceDraft({
    required this.issueTitle,
    required this.issueDescription,
    required this.priority,
  });

  final String issueTitle;
  final String? issueDescription;
  final String priority;
}

class _MaintenanceMetricCard extends StatelessWidget {
  const _MaintenanceMetricCard({
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceRecordCard extends StatelessWidget {
  const _MaintenanceRecordCard({
    required this.machine,
    required this.record,
    required this.footer,
    this.subtitle,
    this.action,
  });

  final Machine? machine;
  final MaintenanceRecord record;
  final String footer;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tone = switch (record.status) {
      MaintenanceStatus.marked => const Color(0xFFD97706),
      MaintenanceStatus.inProgress => const Color(0xFF2563EB),
      _ => const Color(0xFF2A9D8F),
    };

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
                    '${machine?.name ?? 'Unknown device'} • ${record.issueTitle}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    record.status,
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
                Text('Type: ${machine?.type ?? 'Unknown'}'),
                Text('Priority: ${record.priority}'),
                Text('Reported by: ${record.reportedByName ?? 'System'}'),
                if (record.startedByName != null)
                  Text('Started by: ${record.startedByName}'),
                if (record.completedByName != null)
                  Text('Completed by: ${record.completedByName}'),
              ],
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(subtitle!),
            ],
            const SizedBox(height: 10),
            Text(
              footer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
