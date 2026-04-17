import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/demo_pos_repository.dart';
import '../models/active_order_session.dart';
import '../models/machine.dart';
import '../models/order.dart';
import '../models/order_history_item.dart';
import '../models/pos_user.dart';
import '../models/receipt_data.dart';
import '../widgets/customer_details_form.dart';
import '../widgets/machine_icon.dart';
import '../widgets/receipt_actions.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({
    super.key,
    required this.repository,
    required this.user,
  });

  final DemoPosRepository repository;
  final PosUser user;

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  static const _orderViews = ['Book Order', 'Order History'];
  static const _washOptions = ['Gentle Wash', 'Specific Wash'];
  static const _paymentMethods = ['UPI QR', 'Card', 'Cash'];
  static const _loadSizes = [8, 9, 10, 11, 12, 14, 15];
  static const _historyStatusOptions = [
    'All Statuses',
    OrderStatus.booked,
    OrderStatus.inProgress,
    OrderStatus.completed,
  ];

  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  String _selectedView = 'Book Order';
  String _washOption = _washOptions.first;
  String _paymentMethod = _paymentMethods.first;
  String _selectedHistoryStatus = _historyStatusOptions.first;
  int _loadSizeKg = _loadSizes[0];
  DateTime _selectedHistoryDate = DateTime.now();
  Machine? _selectedWasher;
  Machine? _selectedDryer;
  bool _saving = false;
  bool _confirming = false;
  Future<List<OrderHistoryItem>>? _historyFuture;
  List<Machine> _washers = const [];
  List<Machine> _dryers = const [];
  ActiveOrderSession? _activeSession;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _loadMachines();
    _refreshHistory();
    _refreshActiveSession();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      _refreshActiveSession(silent: true);
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    final machines = await widget.repository.getMachines();
    if (!mounted) {
      return;
    }
    setState(() {
      _washers = machines.where((machine) => machine.type == 'Washer').toList();
      _dryers = machines.where((machine) => machine.type == 'Dryer').toList();
      _selectedWasher ??= _washers.isEmpty ? null : _washers.first;
      _selectedDryer ??= _dryers.isEmpty ? null : _dryers.first;
    });
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = widget.repository.getOrderHistory();
    });
  }

  Future<void> _refreshActiveSession({bool silent = false}) async {
    final session = await widget.repository.getActiveOrderSession();
    if (!mounted) {
      return;
    }
    if (silent && _sessionEquals(_activeSession, session)) {
      return;
    }
    setState(() {
      _activeSession = session;
    });
  }

  bool _sessionEquals(ActiveOrderSession? left, ActiveOrderSession? right) {
    if (left == null && right == null) {
      return true;
    }
    if (left == null || right == null) {
      return false;
    }
    return left.stage == right.stage &&
        left.orderId == right.orderId &&
        left.paymentReference == right.paymentReference &&
        left.confirmedBy == right.confirmedBy &&
        left.customerName == right.customerName &&
        left.customerPhone == right.customerPhone;
  }

  Future<void> _submitOrderDraft() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _selectedWasher == null || _selectedDryer == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final session = await widget.repository.saveActiveOrderDraft(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      loadSizeKg: _loadSizeKg,
      washOption: _washOption,
      washer: _selectedWasher!,
      dryer: _selectedDryer!,
      paymentMethod: _paymentMethod,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
      _activeSession = session;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Order details are now visible on both operator and customer screens.',
        ),
      ),
    );
  }

  Future<void> _confirmFromOperator() async {
    setState(() {
      _confirming = true;
    });

    final session = await widget.repository.confirmActiveOrderSession(
      confirmedBy: 'Operator',
      user: widget.user,
    );

    if (!mounted) {
      return;
    }

    await _loadMachines();
    _refreshHistory();

    setState(() {
      _confirming = false;
      _activeSession = session;
      _selectedView = 'Book Order';
    });
  }

  String _statusLabel(String status) {
    if (status == 'All Statuses') {
      return 'All Statuses';
    }
    switch (status) {
      case OrderStatus.booked:
        return 'Booked';
      case OrderStatus.inProgress:
        return 'In Progress';
      default:
        return 'Completed';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case OrderStatus.booked:
        return const Color(0xFFCA8A04);
      case OrderStatus.inProgress:
        return const Color(0xFF0E7490);
      default:
        return const Color(0xFF2A9D8F);
    }
  }

  String _sessionStageLabel(ActiveOrderSession session) {
    if (session.isDraft) {
      return 'Awaiting Confirmation';
    }
    if (session.isBooked) {
      return 'Booked';
    }
    return 'Payment Confirmed';
  }

  Color _sessionStageColor(ActiveOrderSession session) {
    if (session.isDraft) {
      return const Color(0xFFCA8A04);
    }
    if (session.isBooked) {
      return const Color(0xFF0E7490);
    }
    return const Color(0xFF2A9D8F);
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _selectedHistoryDate = picked;
    });
  }

  Machine? _findMachine(int id, List<Machine> machines) {
    for (final machine in machines) {
      if (machine.id == id) {
        return machine;
      }
    }
    return null;
  }

  Future<ReceiptData?> _loadReceiptData(ActiveOrderSession session) async {
    final orderId = session.orderId;
    if (orderId == null) {
      return null;
    }
    final item = await widget.repository.getOrderHistoryItemByOrderId(orderId);
    if (item == null) {
      return null;
    }
    return ReceiptData(
      order: item.order,
      customer: item.customer,
      machine: item.machine,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: _orderViews
                .map(
                  (view) => ButtonSegment<String>(
                    value: view,
                    label: Text(view),
                    icon: Icon(
                      view == 'Book Order'
                          ? Icons.playlist_add_circle_outlined
                          : Icons.receipt_long_outlined,
                    ),
                  ),
                )
                .toList(),
            selected: {_selectedView},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedView = selection.first;
              });
            },
          ),
          const SizedBox(height: 20),
          if (_selectedView == 'Book Order') _buildBookingView(),
          if (_selectedView == 'Order History') _buildOrderHistory(),
        ],
      ),
    );
  }

  Widget _buildBookingView() {
    final session = _activeSession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session != null) ...[
          _buildActiveSessionCard(session),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take Order',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the order details here. The customer and operator will both see the same order for confirmation before booking.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  CustomerDetailsForm(
                    nameController: _customerNameController,
                    phoneController: _customerPhoneController,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _loadSizeKg,
                    decoration: const InputDecoration(labelText: 'Load size'),
                    items: _loadSizes
                        .map(
                          (size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size kg'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _loadSizeKg = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _washOption,
                    decoration: const InputDecoration(labelText: 'Wash option'),
                    items: _washOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _washOption = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Machine>(
                    initialValue: _selectedWasher,
                    decoration:
                        const InputDecoration(labelText: 'Washer assigned'),
                    items: _washers
                        .map(
                          (machine) => DropdownMenuItem<Machine>(
                            value: machine,
                            child: Text(
                              '${machine.name} • ${machine.capacityKg}kg',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedWasher = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Machine>(
                    initialValue: _selectedDryer,
                    decoration:
                        const InputDecoration(labelText: 'Dryer assigned'),
                    items: _dryers
                        .map(
                          (machine) => DropdownMenuItem<Machine>(
                            value: machine,
                            child: Text(
                              '${machine.name} • ${machine.capacityKg}kg',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() {
                              _selectedDryer = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Customer payment method',
                    ),
                    items: _paymentMethods
                        .map(
                          (method) => DropdownMenuItem<String>(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _paymentMethod = value;
                            });
                          },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submitOrderDraft,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _saving
                          ? 'Sending to customer...'
                          : 'Show On Both Screens',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionCard(ActiveOrderSession session) {
    final washer = _findMachine(session.washerMachineId, _washers);
    final dryer = _findMachine(session.dryerMachineId, _dryers);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                  'Live Order Session',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _sessionStageColor(session).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _sessionStageLabel(session),
                    style: TextStyle(
                      color: _sessionStageColor(session),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Customer: ${session.customerName}'),
            Text('Phone: ${session.customerPhone}'),
            Text('Load size: ${session.loadSizeKg}kg'),
            Text('Wash option: ${session.washOption}'),
            Text(
                'Washer assigned: ${washer?.name ?? 'Washer ${session.washerMachineId}'}'),
            Text(
                'Dryer assigned: ${dryer?.name ?? 'Dryer ${session.dryerMachineId}'}'),
            Text('Payment method: ${session.paymentMethod}'),
            if (session.confirmedBy != null)
              Text('Confirmed by: ${session.confirmedBy}'),
            if (session.paymentReference != null)
              Text('Payment reference: ${session.paymentReference}'),
            const SizedBox(height: 16),
            if (session.isDraft)
              FilledButton.icon(
                onPressed: _confirming ? null : _confirmFromOperator,
                icon: const Icon(Icons.verified_outlined),
                label: Text(
                  _confirming ? 'Confirming...' : 'Confirm From Operator',
                ),
              )
            else if (session.isBooked)
              const Text(
                'Booking is confirmed. Payment can now be initiated from the customer screen only.',
              )
            else
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment is complete. This confirmation is visible on both the operator and customer screens.',
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<ReceiptData?>(
                        future: _loadReceiptData(session),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Text(
                              'Receipt details could not be loaded.',
                            );
                          }

                          final receipt = snapshot.data;
                          if (receipt == null) {
                            return const Text(
                              'Receipt details are not available yet.',
                            );
                          }

                          return ReceiptActions(receipt: receipt);
                        },
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

  Widget _buildOrderHistory() {
    return FutureBuilder<List<OrderHistoryItem>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <OrderHistoryItem>[];

        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (items.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No orders have been created yet.'),
            ),
          );
        }

        final selectedDateLabel = DateFormat(
          'dd MMM yyyy',
        ).format(_selectedHistoryDate);
        final filteredItems = items
            .where(
              (item) => _isSameDate(item.order.timestamp, _selectedHistoryDate),
            )
            .where(
              (item) =>
                  _selectedHistoryStatus == 'All Statuses' ||
                  item.order.status == _selectedHistoryStatus,
            )
            .toList()
          ..sort((a, b) => b.order.timestamp.compareTo(a.order.timestamp));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Selected date',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedDateLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickHistoryDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Pick Date'),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedHistoryStatus,
                        decoration: const InputDecoration(
                          labelText: 'Order status filter',
                        ),
                        items: _historyStatusOptions
                            .map(
                              (status) => DropdownMenuItem<String>(
                                value: status,
                                child: Text(_statusLabel(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedHistoryStatus = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (filteredItems.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No orders found for $selectedDateLabel.'),
                ),
              )
            else
              ...filteredItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MachineIcon(machine: item.machine, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.customer.fullName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Load size: ${item.order.loadSizeKg ?? item.machine.capacityKg}kg',
                                ),
                                Text(
                                  'Wash option: ${item.order.washOption ?? 'Standard Wash'}',
                                ),
                                Text(
                                  'Washer assigned: ${item.machine.name}',
                                ),
                                Text(
                                  'Dryer assigned: ${item.dryerMachine?.name ?? 'Not assigned'}',
                                ),
                                Text(
                                  'Time: ${DateFormat('hh:mm a').format(item.order.timestamp)}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(
                                item.order.status,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _statusLabel(item.order.status),
                              style: TextStyle(
                                color: _statusColor(item.order.status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
