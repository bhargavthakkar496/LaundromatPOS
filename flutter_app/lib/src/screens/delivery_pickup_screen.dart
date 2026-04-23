import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/delivery_task.dart';
import '../models/machine.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/pickup_task.dart';
import '../models/pos_user.dart';
import '../services/open_external_url.dart';
import '../services/whatsapp_notification_service.dart';

enum DeliveryPickupInitialTab { delivery, pickup }

const String _allDeliveryStatuses = 'ALL';

class DeliveryPickupScreen extends StatefulWidget {
  const DeliveryPickupScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.initialTab,
  });

  final PosRepository repository;
  final PosUser user;
  final DeliveryPickupInitialTab initialTab;

  @override
  State<DeliveryPickupScreen> createState() => _DeliveryPickupScreenState();
}

class _DeliveryPickupScreenState extends State<DeliveryPickupScreen> {
  final DateFormat _dateTimeFormat = DateFormat('dd MMM, hh:mm a');
  List<Machine> _machines = const [];
  List<OrderHistoryItem> _history = const [];
  final Map<int, DeliveryTask> _deliveryTasksByOrderId = {};
  final Map<int, PickupTask> _pickupTasksByOrderId = {};
  bool _loading = true;
  int? _markingPickupMachineId;
  int? _updatingPickupOrderId;
  int? _updatingDeliveryOrderId;
  String _deliveryStatusFilter = _allDeliveryStatuses;

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
      widget.repository.getOrderHistory(),
      widget.repository.getDeliveryTasks(),
      widget.repository.getPickupTasks(),
    ]);

    final machines = results[0] as List<Machine>;
    final history = results[1] as List<OrderHistoryItem>;
    final tasks = results[2] as List<DeliveryTask>;
    final pickupTasks = results[3] as List<PickupTask>;
    _deliveryTasksByOrderId
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.orderId, task)));
    _pickupTasksByOrderId
      ..clear()
      ..addEntries(pickupTasks.map((task) => MapEntry(task.orderId, task)));
    await _seedMissingDeliveryTasks(history);
    await _seedMissingPickupTasks(machines, history);

    if (!mounted) {
      return;
    }

    setState(() {
      _machines = machines;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _seedMissingPickupTasks(
    List<Machine> machines,
    List<OrderHistoryItem> history,
  ) async {
    final historyByOrderId = {
      for (final item in history) item.order.id: item,
    };
    final machineCandidates = machines
        .where((machine) =>
            machine.isReadyForPickup && machine.currentOrderId != null)
        .toList()
      ..sort((a, b) {
        final left = historyByOrderId[a.currentOrderId!];
        final right = historyByOrderId[b.currentOrderId!];
        final leftTime =
            left?.order.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightTime =
            right?.order.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return rightTime.compareTo(leftTime);
      });

    for (final machine in machineCandidates.take(8)) {
      final orderId = machine.currentOrderId;
      if (orderId == null ||
          _pickupTasksByOrderId.containsKey(orderId) ||
          !historyByOrderId.containsKey(orderId)) {
        continue;
      }
      final task = await widget.repository.savePickupTask(
        task: PickupTask(
          orderId: orderId,
          machineId: machine.id,
          status: PickupTaskStatus.pending,
        ),
      );
      _pickupTasksByOrderId[task.orderId] = task;
    }

    if (_pickupTasksByOrderId.isNotEmpty) {
      return;
    }

    final historyCandidates = history
        .where(
          (item) =>
              item.order.paymentStatus == PaymentStatus.paid &&
              item.order.status == OrderStatus.completed,
        )
        .toList()
      ..sort((a, b) => b.order.timestamp.compareTo(a.order.timestamp));

    for (final item in historyCandidates.take(4)) {
      if (_pickupTasksByOrderId.containsKey(item.order.id)) {
        continue;
      }
      final task = await widget.repository.savePickupTask(
        task: PickupTask(
          orderId: item.order.id,
          machineId: item.machine.id,
          status: PickupTaskStatus.pending,
        ),
      );
      _pickupTasksByOrderId[task.orderId] = task;
    }
  }

  Future<void> _seedMissingDeliveryTasks(List<OrderHistoryItem> history) async {
    final candidates = history
        .where((item) => item.order.paymentStatus == PaymentStatus.paid)
        .toList()
      ..sort((a, b) => b.order.timestamp.compareTo(a.order.timestamp));

    for (final item in candidates.take(8)) {
      if (_deliveryTasksByOrderId.containsKey(item.order.id)) {
        continue;
      }
      final task = await widget.repository.saveDeliveryTask(
        task: DeliveryTask(
          orderId: item.order.id,
          status: DeliveryTaskStatus.pending,
          assignedDriver: null,
          windowLabel: context.l10n.todayDeliveryWindow,
        ),
      );
      _deliveryTasksByOrderId[item.order.id] = task;
    }
  }

  OrderHistoryItem? _historyItemByOrderId(int orderId) {
    for (final item in _history) {
      if (item.order.id == orderId) {
        return item;
      }
    }
    return null;
  }

  Machine? _machineById(int machineId) {
    for (final machine in _machines) {
      if (machine.id == machineId) {
        return machine;
      }
    }
    return null;
  }

  List<_PickupQueueItem> get _pickupQueueItems {
    final items = _pickupTasksByOrderId.values
        .where((task) => task.status != PickupTaskStatus.pickedUp)
        .map((task) {
          final historyItem = _historyItemByOrderId(task.orderId);
          final machine = _machineById(task.machineId) ?? historyItem?.machine;
          if (historyItem == null || machine == null) {
            return null;
          }
          return _PickupQueueItem(
            task: task,
            machine: machine,
            historyItem: historyItem,
          );
        })
        .whereType<_PickupQueueItem>()
        .toList()
      ..sort(
        (a, b) => b.historyItem.order.timestamp
            .compareTo(a.historyItem.order.timestamp),
      );
    return items;
  }

  List<_DeliveryQueueItem> get _deliveryQueueItems {
    final items = _deliveryTasksByOrderId.values
        .map((task) {
          final historyItem = _historyItemByOrderId(task.orderId);
          if (historyItem == null) {
            return null;
          }
          return _DeliveryQueueItem(task: task, historyItem: historyItem);
        })
        .whereType<_DeliveryQueueItem>()
        .toList();

    items.sort(
      (a, b) => b.historyItem.order.timestamp
          .compareTo(a.historyItem.order.timestamp),
    );
    return items;
  }

  List<_DeliveryQueueItem> get _filteredDeliveryQueueItems {
    if (_deliveryStatusFilter == _allDeliveryStatuses) {
      return _deliveryQueueItems;
    }
    return _deliveryQueueItems
        .where((item) => item.task.status == _deliveryStatusFilter)
        .toList();
  }

  List<String> get _deliveryStatusFilters => const [
        _allDeliveryStatuses,
        DeliveryTaskStatus.pending,
        DeliveryTaskStatus.scheduled,
        DeliveryTaskStatus.outForDelivery,
        DeliveryTaskStatus.delivered,
        DeliveryTaskStatus.cancelled,
      ];

  Future<void> _savePickupTask(PickupTask task) async {
    final saved = await widget.repository.savePickupTask(task: task);
    if (!mounted) {
      return;
    }
    setState(() {
      _pickupTasksByOrderId[saved.orderId] = saved;
    });
  }

  Future<void> _sendPickupReminder(_PickupQueueItem queueItem) async {
    setState(() {
      _updatingPickupOrderId = queueItem.historyItem.order.id;
    });
    final phone = WhatsAppNotificationService.normalizePhone(
        queueItem.historyItem.customer.phone);
    final message = Uri.encodeComponent(
      WhatsAppNotificationService.buildCycleCompletedMessage(
          queueItem.historyItem),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    if (launched) {
      await _savePickupTask(
        queueItem.task.copyWith(status: PickupTaskStatus.reminderSent),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _updatingPickupOrderId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? '${context.l10n.pickupReminderSent} ${queueItem.historyItem.customer.fullName}.'
              : context.l10n.openWhatsappError,
        ),
      ),
    );
  }

  Future<void> _markPickedUp(_PickupQueueItem queueItem) async {
    setState(() {
      _markingPickupMachineId = queueItem.machine.id;
      _updatingPickupOrderId = queueItem.historyItem.order.id;
    });
    try {
      await widget.repository.markMachinePickedUp(queueItem.machine.id);
      await _savePickupTask(
        queueItem.task.copyWith(status: PickupTaskStatus.pickedUp),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${queueItem.historyItem.customer.fullName} ${context.l10n.markedPickedUp}',
          ),
        ),
      );
      await _loadData(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _markingPickupMachineId = null;
          _updatingPickupOrderId = null;
        });
      }
    }
  }

  void _callCustomer(OrderHistoryItem item, String contextLabel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${contextLabel == 'Delivery' ? context.l10n.deliveryCustomerContact : context.l10n.pickupCustomerContact}: ${item.customer.fullName} • ${item.customer.phone}',
        ),
      ),
    );
  }

  Future<void> _openDeliveryEditor(_DeliveryQueueItem queueItem) async {
    final driverController = TextEditingController(
      text: queueItem.task.assignedDriver ?? 'Ravi Courier',
    );
    final windowController = TextEditingController(
      text: queueItem.task.windowLabel,
    );

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          queueItem.task.status == DeliveryTaskStatus.pending
              ? context.l10n.scheduleDelivery
              : context.l10n.editDelivery,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: driverController,
              decoration:
                  InputDecoration(labelText: context.l10n.assignedDriver),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: windowController,
              decoration:
                  InputDecoration(labelText: context.l10n.deliveryWindow),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final driver = driverController.text.trim();
              final window = windowController.text.trim();
              if (driver.isEmpty || window.isEmpty) {
                return;
              }
              Navigator.of(context).pop((driver, window));
            },
            child: Text(context.l10n.saveDelivery),
          ),
        ],
      ),
    );

    driverController.dispose();
    windowController.dispose();

    if (!mounted || result == null) {
      return;
    }

    await _saveDeliveryTask(
      queueItem.task.copyWith(
        status: queueItem.task.status == DeliveryTaskStatus.cancelled
            ? DeliveryTaskStatus.pending
            : DeliveryTaskStatus.scheduled,
        assignedDriver: result.$1,
        windowLabel: result.$2,
      ),
    );
  }

  Future<void> _updateDeliveryStatus(
    _DeliveryQueueItem queueItem,
    String status,
  ) async {
    setState(() {
      _updatingDeliveryOrderId = queueItem.historyItem.order.id;
    });
    await _saveDeliveryTask(queueItem.task.copyWith(status: status));
    if (!mounted) {
      return;
    }
    setState(() {
      _updatingDeliveryOrderId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.l10n.deliveryUpdatedFor} ${queueItem.historyItem.customer.fullName}.',
        ),
      ),
    );
  }

  Future<void> _saveDeliveryTask(DeliveryTask task) async {
    final saved = await widget.repository.saveDeliveryTask(task: task);
    if (!mounted) {
      return;
    }
    setState(() {
      _deliveryTasksByOrderId[saved.orderId] = saved;
    });
  }

  Future<void> _sendDeliveryUpdate(_DeliveryQueueItem queueItem) async {
    final phone = WhatsAppNotificationService.normalizePhone(
        queueItem.historyItem.customer.phone);
    final message = Uri.encodeComponent(
      [
        'Your laundry order is being handled for delivery.',
        'Order #${queueItem.historyItem.order.id}',
        'Customer: ${queueItem.historyItem.customer.fullName}',
        'Status: ${deliveryStatusLabel(context, queueItem.task.status)}',
        'Window: ${queueItem.task.windowLabel}',
        if ((queueItem.task.assignedDriver ?? '').isNotEmpty)
          'Driver: ${queueItem.task.assignedDriver}',
      ].join('\n'),
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    final launched = await openExternalUrl(url);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? '${context.l10n.deliveryUpdateSent} ${queueItem.historyItem.customer.fullName}.'
              : context.l10n.openWhatsappError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickupItems = _pickupQueueItems;
    final allDeliveryItems = _deliveryQueueItems;
    final deliveryItems = _filteredDeliveryQueueItems;

    return DefaultTabController(
      initialIndex:
          widget.initialTab == DeliveryPickupInitialTab.delivery ? 0 : 1,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialTab == DeliveryPickupInitialTab.delivery
                ? context.l10n.deliveryDesk
                : context.l10n.pickupDesk,
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.delivery),
              Tab(text: context.l10n.pickup),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : () => _loadData(showLoading: false),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _SummaryBanner(
                        title: context.l10n.deliveryDesk,
                        description: context.l10n.deliveryDeskDescription,
                        primaryMetricLabel: context.l10n.scheduled,
                        primaryMetricValue:
                            '${allDeliveryItems.where((item) => item.task.status == DeliveryTaskStatus.scheduled).length}',
                        secondaryMetricLabel: context.l10n.outNow,
                        secondaryMetricValue:
                            '${allDeliveryItems.where((item) => item.task.status == DeliveryTaskStatus.outForDelivery).length}',
                      ),
                      const SizedBox(height: 20),
                      _DeliveryStatusFilterBar(
                        title: context.l10n.statusFilters,
                        summary:
                            context.l10n.showingTasks(deliveryItems.length),
                        filters: _deliveryStatusFilters,
                        selectedFilter: _deliveryStatusFilter,
                        onSelected: (filter) {
                          setState(() {
                            _deliveryStatusFilter = filter;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (allDeliveryItems.isEmpty)
                        _EmptyOperationsState(
                          title: context.l10n.deliveryTasksEmptyTitle,
                          message: context.l10n.deliveryTasksEmptyMessage,
                        )
                      else if (deliveryItems.isEmpty)
                        _EmptyOperationsState(
                          title: deliveryStatusLabel(
                            context,
                            _deliveryStatusFilter,
                          ),
                          message: context.l10n.noTasksForStatus,
                        )
                      else
                        ...deliveryItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DeliveryTaskCard(
                              item: item,
                              busy: _updatingDeliveryOrderId ==
                                  item.historyItem.order.id,
                              onSchedule: item.task.status ==
                                          DeliveryTaskStatus.pending ||
                                      item.task.status ==
                                          DeliveryTaskStatus.cancelled ||
                                      item.task.status ==
                                          DeliveryTaskStatus.scheduled
                                  ? () => _openDeliveryEditor(item)
                                  : null,
                              onDispatch: item.task.status ==
                                      DeliveryTaskStatus.scheduled
                                  ? () => _updateDeliveryStatus(
                                        item,
                                        DeliveryTaskStatus.outForDelivery,
                                      )
                                  : null,
                              onDelivered: item.task.status ==
                                      DeliveryTaskStatus.outForDelivery
                                  ? () => _updateDeliveryStatus(
                                        item,
                                        DeliveryTaskStatus.delivered,
                                      )
                                  : null,
                              onCancel: item.task.status !=
                                          DeliveryTaskStatus.delivered &&
                                      item.task.status !=
                                          DeliveryTaskStatus.cancelled
                                  ? () => _updateDeliveryStatus(
                                        item,
                                        DeliveryTaskStatus.cancelled,
                                      )
                                  : null,
                              onReopen: item.task.status ==
                                      DeliveryTaskStatus.cancelled
                                  ? () => _updateDeliveryStatus(
                                        item,
                                        DeliveryTaskStatus.pending,
                                      )
                                  : null,
                              onSendUpdate: () => _sendDeliveryUpdate(item),
                              onCallCustomer: () =>
                                  _callCustomer(item.historyItem, 'Delivery'),
                              dateTimeFormat: _dateTimeFormat,
                            ),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _SummaryBanner(
                        title: context.l10n.pickupDesk,
                        description: context.l10n.pickupDeskDescription,
                        primaryMetricLabel: context.l10n.readyLoads,
                        primaryMetricValue:
                            '${pickupItems.where((item) => item.task.status == PickupTaskStatus.pending).length}',
                        secondaryMetricLabel: context.l10n.reminderSent,
                        secondaryMetricValue:
                            '${pickupItems.where((item) => item.task.status == PickupTaskStatus.reminderSent).length}',
                      ),
                      const SizedBox(height: 20),
                      if (pickupItems.isEmpty)
                        _EmptyOperationsState(
                          title: context.l10n.pickupTasksEmptyTitle,
                          message: context.l10n.pickupTasksEmptyMessage,
                        )
                      else
                        ...pickupItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PickupTaskCard(
                              item: item,
                              busy:
                                  _markingPickupMachineId == item.machine.id ||
                                      _updatingPickupOrderId ==
                                          item.historyItem.order.id,
                              onSendReminder: () => _sendPickupReminder(item),
                              onMarkPickedUp: () => _markPickedUp(item),
                              onCallCustomer: () =>
                                  _callCustomer(item.historyItem, 'Pickup'),
                              dateTimeFormat: _dateTimeFormat,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.title,
    required this.description,
    required this.primaryMetricLabel,
    required this.primaryMetricValue,
    required this.secondaryMetricLabel,
    required this.secondaryMetricValue,
  });

  final String title;
  final String description;
  final String primaryMetricLabel;
  final String primaryMetricValue;
  final String secondaryMetricLabel;
  final String secondaryMetricValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF1E97B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
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
              _MetricPill(label: primaryMetricLabel, value: primaryMetricValue),
              _MetricPill(
                  label: secondaryMetricLabel, value: secondaryMetricValue),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
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
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  const _PickupTaskCard({
    required this.item,
    required this.busy,
    required this.onSendReminder,
    required this.onMarkPickedUp,
    required this.onCallCustomer,
    required this.dateTimeFormat,
  });

  final _PickupQueueItem item;
  final bool busy;
  final VoidCallback onSendReminder;
  final VoidCallback onMarkPickedUp;
  final VoidCallback onCallCustomer;
  final DateFormat dateTimeFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    '${item.historyItem.customer.fullName} • ${item.machine.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusBadge(
                  label: pickupStatusLabel(context, item.task.status),
                  color: pickupStatusColor(item.task.status),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${l10n.phone}: ${item.historyItem.customer.phone}'),
                Text('${l10n.ref}: ${item.historyItem.order.paymentReference}'),
                Text(
                    '${l10n.amount}: INR ${item.historyItem.order.amount.toStringAsFixed(0)}'),
                Text(dateTimeFormat.format(item.historyItem.order.timestamp)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onCallCustomer,
                  icon: const Icon(Icons.call_outlined),
                  label: Text(l10n.callCustomer),
                ),
                OutlinedButton.icon(
                  onPressed: onSendReminder,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(l10n.sendReminder),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onMarkPickedUp,
                  icon: const Icon(Icons.task_alt_outlined),
                  label: Text(
                    busy ? l10n.updating : l10n.markPickedUp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTaskCard extends StatelessWidget {
  const _DeliveryTaskCard({
    required this.item,
    required this.busy,
    required this.onSchedule,
    required this.onDispatch,
    required this.onDelivered,
    required this.onCancel,
    required this.onReopen,
    required this.onSendUpdate,
    required this.onCallCustomer,
    required this.dateTimeFormat,
  });

  final _DeliveryQueueItem item;
  final bool busy;
  final VoidCallback? onSchedule;
  final VoidCallback? onDispatch;
  final VoidCallback? onDelivered;
  final VoidCallback? onCancel;
  final VoidCallback? onReopen;
  final VoidCallback onSendUpdate;
  final VoidCallback onCallCustomer;
  final DateFormat dateTimeFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    '${item.historyItem.customer.fullName} • Order #${item.historyItem.order.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusBadge(
                  label: deliveryStatusLabel(context, item.task.status),
                  color: deliveryStatusColor(item.task.status),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${l10n.phone}: ${item.historyItem.customer.phone}'),
                Text('${l10n.machine}: ${item.historyItem.machine.name}'),
                Text('${l10n.ref}: ${item.historyItem.order.paymentReference}'),
                Text(
                    '${l10n.amount}: INR ${item.historyItem.order.amount.toStringAsFixed(0)}'),
                Text('${l10n.window}: ${item.task.windowLabel}'),
                if ((item.task.assignedDriver ?? '').isNotEmpty)
                  Text('${l10n.driver}: ${item.task.assignedDriver}'),
                Text(dateTimeFormat.format(item.historyItem.order.timestamp)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onCallCustomer,
                  icon: const Icon(Icons.call_outlined),
                  label: Text(l10n.callCustomer),
                ),
                OutlinedButton.icon(
                  onPressed: onSendUpdate,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(l10n.sendUpdate),
                ),
                if (onSchedule != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onSchedule,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      busy
                          ? l10n.saving
                          : item.task.status == DeliveryTaskStatus.scheduled
                              ? l10n.editDelivery
                              : l10n.scheduleDelivery,
                    ),
                  ),
                if (onDispatch != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onDispatch,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      busy ? l10n.saving : l10n.markOutForDelivery,
                    ),
                  ),
                if (onDelivered != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onDelivered,
                    icon: const Icon(Icons.home_work_outlined),
                    label: Text(busy ? l10n.saving : l10n.markDelivered),
                  ),
                if (onCancel != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(l10n.cancelDelivery),
                  ),
                if (onReopen != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReopen,
                    icon: const Icon(Icons.restart_alt_outlined),
                    label: Text(l10n.reopenDelivery),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStatusFilterBar extends StatelessWidget {
  const _DeliveryStatusFilterBar({
    required this.title,
    required this.summary,
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  final String title;
  final String summary;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filters
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(deliveryStatusLabel(context, filter)),
                      selected: selectedFilter == filter,
                      onSelected: (_) => onSelected(filter),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
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

class _EmptyOperationsState extends StatelessWidget {
  const _EmptyOperationsState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 42),
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
}

class _PickupQueueItem {
  const _PickupQueueItem({
    required this.task,
    required this.machine,
    required this.historyItem,
  });

  final PickupTask task;
  final Machine machine;
  final OrderHistoryItem historyItem;
}

class _DeliveryQueueItem {
  const _DeliveryQueueItem({
    required this.task,
    required this.historyItem,
  });

  final DeliveryTask task;
  final OrderHistoryItem historyItem;
}

String deliveryStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  switch (status) {
    case _allDeliveryStatuses:
      return l10n.all;
    case DeliveryTaskStatus.scheduled:
      return l10n.scheduled;
    case DeliveryTaskStatus.outForDelivery:
      return l10n.outForDelivery;
    case DeliveryTaskStatus.delivered:
      return l10n.delivered;
    case DeliveryTaskStatus.cancelled:
      return l10n.cancelled;
    default:
      return l10n.pendingSchedule;
  }
}

Color deliveryStatusColor(String status) {
  switch (status) {
    case DeliveryTaskStatus.scheduled:
      return const Color(0xFF1D4ED8);
    case DeliveryTaskStatus.outForDelivery:
      return const Color(0xFF0F766E);
    case DeliveryTaskStatus.delivered:
      return const Color(0xFF2E8B57);
    case DeliveryTaskStatus.cancelled:
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFFD97706);
  }
}

String pickupStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  switch (status) {
    case PickupTaskStatus.reminderSent:
      return l10n.reminderSent;
    case PickupTaskStatus.pickedUp:
      return l10n.pickedUpStatus;
    default:
      return l10n.pickupReady;
  }
}

Color pickupStatusColor(String status) {
  switch (status) {
    case PickupTaskStatus.reminderSent:
      return const Color(0xFF1D4ED8);
    case PickupTaskStatus.pickedUp:
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF2E8B57);
  }
}
