import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/active_order_session.dart';
import '../models/garment_item.dart';
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

  final PosRepository repository;
  final PosUser user;

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  static const _orderViews = ['Book Order', 'Order History'];
  static const _washOptions = ['Gentle Wash', 'Specific Wash'];
  static const _paymentMethods = ['UPI QR', 'Card', 'Cash'];
  static const _loadSizes = [8, 9, 10, 11, 12, 14, 15];
  static const _garmentServiceRates = <String, double>{
    LaundryService.washing: 45,
    LaundryService.drying: 30,
    LaundryService.ironing: 18,
  };
  static const _historyStatusOptions = [
    'All Statuses',
    OrderStatus.booked,
    OrderStatus.inProgress,
    OrderStatus.completed,
    OrderStatus.readyForPickup,
    OrderStatus.delivered,
  ];
  static const _workflowActions = [
    'Receive garments and capture customer name, mobile number, and service requirements.',
    'Build a per-piece garment manifest with wash type, dry duration, ironing, and quantity.',
    'Calculate invoice total and generate the order id for the customer.',
    'Print one taffeta tag per garment piece with text details and QR-ready tag data.',
    'Scan tags during washing, drying, and ironing to update piece-level progress.',
    'Reconcile all tagged garments before marking the order ready for pickup or delivery.',
  ];

  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _selectedView = 'Book Order';
  String _washOption = _washOptions.first;
  String _paymentMethod = _paymentMethods.first;
  String _selectedHistoryStatus = _historyStatusOptions.first;
  int _loadSizeKg = _loadSizes[0];
  DateTime _selectedHistoryDate = DateTime.now();
  final Set<String> _selectedServices = {
    LaundryService.washing,
    LaundryService.drying,
  };
  Machine? _selectedWasher;
  Machine? _selectedDryer;
  Machine? _selectedIroningStation;
  bool _saving = false;
  bool _confirming = false;
  Future<List<OrderHistoryItem>>? _historyFuture;
  List<Machine> _washers = const [];
  List<Machine> _dryers = const [];
  List<Machine> _ironingStations = const [];
  final List<_ScannedLaundryTag> _scannedTags = [];
  final List<GarmentItem> _garmentItems = [];
  ActiveOrderSession? _activeSession;
  Timer? _sessionTimer;

  bool get _includesWashing =>
      _selectedServices.contains(LaundryService.washing);

  bool get _includesDrying => _selectedServices.contains(LaundryService.drying);

  bool get _includesIroning =>
      _selectedServices.contains(LaundryService.ironing);

  bool get _hasGarmentItems => _garmentItems.isNotEmpty;

  Set<String> get _garmentSelectedServices =>
      _garmentItems.expand((item) => item.selectedServices).toSet();

  int get _garmentPieceCount =>
      _garmentItems.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _garmentManifestTotal => _garmentItems.fold<double>(
        0,
        (sum, item) => sum + item.lineTotal,
      );

  double get _estimatedAmount {
    if (_hasGarmentItems) {
      return _garmentManifestTotal;
    }
    return [
      _includesWashing ? _selectedWasher?.price : null,
      _includesDrying ? _selectedDryer?.price : null,
      _includesIroning ? _selectedIroningStation?.price : null,
    ].whereType<double>().fold<double>(0, (sum, value) => sum + value);
  }

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
    _barcodeController.dispose();
    super.dispose();
  }

  List<Machine> _uniqueMachinesById(Iterable<Machine> machines) {
    final uniqueById = <int, Machine>{};
    for (final machine in machines) {
      uniqueById[machine.id] = machine;
    }
    return uniqueById.values.toList();
  }

  Machine? _selectionFromList(List<Machine> machines, Machine? selected) {
    if (machines.isEmpty) {
      return null;
    }
    if (selected == null) {
      return machines.first;
    }
    for (final machine in machines) {
      if (machine.id == selected.id) {
        return machine;
      }
    }
    return machines.first;
  }

  Future<void> _loadMachines() async {
    final machines = await widget.repository.getMachines();
    if (!mounted) {
      return;
    }
    final washers = _uniqueMachinesById(
      machines.where((machine) => machine.type == 'Washer'),
    );
    final dryers = _uniqueMachinesById(
      machines.where((machine) => machine.type == 'Dryer'),
    );
    final ironingStations = _uniqueMachinesById(
      machines.where((machine) => machine.type == Machine.ironingStationType),
    );
    setState(() {
      _washers = washers;
      _dryers = dryers;
      _ironingStations = ironingStations;
      _selectedWasher = _selectionFromList(_washers, _selectedWasher);
      _selectedDryer = _selectionFromList(_dryers, _selectedDryer);
      _selectedIroningStation =
          _selectionFromList(_ironingStations, _selectedIroningStation);
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
        left.customerPhone == right.customerPhone &&
        left.garmentItems.length == right.garmentItems.length;
  }

  Future<void> _submitOrderDraft() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final requiresWashing = _includesWashing;
    final requiresDrying = _includesDrying;
    final requiresIroning = _includesIroning;

    if (!isValid || _selectedServices.isEmpty) {
      return;
    }
    if (requiresWashing && _selectedWasher == null) {
      _showFormMessage('Select a washer for the washing service.');
      return;
    }
    if (requiresDrying && _selectedDryer == null) {
      _showFormMessage('Select a dryer for the drying service.');
      return;
    }
    if (requiresIroning && _selectedIroningStation == null) {
      _showFormMessage('Select an ironing station for the ironing service.');
      return;
    }

    setState(() {
      _saving = true;
    });

    final session = await widget.repository.saveActiveOrderDraft(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      loadSizeKg: _loadSizeKg,
      selectedServices: _selectedServices.toList(),
      garmentItems: List<GarmentItem>.from(_garmentItems),
      washOption: requiresWashing ? _washOption : null,
      washer: requiresWashing ? _selectedWasher : null,
      dryer: requiresDrying ? _selectedDryer : null,
      ironingStation: requiresIroning ? _selectedIroningStation : null,
      paymentMethod: _paymentMethod,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _saving = false;
      _activeSession = session;
    });

    _showFormMessage(
      'Order details are now visible on both operator and customer screens.',
    );
  }

  void _showFormMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _nearestLoadSize(int inputKg) {
    var nearest = _loadSizes.first;
    var bestDistance = (nearest - inputKg).abs();
    for (final size in _loadSizes.skip(1)) {
      final distance = (size - inputKg).abs();
      if (distance < bestDistance) {
        nearest = size;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  double _serviceRate(String service) => _garmentServiceRates[service] ?? 0;

  void _syncSelectedServicesFromGarments() {
    if (_garmentItems.isEmpty) {
      return;
    }
    _selectedServices
      ..clear()
      ..addAll(_garmentSelectedServices);
  }

  void _applyScannedTag(_ScannedLaundryTag tag) {
    final existingIndex = _scannedTags.indexWhere(
      (entry) => entry.deduplicationKey == tag.deduplicationKey,
    );
    if (existingIndex != -1) {
      _showFormMessage(
          'Tag ${tag.displayLabel} is already in this order draft.');
      return;
    }

    final updatedServices = {..._selectedServices, ...tag.selectedServices};

    setState(() {
      _scannedTags.add(tag);
      _garmentItems.add(
        _garmentItemFromTag(
          tag,
          fallbackServices: updatedServices.isEmpty
              ? const {LaundryService.washing}
              : updatedServices,
          resolveServiceRate: _serviceRate,
        ),
      );

      if (tag.customerName != null &&
          _customerNameController.text.trim().isEmpty) {
        _customerNameController.text = tag.customerName!;
      }
      if (tag.customerPhone != null &&
          _customerPhoneController.text.trim().isEmpty) {
        _customerPhoneController.text = tag.customerPhone!;
      }
      _selectedServices
        ..clear()
        ..addAll(updatedServices);
      if (tag.loadSizeKg != null) {
        _loadSizeKg = _nearestLoadSize(tag.loadSizeKg!);
      }
      if (tag.washOption != null) {
        _washOption = tag.washOption!;
      }
      if (tag.paymentMethod != null) {
        _paymentMethod = tag.paymentMethod!;
      }
      _syncSelectedServicesFromGarments();
    });

    final appliedDetails = <String>[
      if (tag.customerName != null) 'customer',
      if (tag.customerPhone != null) 'phone',
      if (tag.selectedServices.isNotEmpty) 'services',
      if (tag.loadSizeKg != null) 'load size',
      if (tag.washOption != null) 'wash option',
      if (tag.paymentMethod != null) 'payment method',
    ];
    _showFormMessage(
      appliedDetails.isEmpty
          ? 'Tag ${tag.displayLabel} was recorded. No order fields were found in the barcode payload.'
          : 'Tag ${tag.displayLabel} applied ${appliedDetails.join(', ')} to the order draft.',
    );
  }

  void _scanBarcodeInput() {
    final raw = _barcodeController.text.trim();
    if (raw.isEmpty) {
      _showFormMessage('Scan or enter a barcode first.');
      return;
    }

    final tag = _ScannedLaundryTag.parse(
      raw,
      washOptions: _washOptions,
      paymentMethods: _paymentMethods,
    );
    _barcodeController.clear();

    if (tag == null) {
      _showFormMessage(
        'Barcode could not be parsed. Use JSON or WASHPOS|key=value tag format.',
      );
      return;
    }

    _applyScannedTag(tag);
  }

  void _clearScannedTags() {
    setState(() {
      _scannedTags.clear();
      _garmentItems.clear();
    });
    _showFormMessage(
        'Scanned garment tags and garment rows were cleared from this draft.');
  }

  Future<void> _addManualGarmentRow() async {
    final garmentController = TextEditingController();
    var quantity = 1;
    final selectedServices = <String>{
      if (_selectedServices.isNotEmpty) ..._selectedServices else LaundryService.washing,
    };

    final created = await showDialog<GarmentItem>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Garment Row'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: garmentController,
                      decoration: const InputDecoration(
                        labelText: 'Garment label',
                        hintText: 'Example: Shirt, Saree, Trouser',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Quantity'),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: quantity > 1
                              ? () => setDialogState(() {
                                    quantity -= 1;
                                  })
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$quantity',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          onPressed: () => setDialogState(() {
                            quantity += 1;
                          }),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LaundryService.washing,
                        LaundryService.drying,
                        LaundryService.ironing,
                      ]
                          .map(
                            (service) => FilterChip(
                              label: Text(service),
                              selected: selectedServices.contains(service),
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedServices.add(service);
                                  } else if (selectedServices.length > 1) {
                                    selectedServices.remove(service);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final garmentLabel = garmentController.text.trim();
                    if (garmentLabel.isEmpty) {
                      return;
                    }
                    final orderedServices = [
                      LaundryService.washing,
                      LaundryService.drying,
                      LaundryService.ironing,
                    ].where(selectedServices.contains).toList();
                    Navigator.of(dialogContext).pop(
                      GarmentItem(
                        tagId:
                            'TAG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                        garmentLabel: garmentLabel,
                        quantity: quantity,
                        selectedServices: orderedServices,
                        unitPrice: _calculateGarmentUnitPrice(
                          orderedServices,
                          resolveServiceRate: _serviceRate,
                        ),
                        status: GarmentItemStatus.received,
                        sourceDeduplicationKey:
                            'MANUAL-${DateTime.now().microsecondsSinceEpoch}',
                      ),
                    );
                  },
                  child: const Text('Add Row'),
                ),
              ],
            );
          },
        );
      },
    );

    garmentController.dispose();

    if (created == null || !mounted) {
      return;
    }

    setState(() {
      _garmentItems.add(created);
      _selectedServices
        ..clear()
        ..addAll(_garmentSelectedServices);
    });
    _showFormMessage('${created.garmentLabel} added to the garment manifest.');
  }

  void _updateGarmentQuantity(GarmentItem item, int nextQuantity) {
    if (nextQuantity < 1) {
      return;
    }
    setState(() {
      final index = _garmentItems.indexOf(item);
      if (index == -1) {
        return;
      }
      _garmentItems[index] = item.copyWith(quantity: nextQuantity);
    });
  }

  void _toggleGarmentService(GarmentItem item, String service) {
    final nextServices = [...item.selectedServices];
    if (nextServices.contains(service)) {
      if (nextServices.length == 1) {
        _showFormMessage('Each garment item needs at least one service.');
        return;
      }
      nextServices.remove(service);
    } else {
      nextServices.add(service);
    }

    setState(() {
      final index = _garmentItems.indexOf(item);
      if (index == -1) {
        return;
      }
      _garmentItems[index] = item.copyWith(
        selectedServices: nextServices,
        unitPrice: _calculateGarmentUnitPrice(
          nextServices,
          resolveServiceRate: _serviceRate,
        ),
      );
      _syncSelectedServicesFromGarments();
    });
  }

  void _removeGarmentItem(GarmentItem item) {
    setState(() {
      _garmentItems.remove(item);
      _scannedTags.removeWhere(
        (tag) => tag.deduplicationKey == item.sourceDeduplicationKey,
      );
      _syncSelectedServicesFromGarments();
    });
    _showFormMessage('${item.garmentLabel} removed from the garment list.');
  }

  void _toggleService(String service, bool selected) {
    setState(() {
      if (selected) {
        _selectedServices.add(service);
      } else {
        _selectedServices.remove(service);
      }
    });
  }

  IconData _serviceIcon(String service) {
    switch (service) {
      case LaundryService.washing:
        return Icons.local_laundry_service_outlined;
      case LaundryService.drying:
        return Icons.dry_outlined;
      default:
        return Icons.iron_outlined;
    }
  }

  String _serviceDescription(String service) {
    switch (service) {
      case LaundryService.washing:
        return 'Select the washer and wash program for this order.';
      case LaundryService.drying:
        return 'Add drying when the customer needs a full wash-to-dry cycle.';
      default:
        return 'Add ironing when the customer needs finishing after laundry.';
    }
  }

  Color _serviceColor(String service) {
    switch (service) {
      case LaundryService.washing:
        return const Color(0xFF0E7490);
      case LaundryService.drying:
        return const Color(0xFFC86B3C);
      default:
        return const Color(0xFF8F5DB7);
    }
  }

  String _serviceMachineLabel(String label, Machine? machine) {
    if (machine == null) {
      return '$label not assigned';
    }
    return '$label: ${machine.name}';
  }

  GarmentItem _garmentItemFromTag(
    _ScannedLaundryTag tag, {
    required Set<String> fallbackServices,
    required double Function(String service) resolveServiceRate,
  }) {
    final services = tag.selectedServices.isEmpty
        ? fallbackServices.toList()
        : tag.selectedServices;
    final calculatedUnitPrice = tag.unitPrice ??
        _calculateGarmentUnitPrice(
          services,
          resolveServiceRate: resolveServiceRate,
        );
    return GarmentItem(
      tagId: tag.displayLabel,
      garmentLabel: tag.garmentName ?? 'Tagged Garment',
      quantity: tag.quantity == null || tag.quantity! < 1 ? 1 : tag.quantity!,
      selectedServices: services,
      unitPrice: calculatedUnitPrice,
      status: GarmentItemStatus.received,
      sourceDeduplicationKey: tag.deduplicationKey,
    );
  }

  double _calculateGarmentUnitPrice(
    List<String> services, {
    required double Function(String service) resolveServiceRate,
  }) {
    return services.fold<double>(
      0,
      (sum, service) => sum + resolveServiceRate(service),
    );
  }

  Widget _buildServiceSelector() {
    final services = [
      LaundryService.washing,
      LaundryService.drying,
      LaundryService.ironing,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final compact = constraints.maxWidth < 920;
        final columns = compact ? 1 : 3;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: services.map((service) {
            final selected = _selectedServices.contains(service);
            final color = _serviceColor(service);
            return SizedBox(
              width: width,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _saving || _hasGarmentItems
                    ? null
                    : () => _toggleService(service, !selected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? color
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Icon(_serviceIcon(service), color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              service,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Checkbox(
                            value: selected,
                            onChanged: _saving || _hasGarmentItems
                                ? null
                                : (value) => _toggleService(
                                      service,
                                      value ?? false,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _serviceDescription(service),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBarcodeScannerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_scanner_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Garment Tag Scanner',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_scannedTags.isNotEmpty)
                TextButton.icon(
                  onPressed: _saving ? null : _clearScannedTags,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Tags'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the barcode on each laundry tag to prefill the order. This works well with USB or handheld barcode scanners that type into the field below.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _barcodeController,
                  enabled: !_saving,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Scan garment tag barcode',
                    hintText:
                        'Example: WASHPOS|tag=TAG-1001|customer=Ravi|phone=9876543210|services=Washing+Drying|load=10',
                  ),
                  onFieldSubmitted: (_) => _scanBarcodeInput(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _scanBarcodeInput,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Apply Scan'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Supported payloads: JSON like {"customerName":"Asha","selectedServices":["Washing"]} or pipe tags like WASHPOS|customer=Asha|phone=9876543210|services=Washing+Ironing|load=8.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4B6475),
                ),
          ),
          if (_scannedTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _scannedTags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag.displayLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (tag.selectedServices.isNotEmpty)
                            Text(
                              'Services: ${tag.selectedServices.join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (tag.loadSizeKg != null)
                            Text(
                              'Load: ${tag.loadSizeKg}kg',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (tag.customerName != null)
                            Text(
                              tag.customerName!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGarmentManifestCard() {
    final serviceOptions = [
      LaundryService.washing,
      LaundryService.drying,
      LaundryService.ironing,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Garment Line Items',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan garment tags or add rows manually. Each row becomes an editable garment entry that can later print one taffeta tag per piece.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _addManualGarmentRow,
                icon: const Icon(Icons.add_outlined),
                label: const Text('Add Garment Row'),
              ),
              if (_scannedTags.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _saving ? null : _clearScannedTags,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear Scanned Tags'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_garmentItems.isEmpty)
            const Text(
              'No garment rows added yet. Scan tags above or add rows manually to build a per-piece order manifest.',
            )
          else ...[
            ..._garmentItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.garmentLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tag: ${item.tagId}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => _removeGarmentItem(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _updateGarmentQuantity(
                                              item,
                                              item.quantity - 1,
                                            ),
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  IconButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _updateGarmentQuantity(
                                              item,
                                              item.quantity + 1,
                                            ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Unit: INR ${item.unitPrice.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Line total: INR ${item.lineTotal.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: serviceOptions
                              .map(
                                (service) => FilterChip(
                                  label: Text(
                                    '$service (INR ${_serviceRate(service).toStringAsFixed(0)})',
                                  ),
                                  selected:
                                      item.selectedServices.contains(service),
                                  onSelected: _saving
                                      ? null
                                      : (_) => _toggleGarmentService(
                                            item,
                                            service,
                                          ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  Text('Rows: ${_garmentItems.length}'),
                  Text('Pieces: $_garmentPieceCount'),
                  Text(
                    'Manifest total: INR ${_garmentManifestTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceConfigurationCard({
    required String title,
    required String service,
    required List<Widget> children,
  }) {
    final color = _serviceColor(service);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_serviceIcon(service), color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDraftSummaryCard() {
    final selectedServices = _selectedServices.toList();
    final estimatedAmount = _estimatedAmount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5F73), Color(0xFF18829A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Preview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'The order will be built from the selected services and machine assignments below.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: selectedServices.isEmpty
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Select at least one service',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ]
                : selectedServices
                    .map(
                      (service) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _serviceIcon(service),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              service,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 18),
          if (_hasGarmentItems) ...[
            Text(
              'Garment manifest',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_garmentItems.length} rows • $_garmentPieceCount pieces • INR ${_garmentManifestTotal.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Load size: $_loadSizeKg kg',
            style: const TextStyle(color: Colors.white),
          ),
          if (_includesWashing)
            Text(
              _serviceMachineLabel('Washer', _selectedWasher),
              style: const TextStyle(color: Colors.white),
            ),
          if (_includesDrying)
            Text(
              _serviceMachineLabel('Dryer', _selectedDryer),
              style: const TextStyle(color: Colors.white),
            ),
          if (_includesIroning)
            Text(
              _serviceMachineLabel('Ironing station', _selectedIroningStation),
              style: const TextStyle(color: Colors.white),
            ),
          if (_includesWashing)
            Text(
              'Wash option: $_washOption',
              style: const TextStyle(color: Colors.white),
            ),
          Text(
            'Payment method: $_paymentMethod',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(
            _hasGarmentItems
                ? 'Machine-backed checkout estimate'
                : 'Estimated order total',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            estimatedAmount > 0
                ? 'INR ${estimatedAmount.toStringAsFixed(0)}'
                : 'Select services to calculate total',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.delivered:
        return 'Delivered';
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
      case OrderStatus.readyForPickup:
        return const Color(0xFF2A9D8F);
      case OrderStatus.delivered:
        return const Color(0xFF3F8CFF);
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

  Machine? _findMachineById(int? id) {
    if (id == null) {
      return null;
    }
    final combined = [..._washers, ..._dryers, ..._ironingStations];
    for (final machine in combined) {
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
      appBar: AppBar(title: Text(context.l10n.orders)),
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
        _buildWorkflowActionCard(),
        const SizedBox(height: 16),
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
                    'Choose the laundry services this customer needs, assign the machines or station for each selected service, and then push the draft order to both screens for confirmation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _buildBarcodeScannerCard(),
                  const SizedBox(height: 16),
                  _buildGarmentManifestCard(),
                  const SizedBox(height: 16),
                  CustomerDetailsForm(
                    nameController: _customerNameController,
                    phoneController: _customerPhoneController,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Services',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasGarmentItems
                              ? 'Scanned garment rows now drive the order services below. Update services per garment in the manifest to keep the order accurate.'
                              : 'Washing, drying, and ironing are independent services. The order will be built from whichever services you select here.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        _buildServiceSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
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
                  if (_includesWashing) ...[
                    _buildServiceConfigurationCard(
                      title: 'Washing Service',
                      service: LaundryService.washing,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _washOption,
                          decoration: const InputDecoration(
                            labelText: 'Wash option',
                          ),
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
                          decoration: const InputDecoration(
                            labelText: 'Assign washer',
                          ),
                          items: _washers
                              .map(
                                (machine) => DropdownMenuItem<Machine>(
                                  value: machine,
                                  child: Text(
                                    '${machine.name} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_includesDrying) ...[
                    _buildServiceConfigurationCard(
                      title: 'Drying Service',
                      service: LaundryService.drying,
                      children: [
                        DropdownButtonFormField<Machine>(
                          initialValue: _selectedDryer,
                          decoration: const InputDecoration(
                            labelText: 'Assign dryer',
                          ),
                          items: _dryers
                              .map(
                                (machine) => DropdownMenuItem<Machine>(
                                  value: machine,
                                  child: Text(
                                    '${machine.name} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
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
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_includesIroning) ...[
                    _buildServiceConfigurationCard(
                      title: 'Ironing Service',
                      service: LaundryService.ironing,
                      children: [
                        DropdownButtonFormField<Machine>(
                          initialValue: _selectedIroningStation,
                          decoration: const InputDecoration(
                            labelText: 'Assign ironing station',
                          ),
                          items: _ironingStations
                              .map(
                                (machine) => DropdownMenuItem<Machine>(
                                  value: machine,
                                  child: Text(
                                    '${machine.name} • ${machine.capacityKg}kg • INR ${machine.price.toStringAsFixed(0)}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedIroningStation = value;
                                  });
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
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
                  const SizedBox(height: 20),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _buildDraftSummaryCard(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submitOrderDraft,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(
                        _saving ? 'Preparing checkout...' : 'Order Checkout',
                      ),
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
    final washer = _findMachineById(session.washerMachineId);
    final dryer = _findMachineById(session.dryerMachineId);
    final ironing = _findMachineById(session.ironingMachineId);
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
            Text('Services: ${session.selectedServices.join(', ')}'),
            if (session.garmentItems.isNotEmpty)
              Text(
                'Garments: ${session.garmentItems.length} rows • ${session.garmentItems.fold<int>(0, (sum, item) => sum + item.quantity)} pieces',
              ),
            if (session.washOption != null)
              Text('Wash option: ${session.washOption}'),
            if (session.includesWashing)
              Text(
                'Washer assigned: ${washer?.name ?? 'Washer ${session.washerMachineId}'}',
              ),
            if (session.includesDrying)
              Text(
                'Dryer assigned: ${dryer?.name ?? 'Dryer ${session.dryerMachineId}'}',
              ),
            if (session.includesIroning)
              Text(
                'Ironing assigned: ${ironing?.name ?? 'Station ${session.ironingMachineId}'}',
              ),
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
                                if (item.order.garmentItems.isNotEmpty)
                                  Text(
                                    'Garments: ${item.order.garmentItems.length} rows • ${item.order.garmentItems.fold<int>(0, (sum, entry) => sum + entry.quantity)} pieces',
                                  ),
                                Text(
                                  'Services: ${item.order.selectedServices.join(', ')}',
                                ),
                                if (item.order.washOption != null)
                                  Text(
                                    'Wash option: ${item.order.washOption}',
                                  ),
                                if (item.order.selectedServices.contains(
                                  LaundryService.washing,
                                ))
                                  Text('Washer assigned: ${item.machine.name}'),
                                if (item.order.selectedServices.contains(
                                  LaundryService.drying,
                                ))
                                  Text(
                                    'Dryer assigned: ${item.dryerMachine?.name ?? 'Not assigned'}',
                                  ),
                                if (item.order.selectedServices.contains(
                                  LaundryService.ironing,
                                ))
                                  Text(
                                    'Ironing assigned: ${item.ironingMachine?.name ?? 'Not assigned'}',
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

  Widget _buildWorkflowActionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Order Flow Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This checklist follows the laundromat intake-to-delivery process and is now the basis for the piece-level order implementation.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...List.generate(_workflowActions.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_workflowActions[index])),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ScannedLaundryTag {
  const _ScannedLaundryTag({
    required this.rawCode,
    required this.selectedServices,
    this.tagId,
    this.garmentName,
    this.customerName,
    this.customerPhone,
    this.quantity,
    this.loadSizeKg,
    this.unitPrice,
    this.washOption,
    this.paymentMethod,
  });

  final String rawCode;
  final String? tagId;
  final String? garmentName;
  final String? customerName;
  final String? customerPhone;
  final int? quantity;
  final int? loadSizeKg;
  final List<String> selectedServices;
  final double? unitPrice;
  final String? washOption;
  final String? paymentMethod;

  String get deduplicationKey => (tagId ?? rawCode).trim().toUpperCase();

  String get displayLabel => tagId ?? rawCode;

  static _ScannedLaundryTag? parse(
    String raw, {
    required List<String> washOptions,
    required List<String> paymentMethods,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final jsonTag = _parseJson(
      trimmed,
      washOptions: washOptions,
      paymentMethods: paymentMethods,
    );
    if (jsonTag != null) {
      return jsonTag;
    }

    final pipeTag = _parsePipeDelimited(
      trimmed,
      washOptions: washOptions,
      paymentMethods: paymentMethods,
    );
    if (pipeTag != null) {
      return pipeTag;
    }

    return _ScannedLaundryTag(
      rawCode: trimmed,
      tagId: trimmed,
      selectedServices: const [],
    );
  }

  static _ScannedLaundryTag? _parseJson(
    String raw, {
    required List<String> washOptions,
    required List<String> paymentMethods,
  }) {
    if (!raw.startsWith('{')) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _fromMap(
        raw: raw,
        map: decoded,
        washOptions: washOptions,
        paymentMethods: paymentMethods,
      );
    } catch (_) {
      return null;
    }
  }

  static _ScannedLaundryTag? _parsePipeDelimited(
    String raw, {
    required List<String> washOptions,
    required List<String> paymentMethods,
  }) {
    if (!raw.contains('|')) {
      return null;
    }

    final parts = raw.split('|');
    final map = <String, dynamic>{};
    for (final part in parts) {
      final separatorIndex = part.indexOf('=');
      if (separatorIndex == -1) {
        continue;
      }
      final key = part.substring(0, separatorIndex).trim();
      final value = part.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      map[key] = value;
    }
    if (map.isEmpty) {
      return null;
    }
    return _fromMap(
      raw: raw,
      map: map,
      washOptions: washOptions,
      paymentMethods: paymentMethods,
    );
  }

  static _ScannedLaundryTag _fromMap({
    required String raw,
    required Map<String, dynamic> map,
    required List<String> washOptions,
    required List<String> paymentMethods,
  }) {
    String? readString(List<String> keys) {
      for (final key in keys) {
        for (final entry in map.entries) {
          if (entry.key.toLowerCase() != key.toLowerCase()) {
            continue;
          }
          final value = entry.value;
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
      return null;
    }

    int? readInt(List<String> keys) {
      final text = readString(keys);
      if (text == null) {
        return null;
      }
      return int.tryParse(text);
    }

    List<String> readServices() {
      final values = <String>[];
      final directValue = map['selectedServices'] ?? map['services'];
      if (directValue is List) {
        for (final item in directValue) {
          if (item is String) {
            values.add(item);
          }
        }
      } else {
        final text = readString(
          const ['selectedServices', 'services', 'service', 'serviceCodes'],
        );
        if (text != null) {
          values.addAll(text.split(RegExp(r'[,+/]')));
        }
      }

      final normalized = <String>[];
      for (final item in values) {
        final service = _normalizeService(item);
        if (service != null && !normalized.contains(service)) {
          normalized.add(service);
        }
      }
      return normalized;
    }

    return _ScannedLaundryTag(
      rawCode: raw,
      tagId: readString(const ['tagId', 'tag', 'id', 'barcode']),
      garmentName: readString(
        const ['garmentName', 'garment', 'itemName', 'pieceType'],
      ),
      customerName: readString(
        const ['customerName', 'customer', 'name', 'customer_name'],
      ),
      customerPhone: readString(
        const ['customerPhone', 'phone', 'mobile', 'customer_phone'],
      ),
      quantity: readInt(const ['quantity', 'qty', 'pieces']),
      loadSizeKg: readInt(const ['loadSizeKg', 'load', 'kg']),
      selectedServices: readServices(),
      unitPrice: () {
        final text = readString(const ['unitPrice', 'price', 'rate']);
        if (text == null) {
          return null;
        }
        return double.tryParse(text);
      }(),
      washOption: _normalizeOption(
        readString(const ['washOption', 'wash', 'program']),
        supportedOptions: washOptions,
      ),
      paymentMethod: _normalizeOption(
        readString(const ['paymentMethod', 'payment', 'method']),
        supportedOptions: paymentMethods,
      ),
    );
  }

  static String? _normalizeService(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('wash')) {
      return LaundryService.washing;
    }
    if (normalized.contains('dry')) {
      return LaundryService.drying;
    }
    if (normalized.contains('iron') || normalized.contains('press')) {
      return LaundryService.ironing;
    }
    return null;
  }

  static String? _normalizeOption(
    String? raw, {
    required List<String> supportedOptions,
  }) {
    if (raw == null) {
      return null;
    }
    final normalized = raw.trim().toLowerCase();
    for (final option in supportedOptions) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }
    if (supportedOptions.contains('UPI QR') && normalized == 'upi') {
      return 'UPI QR';
    }
    if (supportedOptions.contains('Specific Wash') &&
        normalized == 'specific') {
      return 'Specific Wash';
    }
    if (supportedOptions.contains('Gentle Wash') && normalized == 'gentle') {
      return 'Gentle Wash';
    }
    return null;
  }
}
