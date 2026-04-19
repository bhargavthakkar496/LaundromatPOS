import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/demo_settings.dart';
import '../data/pos_repository.dart';
import '../models/machine.dart';
import '../models/pos_user.dart';
import '../services/open_external_url.dart';
import '../services/whatsapp_notification_service.dart';
import '../widgets/machine_icon.dart';
import 'checkout_screen.dart';

class MachineOverviewScreen extends StatefulWidget {
  const MachineOverviewScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.onLogout,
  });

  final PosRepository repository;
  final PosUser user;
  final Future<void> Function() onLogout;

  @override
  State<MachineOverviewScreen> createState() => _MachineOverviewScreenState();
}

class _MachineOverviewScreenState extends State<MachineOverviewScreen> {
  static const List<String> _machineCategories = [
    Machine.washerType,
    Machine.dryerType,
    Machine.ironingStationType,
  ];
  static const String _allStatusFilter = 'ALL';

  Timer? _refreshTimer;
  Timer? _tickerTimer;
  final Map<int, String> _lastKnownStatusByMachineId = {};
  final Set<int> _autoNotifiedCompletionOrderIds = <int>{};
  final TextEditingController _searchController = TextEditingController();

  List<Machine> _machines = const [];
  String _selectedCategory = Machine.washerType;
  String _selectedStatus = _allStatusFilter;
  bool _loading = true;
  bool _syncing = false;
  bool _requestInFlight = false;
  String? _errorMessage;
  DateTime _now = DateTime.now();
  DateTime? _lastUpdatedAt;

  @override
  void initState() {
    super.initState();
    _loadMachines();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) {
        return;
      }
      _loadMachines(showLoading: false);
    });
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickerTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout(Machine machine) async {
    if (!machine.isAvailable) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutScreen(
          repository: widget.repository,
          user: widget.user,
          machine: machine,
          onLogout: widget.onLogout,
        ),
      ),
    );
    _loadMachines(showLoading: false);
  }

  Future<void> _markPickedUp(Machine machine) async {
    await widget.repository.markMachinePickedUp(machine.id);
    if (!mounted) {
      return;
    }
    _loadMachines(showLoading: false);
  }

  Future<void> _showMachineDetails(Machine machine) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final statusColor = _statusColor(machine, context);
        final detailActions = _buildActionButtons(context, machine);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.84,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ListView(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MachineIcon(machine: machine, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              machine.name,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
                              style: Theme.of(sheetContext).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      _MachineStatusBadge(
                        label: _statusLabel(machine),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusDetail(machine),
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  if (_cycleProgress(machine) != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: _cycleProgress(machine),
                        backgroundColor: statusColor.withValues(alpha: 0.14),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MachineMetaPill(
                        label: 'Machine ID',
                        value: '#${machine.id}',
                      ),
                      _MachineMetaPill(
                        label: 'Cycle Duration',
                        value: _formatDuration(machine.cycleDuration),
                      ),
                      if (machine.isInUse)
                        _MachineMetaPill(
                          label: 'Remaining',
                          value: _formatDuration(
                            _remainingCycleDuration(machine) ?? Duration.zero,
                          ),
                        ),
                      if (machine.cycleStartedAt != null)
                        _MachineMetaPill(
                          label: 'Started At',
                          value: DateFormat('dd MMM, hh:mm a').format(
                            machine.cycleStartedAt!.toLocal(),
                          ),
                        ),
                      if (machine.cycleEndsAt != null)
                        _MachineMetaPill(
                          label: 'Ends At',
                          value: DateFormat('dd MMM, hh:mm a').format(
                            machine.cycleEndsAt!.toLocal(),
                          ),
                        ),
                      if (machine.currentOrderId != null)
                        _MachineMetaPill(
                          label: 'Current Order',
                          value: '#${machine.currentOrderId}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operational Notes',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          machine.isReadyForPickup
                              ? 'This machine is blocking floor throughput until the order is picked up or the customer is notified.'
                              : machine.isInUse
                                  ? 'The cycle is live. Use the delay notice if the customer needs an updated completion time.'
                                  : machine.status == MachineStatus.maintenance
                                      ? 'This machine is currently unavailable for new bookings. Leave it visible here so operators see lost capacity immediately.'
                                      : machine.isIroningStation
                                          ? 'Ironing stations remain visible for counter-assisted service without forcing a full checkout from this screen.'
                                          : 'This machine is available and can be launched directly into checkout.',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quick Actions',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: detailActions,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadMachines({bool showLoading = true}) async {
    if (_requestInFlight) {
      return;
    }
    _requestInFlight = true;

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() {
        _syncing = true;
      });
    }

    try {
      final machines = await widget.repository.getMachines();
      await _handleAutomaticCompletionNotifications(machines);
      for (final machine in machines) {
        _lastKnownStatusByMachineId[machine.id] = machine.status;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _machines = machines;
        if (!_availableCategories.contains(_selectedCategory) &&
            _availableCategories.isNotEmpty) {
          _selectedCategory = _availableCategories.first;
        }
        _loading = false;
        _syncing = false;
        _errorMessage = null;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _syncing = false;
        _errorMessage = _machines.isEmpty
            ? 'Could not load machine data right now.'
            : 'Live machine sync failed. Showing the last known machine state.';
      });
    } finally {
      _requestInFlight = false;
    }
  }

  List<String> get _availableCategories {
    final available = _machineCategories
        .where(
          (category) => _machines.any(
            (machine) => machine.type.toLowerCase() == category.toLowerCase(),
          ),
        )
        .toList();
    return available;
  }

  List<Machine> get _visibleMachines {
    final query = _searchController.text.trim().toLowerCase();
    final visible = _machines
        .where(
      (machine) =>
          machine.type.toLowerCase() == _selectedCategory.toLowerCase(),
    )
        .where((machine) {
      if (_selectedStatus == _allStatusFilter) {
        return true;
      }
      return machine.status == _selectedStatus;
    }).where((machine) {
      if (query.isEmpty) {
        return true;
      }
      return machine.name.toLowerCase().contains(query) ||
          machine.type.toLowerCase().contains(query) ||
          machine.status.toLowerCase().contains(query);
    }).toList();

    visible.sort((left, right) {
      final priorityCompare = _statusPriority(left).compareTo(
        _statusPriority(right),
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      if (left.isInUse && right.isInUse) {
        final leftEndsAt = left.cycleEndsAt;
        final rightEndsAt = right.cycleEndsAt;
        if (leftEndsAt != null && rightEndsAt != null) {
          return leftEndsAt.compareTo(rightEndsAt);
        }
      }
      return left.name.compareTo(right.name);
    });

    return visible;
  }

  List<Machine> get _readyMachines =>
      _visibleMachines.where((machine) => machine.isReadyForPickup).toList();

  List<Machine> get _mainListMachines {
    if (_selectedStatus != _allStatusFilter) {
      return _visibleMachines;
    }
    return _visibleMachines
        .where((machine) => !machine.isReadyForPickup)
        .toList();
  }

  Machine? get _nextReadyMachine {
    final activeMachines = _machines
        .where((machine) => machine.isInUse && machine.cycleEndsAt != null)
        .toList()
      ..sort(
        (left, right) => left.cycleEndsAt!.compareTo(right.cycleEndsAt!),
      );
    return activeMachines.isEmpty ? null : activeMachines.first;
  }

  int get _availableCount =>
      _machines.where((machine) => machine.isAvailable).length;

  int get _inUseCount => _machines.where((machine) => machine.isInUse).length;

  int get _readyCount =>
      _machines.where((machine) => machine.isReadyForPickup).length;

  int get _maintenanceCount => _machines
      .where((machine) => machine.status == MachineStatus.maintenance)
      .length;

  Future<void> _handleAutomaticCompletionNotifications(
    List<Machine> machines,
  ) async {
    if (!DemoSettings.autoOpenWhatsAppNotifications) {
      return;
    }

    for (final machine in machines) {
      final previousStatus = _lastKnownStatusByMachineId[machine.id];
      final orderId = machine.currentOrderId;
      final becameReady = previousStatus == MachineStatus.inUse &&
          machine.status == MachineStatus.readyForPickup;
      if (!becameReady || orderId == null) {
        continue;
      }
      if (_autoNotifiedCompletionOrderIds.contains(orderId)) {
        continue;
      }
      _autoNotifiedCompletionOrderIds.add(orderId);
      await _sendCycleCompletedNotification(machine);
    }
  }

  Future<void> _sendCycleCompletedNotification(Machine machine) async {
    final orderId = machine.currentOrderId;
    if (orderId == null) {
      return;
    }
    final item = await widget.repository.getOrderHistoryItemByOrderId(orderId);
    if (item == null) {
      return;
    }
    final phone =
        WhatsAppNotificationService.normalizePhone(item.customer.phone);
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildCycleCompletedMessage(item),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp for cycle completion.'),
        ),
      );
    }
  }

  Future<void> _sendMachineDelayNotification(Machine machine) async {
    final orderId = machine.currentOrderId;
    if (orderId == null) {
      return;
    }
    final item = await widget.repository.getOrderHistoryItemByOrderId(orderId);
    if (item == null) {
      return;
    }
    final phone =
        WhatsAppNotificationService.normalizePhone(item.customer.phone);
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildMachineDelayMessage(item),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp for machine delay.'),
        ),
      );
    }
  }

  String _statusLabel(Machine machine) {
    if (machine.isInUse) {
      return 'Cycle running';
    }
    if (machine.isReadyForPickup) {
      return 'Ready for pickup';
    }
    if (machine.status == MachineStatus.maintenance) {
      return 'Maintenance';
    }
    return 'Available';
  }

  Color _statusColor(Machine machine, BuildContext context) {
    if (machine.isInUse) {
      return const Color(0xFFC86B3C);
    }
    if (machine.isReadyForPickup) {
      return const Color(0xFF2A9D8F);
    }
    if (machine.status == MachineStatus.maintenance) {
      return Theme.of(context).colorScheme.error;
    }
    return const Color(0xFF0E7490);
  }

  int _statusPriority(Machine machine) {
    if (machine.isReadyForPickup) {
      return 0;
    }
    if (machine.isInUse) {
      return 1;
    }
    if (machine.isAvailable) {
      return 2;
    }
    if (machine.status == MachineStatus.maintenance) {
      return 3;
    }
    return 4;
  }

  String _statusDetail(Machine machine) {
    if (machine.isInUse) {
      final remaining = _remainingCycleDuration(machine);
      final eta = machine.cycleEndsAt == null
          ? 'ETA unavailable'
          : 'ETA ${DateFormat('hh:mm a').format(machine.cycleEndsAt!.toLocal())}';
      if (remaining == null) {
        return eta;
      }
      return '${_formatDuration(remaining)} left • $eta';
    }
    if (machine.isReadyForPickup) {
      return machine.currentOrderId == null
          ? 'Cycle completed and waiting on collection.'
          : 'Order #${machine.currentOrderId} is still waiting on pickup.';
    }
    if (machine.status == MachineStatus.maintenance) {
      return 'Machine is blocked from new orders until it is restored.';
    }
    if (machine.isIroningStation) {
      return 'Available for counter-assisted ironing orders.';
    }
    return 'Open for a new order right now.';
  }

  Duration? _remainingCycleDuration(Machine machine) {
    if (machine.cycleEndsAt == null) {
      return null;
    }
    final remaining = machine.cycleEndsAt!.difference(_now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  double? _cycleProgress(Machine machine) {
    if (machine.cycleStartedAt == null || machine.cycleEndsAt == null) {
      return null;
    }
    final total = machine.cycleEndsAt!.difference(machine.cycleStartedAt!);
    if (total.inMilliseconds <= 0) {
      return null;
    }
    final elapsed = _now.difference(machine.cycleStartedAt!);
    final rawProgress = elapsed.inMilliseconds / total.inMilliseconds;
    return rawProgress.clamp(0.0, 1.0);
  }

  Widget _buildStatusChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedStatus == value,
      onSelected: (_) {
        setState(() {
          _selectedStatus = value;
        });
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, Machine? nextReadyMachine) {
    final summaryText = nextReadyMachine == null
        ? 'No active cycles are currently counting down in this category.'
        : '${nextReadyMachine.name} is the next machine due to finish in ${_formatDuration(_remainingCycleDuration(nextReadyMachine) ?? Duration.zero)}.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF1AA0B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220E7490),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Machine Floor',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Track machine readiness, active cycles, and blocked capacity from one operator view.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  summaryText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetricPill(label: 'Category', value: _selectedCategory),
              _HeroMetricPill(
                label: 'Visible',
                value: '${_visibleMachines.length}',
              ),
              _HeroMetricPill(
                label: 'Last Sync',
                value: _lastUpdatedAt == null
                    ? 'Pending'
                    : DateFormat('hh:mm a').format(_lastUpdatedAt!.toLocal()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(BuildContext context, int visibleCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_outlined),
                hintText: 'Search machines by name, type, or status',
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Machine Type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableCategories
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Machine Status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildStatusChip('All', _allStatusFilter),
                _buildStatusChip('Ready', MachineStatus.readyForPickup),
                _buildStatusChip('Running', MachineStatus.inUse),
                _buildStatusChip('Available', MachineStatus.available),
                _buildStatusChip('Maintenance', MachineStatus.maintenance),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '$visibleCount machine${visibleCount == 1 ? '' : 's'} match the current view.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B6475),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.local_laundry_service_outlined, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context, Machine machine) {
    if (machine.isAvailable) {
      if (machine.isIroningStation) {
        return [
          FilledButton.tonal(
            onPressed: null,
            child: const Text('Counter Service'),
          ),
        ];
      }
      return [
        FilledButton.icon(
          onPressed: () => _startCheckout(machine),
          icon: const Icon(Icons.play_arrow_outlined),
          label: const Text('Start Order'),
        ),
      ];
    }

    if (machine.isInUse) {
      return [
        FilledButton.tonalIcon(
          onPressed: () => _sendMachineDelayNotification(machine),
          icon: const Icon(Icons.schedule_send_outlined),
          label: const Text('Send Delay Notice'),
        ),
      ];
    }

    if (machine.isReadyForPickup) {
      return [
        FilledButton.icon(
          onPressed: () => _markPickedUp(machine),
          icon: const Icon(Icons.task_alt_outlined),
          label: const Text('Mark Picked Up'),
        ),
        OutlinedButton.icon(
          onPressed: () => _sendCycleCompletedNotification(machine),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Send Completion Notice'),
        ),
      ];
    }

    return [
      FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.build_outlined),
        label: const Text('Under Maintenance'),
      ),
    ];
  }

  Widget _buildMachineCard(
    BuildContext context,
    Machine machine, {
    bool emphasize = false,
  }) {
    final statusColor = _statusColor(machine, context);
    final progress = _cycleProgress(machine);

    return Card(
      elevation: emphasize ? 1.5 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: emphasize
              ? statusColor.withValues(alpha: 0.65)
              : const Color(0xFFE0EAF0),
          width: emphasize ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showMachineDetails(machine),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MachineIcon(machine: machine, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          machine.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MachineStatusBadge(
                        label: _statusLabel(machine),
                        color: statusColor,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _showMachineDetails(machine),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _statusDetail(machine),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF324B5B),
                    ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progress,
                    backgroundColor: statusColor.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MachineMetaPill(
                    label: 'Capacity',
                    value: '${machine.capacityKg}kg',
                  ),
                  _MachineMetaPill(
                    label: 'Price',
                    value: 'INR ${machine.price.toStringAsFixed(0)}',
                  ),
                  if (machine.isInUse)
                    _MachineMetaPill(
                      label: 'Time Remaining',
                      value: _formatDuration(
                        _remainingCycleDuration(machine) ?? Duration.zero,
                      ),
                    ),
                  if (machine.cycleEndsAt != null)
                    _MachineMetaPill(
                      label: 'Ends At',
                      value: DateFormat('hh:mm a').format(
                        machine.cycleEndsAt!.toLocal(),
                      ),
                    ),
                  if (machine.currentOrderId != null)
                    _MachineMetaPill(
                      label: 'Current Order',
                      value: '#${machine.currentOrderId}',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _buildActionButtons(context, machine),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMachineSection(
    BuildContext context, {
    required List<Machine> machines,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useGrid = width >= 920;
        if (!useGrid) {
          return Column(
            children: machines
                .map(
                  (machine) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMachineCard(context, machine),
                  ),
                )
                .toList(),
          );
        }

        final columns = width >= 1380 ? 3 : 2;
        const spacing = 12.0;
        final cardWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: machines
              .map(
                (machine) => SizedBox(
                  width: cardWidth,
                  child: _buildMachineCard(context, machine),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _handleRefresh() => _loadMachines(showLoading: false);

  @override
  Widget build(BuildContext context) {
    final visibleMachines = _visibleMachines;
    final readyMachines = _readyMachines;
    final mainListMachines = _mainListMachines;
    final nextReadyMachine = _nextReadyMachine;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Machine Overview')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Overview'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh machines',
            onPressed: _syncing ? null : _handleRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _buildHeroCard(context, nextReadyMachine),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MachineSummaryCard(
                  label: 'Available',
                  value: '$_availableCount',
                  accent: const Color(0xFF0E7490),
                ),
                _MachineSummaryCard(
                  label: 'In Use',
                  value: '$_inUseCount',
                  accent: const Color(0xFFC86B3C),
                ),
                _MachineSummaryCard(
                  label: 'Ready',
                  value: '$_readyCount',
                  accent: const Color(0xFF2A9D8F),
                ),
                _MachineSummaryCard(
                  label: 'Maintenance',
                  value: '$_maintenanceCount',
                  accent: Theme.of(context).colorScheme.error,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildFilterPanel(context, visibleMachines.length),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(context),
            ],
            if (_machines.isEmpty) ...[
              const SizedBox(height: 24),
              _buildEmptyState(
                context,
                title: 'No machines found',
                message:
                    'Machine data has not been configured yet for this location.',
              ),
            ] else if (visibleMachines.isEmpty) ...[
              const SizedBox(height: 24),
              _buildEmptyState(
                context,
                title: 'No machines match these filters',
                message:
                    'Try a different category, status, or search term to widen the overview.',
              ),
            ] else ...[
              if (_selectedStatus == _allStatusFilter &&
                  readyMachines.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Needs Pickup Now',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed cycles are surfaced first so the operator can clear the floor quickly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4B6475),
                      ),
                ),
                const SizedBox(height: 14),
                _buildMachineSection(
                  context,
                  machines: readyMachines
                      .map(
                        (machine) => machine,
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                _selectedStatus == MachineStatus.readyForPickup
                    ? 'Pickup Queue'
                    : 'Machine Queue',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Machines are sorted by urgency, then by upcoming cycle completion time.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4B6475),
                    ),
              ),
              const SizedBox(height: 14),
              _buildMachineSection(
                context,
                machines: mainListMachines,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MachineSummaryCard extends StatelessWidget {
  const _MachineSummaryCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HeroMetricPill extends StatelessWidget {
  const _HeroMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MachineStatusBadge extends StatelessWidget {
  const _MachineStatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MachineMetaPill extends StatelessWidget {
  const _MachineMetaPill({
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
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
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
