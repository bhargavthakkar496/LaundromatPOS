import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/demo_settings.dart';
import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/inventory.dart';
import '../models/machine.dart';
import '../models/pos_user.dart';
import '../services/open_external_url.dart';
import '../services/customer_display_launcher.dart';
import '../services/whatsapp_notification_service.dart';
import '../ui/tokens/app_colors.dart';
import '../ui/tokens/app_radius.dart';
import '../ui/tokens/app_spacing.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/dashboard_wrap_grid.dart';
import '../widgets/manager_option_icon.dart';
import '../widgets/meta_pill.dart';
import '../widgets/status_badge.dart';
import '../widgets/surface_card.dart';
import 'customer_profile_screen.dart';
import 'inventory_screen.dart';
import 'maintenance_screen.dart';
import 'machine_overview_screen.dart';
import 'delivery_pickup_screen.dart';
import 'operator_payment_screen.dart';
import 'order_management_screen.dart';
import 'order_history_screen.dart';
import 'pricing_screen.dart';
import 'refund_requests_screen.dart';
import 'revenue_dashboard_screen.dart';
import 'staff_management_screen.dart';

class MachineListScreen extends StatefulWidget {
  const MachineListScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.onLogout,
    required this.currentLocale,
    required this.onLocaleChanged,
    required this.shouldAutoOpenCustomerScreen,
    required this.onCustomerScreenAutoOpened,
  });

  final PosRepository repository;
  final PosUser user;
  final Future<void> Function() onLogout;
  final Locale currentLocale;
  final Future<void> Function(Locale locale) onLocaleChanged;
  final bool shouldAutoOpenCustomerScreen;
  final VoidCallback onCustomerScreenAutoOpened;

  @override
  State<MachineListScreen> createState() => _MachineListScreenState();
}

class _MachineListScreenState extends State<MachineListScreen> {
  Timer? _refreshTimer;
  final Map<int, String> _lastKnownStatusByMachineId = {};
  final Set<int> _autoNotifiedCompletionOrderIds = <int>{};
  List<InventoryRestockRequest> _pendingRestockRequests = const [];
  List<InventoryRestockRequest> _approvedRestockRequests = const [];
  bool _loading = true;
  bool _operatorMessageShown = false;
  int? _approvingRestockRequestId;
  int? _markingProcuredRestockRequestId;

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
    final launched = await CustomerDisplayLauncher.open();
    if (!mounted) {
      return;
    }
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.openCustomerScreenError),
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

  void _showOperatorFloatingMessage() {
    if (_operatorMessageShown) {
      return;
    }
    _operatorMessageShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.brandPrimary,
          content: Text(
            context.l10n.operatorReady,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
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

    final results = await Future.wait([
      widget.repository.getMachines(),
      widget.repository.getInventoryRestockRequests(
        status: InventoryRestockRequestStatus.pending,
      ),
      widget.repository.getInventoryRestockRequests(
        status: InventoryRestockRequestStatus.approved,
      ),
    ]);
    final machines = results[0] as List<Machine>;
    final pendingRestockRequests = results[1] as List<InventoryRestockRequest>;
    final approvedRestockRequests = results[2] as List<InventoryRestockRequest>;
    await _handleAutomaticCompletionNotifications(machines);
    for (final machine in machines) {
      _lastKnownStatusByMachineId[machine.id] = machine.status;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingRestockRequests = pendingRestockRequests;
      _approvedRestockRequests = approvedRestockRequests;
      _loading = false;
    });
    _showOperatorFloatingMessage();
  }

  Future<void> _approveRestockRequest(InventoryRestockRequest request) async {
    final remarksController = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Restock Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.itemName} • ${request.requestedQuantity} ${request.unit}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Operator remarks',
                  hintText:
                      'Approved for next supplier run and priority shelf replenishment.',
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
                final value = remarksController.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    remarksController.dispose();

    if (!mounted || remarks == null || remarks.trim().isEmpty) {
      return;
    }

    setState(() {
      _approvingRestockRequestId = request.id;
    });

    await widget.repository.approveInventoryRestockRequest(
      requestId: request.id,
      operatorRemarks: remarks,
      approverName: widget.user.displayName,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _approvingRestockRequestId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Restock request ${request.requestNumber} approved and moved into procurement.',
        ),
      ),
    );
    _loadMachines(showLoading: false);
  }

  Future<void> _markRestockRequestProcured(
    InventoryRestockRequest request,
  ) async {
    setState(() {
      _markingProcuredRestockRequestId = request.id;
    });

    try {
      await widget.repository.markInventoryRestockRequestProcured(
        requestId: request.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restock request ${request.requestNumber} marked procured. Inventory is healthy again.',
          ),
        ),
      );
      _loadMachines(showLoading: false);
    } finally {
      if (mounted) {
        setState(() {
          _markingProcuredRestockRequestId = null;
        });
      }
    }
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
        SnackBar(
          content: Text(context.l10n.openWhatsappError),
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
          builder: (_) => OperatorPaymentScreen(
            repository: widget.repository,
            user: widget.user,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Inventory') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InventoryScreen(repository: widget.repository),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Pricing') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PricingScreen(repository: widget.repository),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Staff') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StaffManagementScreen(
            repository: widget.repository,
            managerName: widget.user.displayName,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Maintenance') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MaintenanceScreen(
            repository: widget.repository,
            user: widget.user,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

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

    if (action.title == 'Complaint Refund') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RefundRequestsScreen(
            repository: widget.repository,
            user: widget.user,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Revenue & Reports') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RevenueDashboardScreen(
            repository: widget.repository,
            user: widget.user,
          ),
        ),
      );
      _loadMachines(showLoading: false);
      return;
    }

    if (action.title == 'Customer Screen') {
      await _openCustomerDisplay();
      return;
    }

    if (action.title == 'Delivery' || action.title == 'Pickup Desk') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DeliveryPickupScreen(
            repository: widget.repository,
            user: widget.user,
            initialTab: action.title == 'Delivery'
                ? DeliveryPickupInitialTab.delivery
                : DeliveryPickupInitialTab.pickup,
          ),
        ),
      );
      _loadMachines(showLoading: false);
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
        description:
            'Run operator checkout, search past payments, and create refund requests.',
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
        title: 'Delivery',
        shortTitle: 'Delivery',
        description:
            'Schedule home delivery, dispatch orders, and confirm delivered loads.',
        iconType: ManagerOptionIconType.delivery,
      ),
      _ManagerAction(
        title: 'Pickup Desk',
        shortTitle: 'Pickup',
        description:
            'Monitor ready loads, remind customers, and close pickup handovers.',
        iconType: ManagerOptionIconType.pickup,
      ),
      _ManagerAction(
        title: 'Maintenance',
        shortTitle: 'Maintenance',
        description: 'Track machine service tasks and downtime handling.',
        iconType: ManagerOptionIconType.maintenance,
      ),
      _ManagerAction(
        title: 'Revenue & Reports',
        shortTitle: 'Reports',
        description:
            'Open the central reporting hub for revenue, transactions, payment mix, machine mix, refunds, and day-end closeout.',
        iconType: ManagerOptionIconType.revenue,
      ),
      _ManagerAction(
        title: 'Complaint Refund',
        shortTitle: 'Refunds',
        description:
            'Review queued refund requests and process approved refunds.',
        iconType: ManagerOptionIconType.complaintRefund,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = _managerActions();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.language,
            onSelected: (value) => widget.onLocaleChanged(Locale(value)),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'en',
                child: Text(l10n.english),
              ),
              PopupMenuItem<String>(
                value: 'ar',
                child: Text(l10n.arabic),
              ),
              PopupMenuItem<String>(
                value: 'th',
                child: Text(l10n.thai),
              ),
              PopupMenuItem<String>(
                value: 'hi',
                child: Text(l10n.hindi),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.language_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(l10n.languageName(widget.currentLocale.languageCode)),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _openHistory,
            child: Text(l10n.orderHistory),
          ),
          TextButton(
            onPressed: widget.onLogout,
            child: Text(l10n.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_pendingRestockRequests.isNotEmpty) ...[
                  DashboardSection(
                    title: l10n.restockRequests,
                    description: l10n.restockRequestsDescription,
                    child: Column(
                      children: _pendingRestockRequests
                          .map(
                            (request) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RestockRequestCard(
                                title: request.itemName,
                                subtitle:
                                    '${request.requestNumber} • ${request.itemSku} • ${request.itemCategory}',
                                statusLabel: l10n.pendingApproval,
                                statusColor: const Color(0xFFD78B2E),
                                notes: request.requestNotes == null ||
                                        request.requestNotes!.isEmpty
                                    ? null
                                    : '${l10n.requestNote}: ${request.requestNotes!}',
                                metadata: [
                                  _SectionMetaData(
                                    label: l10n.requestedQty,
                                    value:
                                        '${request.requestedQuantity} ${request.unit}',
                                  ),
                                  _SectionMetaData(
                                    label: l10n.supplier,
                                    value: request.supplier ?? l10n.unassigned,
                                  ),
                                  _SectionMetaData(
                                    label: l10n.branchLocation,
                                    value:
                                        '${request.branch} / ${request.location}',
                                  ),
                                  _SectionMetaData(
                                    label: l10n.requestedBy,
                                    value:
                                        request.requestedByName ?? l10n.system,
                                  ),
                                  _SectionMetaData(
                                    label: l10n.created,
                                    value: MaterialLocalizations.of(context)
                                        .formatShortDate(request.createdAt),
                                  ),
                                ],
                                action: FilledButton.icon(
                                  onPressed: _approvingRestockRequestId ==
                                          request.id
                                      ? null
                                      : () => _approveRestockRequest(request),
                                  icon: const Icon(Icons.approval_outlined),
                                  label: Text(
                                    _approvingRestockRequestId == request.id
                                        ? l10n.approving
                                        : l10n.approveWithRemarks,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                if (_approvedRestockRequests.isNotEmpty) ...[
                  DashboardSection(
                    title: l10n.inProcurement,
                    description: l10n.inProcurementDescription,
                    child: Column(
                      children: _approvedRestockRequests
                          .map(
                            (request) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RestockRequestCard(
                                title: request.itemName,
                                subtitle:
                                    '${request.requestNumber} • ${request.itemSku} • ${request.itemCategory}',
                                statusLabel: l10n.inProcurement,
                                statusColor: const Color(0xFF1E7C93),
                                notes: (request.operatorRemarks ?? '')
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : 'Operator remarks: ${request.operatorRemarks!}',
                                metadata: [
                                  _SectionMetaData(
                                    label: 'Approved Qty',
                                    value:
                                        '${request.requestedQuantity} ${request.unit}',
                                  ),
                                  _SectionMetaData(
                                    label: 'Supplier',
                                    value: request.supplier ?? 'Unassigned',
                                  ),
                                  _SectionMetaData(
                                    label: 'Branch / Location',
                                    value:
                                        '${request.branch} / ${request.location}',
                                  ),
                                  _SectionMetaData(
                                    label: 'Approved By',
                                    value: request.approvedByName ??
                                        widget.user.displayName,
                                  ),
                                ],
                                action: FilledButton.icon(
                                  onPressed: _markingProcuredRestockRequestId ==
                                          request.id
                                      ? null
                                      : () => _markRestockRequestProcured(
                                            request,
                                          ),
                                  icon: const Icon(Icons.inventory_2_outlined),
                                  label: Text(
                                    _markingProcuredRestockRequestId ==
                                            request.id
                                        ? 'Updating Stock...'
                                        : 'Mark Procured',
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                DashboardSection(
                  title: l10n.managerOptions,
                  description: l10n.managerOptionsDescription,
                  child: DashboardWrapGrid(
                    spacing: 8,
                    runSpacing: 8,
                    minChildWidth: 150,
                    maxColumns: 4,
                    children: actions
                        .map(
                          (action) => _ManagerActionCard(
                            action: action,
                            onTap: () => _handleManagerAction(action),
                          ),
                        )
                        .toList(),
                  ),
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
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFC),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  alignment: Alignment.center,
                  child: ManagerOptionIcon(
                    type: action.iconType,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 112,
                  child: Text(
                    context.l10n.managerActionShortTitle(action.title),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: 0,
                          color: AppColors.textStrong,
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

class _RestockRequestCard extends StatelessWidget {
  const _RestockRequestCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.metadata,
    required this.action,
    this.notes,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<_SectionMetaData> metadata;
  final Widget action;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: metadata
                .map(
                  (item) => MetaPill(
                    label: item.label,
                    value: item.value,
                  ),
                )
                .toList(),
          ),
          if ((notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              notes!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          action,
        ],
      ),
    );
  }
}

class _SectionMetaData {
  const _SectionMetaData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
