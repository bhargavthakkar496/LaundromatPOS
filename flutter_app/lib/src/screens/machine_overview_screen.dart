import 'dart:async';

import 'package:flutter/material.dart';

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

  Timer? _refreshTimer;
  final Map<int, String> _lastKnownStatusByMachineId = {};
  final Set<int> _autoNotifiedCompletionOrderIds = <int>{};
  List<Machine> _machines = const [];
  String _selectedCategory = Machine.washerType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMachines();
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
      if (!_availableCategories.contains(_selectedCategory) &&
          _availableCategories.isNotEmpty) {
        _selectedCategory = _availableCategories.first;
      }
      _loading = false;
    });
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

  List<Machine> get _visibleMachines => _machines
      .where(
        (machine) =>
            machine.type.toLowerCase() == _selectedCategory.toLowerCase(),
      )
      .toList();

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
      final remaining = machine.remainingCycleDuration;
      if (remaining == null) {
        return '${machine.type} started';
      }
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      final formatted = minutes > 0
          ? '${minutes}m ${seconds.toString().padLeft(2, '0')}s left'
          : '${seconds}s left';
      return '${machine.type} started • $formatted';
    }
    if (machine.isReadyForPickup) {
      return 'Completed • Ready for pickup';
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

  @override
  Widget build(BuildContext context) {
    final visibleMachines = _visibleMachines;

    return Scaffold(
      appBar: AppBar(title: const Text('Machine Overview')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _machines.isEmpty
              ? const Center(child: Text('No machines found.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_availableCategories.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
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
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (visibleMachines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('No machines found in this category.'),
                        ),
                      )
                    else
                      ...visibleMachines
                      .map(
                        (machine) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              leading: MachineIcon(machine: machine),
                              title: Text(machine.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${machine.type} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _statusLabel(machine),
                                    style: TextStyle(
                                      color: _statusColor(machine, context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: machine.isAvailable
                                  ? FilledButton.tonal(
                                      onPressed: machine.isIroningStation
                                          ? null
                                          : () => _startCheckout(machine),
                                      child: Text(
                                        machine.isIroningStation
                                            ? 'Available'
                                            : 'Start',
                                      ),
                                    )
                                  : machine.isInUse || machine.isReadyForPickup
                                      ? PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (value == 'delay') {
                                              _sendMachineDelayNotification(
                                                machine,
                                              );
                                            } else if (value == 'complete') {
                                              _sendCycleCompletedNotification(
                                                machine,
                                              );
                                            } else if (value == 'pickup') {
                                              _markPickedUp(machine);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            if (machine.isInUse)
                                              const PopupMenuItem<String>(
                                                value: 'delay',
                                                child:
                                                    Text('Send Delay Notice'),
                                              ),
                                            if (machine.isReadyForPickup)
                                              const PopupMenuItem<String>(
                                                value: 'complete',
                                                child: Text(
                                                  'Send Completion Notice',
                                                ),
                                              ),
                                            if (machine.isReadyForPickup)
                                              const PopupMenuItem<String>(
                                                value: 'pickup',
                                                child: Text('Mark Picked Up'),
                                              ),
                                          ],
                                        )
                                      : const Icon(Icons.build_outlined),
                              onTap: machine.isAvailable
                                  ? machine.isIroningStation
                                      ? null
                                      : () => _startCheckout(machine)
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  ],
                ),
    );
  }
}
