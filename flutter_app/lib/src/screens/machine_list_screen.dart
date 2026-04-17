import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/demo_settings.dart';
import '../data/pos_repository.dart';
import '../models/machine.dart';
import '../models/pos_user.dart';
import '../services/app_routes.dart';
import '../services/open_external_url.dart';
import '../services/whatsapp_notification_service.dart';
import '../widgets/manager_option_icon.dart';
import 'customer_self_service_screen.dart';
import 'customer_profile_screen.dart';
import 'inventory_screen.dart';
import 'machine_overview_screen.dart';
import 'order_management_screen.dart';
import 'order_history_screen.dart';

class MachineListScreen extends StatefulWidget {
  const MachineListScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.onLogout,
    required this.shouldAutoOpenCustomerScreen,
    required this.onCustomerScreenAutoOpened,
  });

  final PosRepository repository;
  final PosUser user;
  final Future<void> Function() onLogout;
  final bool shouldAutoOpenCustomerScreen;
  final VoidCallback onCustomerScreenAutoOpened;

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  Timer? _refreshTimer;
  final Map<int, String> _lastKnownStatusByMachineId = {};
  final Set<int> _autoNotifiedCompletionOrderIds = <int>{};
  List<Machine> _machines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMachines();
    _maybeAutoOpenCustomerScreen();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      _loadMachines(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MachineListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.shouldAutoOpenCustomerScreen &&
        widget.shouldAutoOpenCustomerScreen) {
      _maybeAutoOpenCustomerScreen();
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderHistoryScreen(
          repository: widget.repository,
          onLogout: widget.onLogout,
        ),
      ),
    );
    _loadMachines(showLoading: false);
  }

  Future<void> _openCustomerLookup() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerProfileScreen(repository: widget.repository),
      ),
    );
    _loadMachines(showLoading: false);
  }

  Future<void> _openCustomerDisplay() async {
    final launched = await openExternalUrl(AppRoutes.customerDisplayUri());
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the customer screen window.'),
        ),
      );
    }
  }

  void _maybeAutoOpenCustomerScreen() {
    if (!DemoSettings.autoOpenCustomerScreenAfterLogin ||
        kIsWeb ||
        !widget.shouldAutoOpenCustomerScreen) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.shouldAutoOpenCustomerScreen) {
        return;
      }
      await _openCustomerDisplay();
      if (!mounted) {
        return;
      }
      widget.onCustomerScreenAutoOpened();
    });
  }

  Future<void> _openMachines() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MachineOverviewScreen(
          repository: widget.repository,
          user: widget.user,
          onLogout: widget.onLogout,
        ),
      ),
    );
    _loadMachines(showLoading: false);
  }

  Future<void> _loadMachines({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

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
      _loading = false;
    });
  }

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

  void _showFeatureMessage(String title, String detail) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $detail')),
    );
  }

  Future<void> _handleManagerAction(_ManagerAction action) async {
    if (action.title == 'Machines') {
      await _openMachines();
      return;
    }

    if (action.title == 'Customer Lookup') {
      await _openCustomerLookup();
      return;
    }

    if (action.title == 'Payment') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CustomerSelfServiceScreen(
            repository: widget.repository,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Inventory') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const InventoryScreen(),
        ),
      );
      return;
    }

    if (action.title == 'Orders' ||
        action.title == 'Reports' ||
        action.title == 'Complaint Refund') {
      if (action.title == 'Orders') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderManagementScreen(
              repository: widget.repository,
              user: widget.user,
            ),
          ),
        );
        _loadMachines(showLoading: false);
        return;
      }
      await _openHistory();
      return;
    }

    if (action.title == 'Customer Screen') {
      await _openCustomerDisplay();
      return;
    }

    _showFeatureMessage(action.title, action.description);
  }

  List<_ManagerAction> _managerActions() {
    return const [
      _ManagerAction(
        title: 'Machines',
        shortTitle: 'Machines',
        description: 'View live machine health, availability, and wash status.',
        iconType: ManagerOptionIconType.machines,
      ),
      _ManagerAction(
        title: 'Inventory',
        shortTitle: 'Inventory',
        description: 'Track chemicals, bags, and spare stock for each shift.',
        iconType: ManagerOptionIconType.inventory,
      ),
      _ManagerAction(
        title: 'Customer Lookup',
        shortTitle: 'Customers',
        description: 'Search repeat customers and onboard new customers here.',
        iconType: ManagerOptionIconType.customerLookup,
      ),
      _ManagerAction(
        title: 'Payment',
        shortTitle: 'Payment',
        description: 'Review active payment methods and settlement readiness.',
        iconType: ManagerOptionIconType.payment,
      ),
      _ManagerAction(
        title: 'Orders',
        shortTitle: 'Orders',
        description: 'Open order history and complaint-linked order activity.',
        iconType: ManagerOptionIconType.orders,
      ),
      _ManagerAction(
        title: 'Staff',
        shortTitle: 'Staff',
        description: 'Manage staff access, shifts, and role coverage.',
        iconType: ManagerOptionIconType.staff,
      ),
      _ManagerAction(
        title: 'Pricing',
        shortTitle: 'Pricing',
        description: 'Update service prices, offers, and machine rate cards.',
        iconType: ManagerOptionIconType.pricing,
      ),
      _ManagerAction(
        title: 'Customer Screen',
        shortTitle: 'Screen',
        description: 'Launch and control the customer-facing display screen.',
        iconType: ManagerOptionIconType.customerScreen,
      ),
      _ManagerAction(
        title: 'Reports',
        shortTitle: 'Reports',
        description:
            'Open manager reports for cycle trends and order summaries.',
        iconType: ManagerOptionIconType.reports,
      ),
      _ManagerAction(
        title: 'Maintenance',
        shortTitle: 'Maintenance',
        description: 'Track machine service tasks and downtime handling.',
        iconType: ManagerOptionIconType.maintenance,
      ),
      _ManagerAction(
        title: 'Revenue & Day End',
        shortTitle: 'Revenue',
        description: 'Review revenue totals and prepare day-end checkout.',
        iconType: ManagerOptionIconType.revenue,
      ),
      _ManagerAction(
        title: 'Complaint Refund',
        shortTitle: 'Refunds',
        description:
            'Handle complaints, refunds, and customer recovery actions.',
        iconType: ManagerOptionIconType.complaintRefund,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _managerActions();
    final availableCount =
        _machines.where((machine) => machine.isAvailable).length;
    final activeCount = _machines.where((machine) => machine.isInUse).length;
    final readyCount =
        _machines.where((machine) => machine.isReadyForPickup).length;
    final maintenanceCount = _machines
        .where((machine) => machine.status == MachineStatus.maintenance)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.user.displayName}'),
        actions: [
          TextButton(
            onPressed: _openHistory,
            child: const Text('Order History'),
          ),
          TextButton(
            onPressed: widget.onLogout,
            child: const Text('Log Out'),
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
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E7490), Color(0xFF1F9CB4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x290E7490),
                        blurRadius: 24,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Wrap(
                    runSpacing: 16,
                    spacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Store Manager Home',
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
                              'Every major store control is available from this dashboard, with machines, customer handling, reporting, and day-end operations in one view.',
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
                          _SummaryPill(
                            label: 'Available',
                            value: '$availableCount',
                            accent: const Color(0xFF6FE0F4),
                          ),
                          _SummaryPill(
                            label: 'Running',
                            value: '$activeCount',
                            accent: const Color(0xFFFFC57A),
                          ),
                          _SummaryPill(
                            label: 'Pickup',
                            value: '$readyCount',
                            accent: const Color(0xFF88E0B8),
                          ),
                          _SummaryPill(
                            label: 'Maintenance',
                            value: '$maintenanceCount',
                            accent: const Color(0xFFFF8C8C),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Manager Options',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Store functions are grouped in compact rows of four.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4B6475),
                      ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final columns = constraints.maxWidth < 720 ? 2 : 4;
                    final cardWidth =
                        (constraints.maxWidth - (spacing * (columns - 1))) /
                            columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: actions
                          .map(
                            (action) => SizedBox(
                              width: cardWidth,
                              child: _ManagerActionCard(
                                action: action,
                                onTap: () => _handleManagerAction(action),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _ManagerAction {
  const _ManagerAction({
    required this.title,
    required this.shortTitle,
    required this.description,
    required this.iconType,
  });

  final String title;
  final String shortTitle;
  final String description;
  final ManagerOptionIconType iconType;
}

class _ManagerActionCard extends StatelessWidget {
  const _ManagerActionCard({
    required this.action,
    required this.onTap,
  });

  final _ManagerAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0EAF0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: ManagerOptionIcon(
                    type: action.iconType,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 84,
                  child: Text(
                    action.shortTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: 0,
                          color: const Color(0xFF223746),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
