import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../models/active_order_session.dart';
import '../models/machine.dart';
import '../models/pricing.dart';
import '../services/currency_formatter.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({
    super.key,
    required this.repository,
  });

  final PosRepository repository;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM, hh:mm a');

  List<Machine> _machines = const [];
  List<PricingServiceFee> _serviceFees = const [];
  List<PricingCampaign> _campaigns = const [];
  PricingQuote? _latestQuote;
  bool _loading = true;
  String? _loadError;
  int? _selectedWasherId;
  int? _selectedDryerId;
  int? _selectedIroningId;
  final Set<String> _selectedServices = <String>{
    LaundryService.washing,
    LaundryService.drying,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait([
        widget.repository.getMachines(),
        widget.repository.getPricingServiceFees(),
        widget.repository.getPricingCampaigns(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _machines = results[0] as List<Machine>;
        _serviceFees = results[1] as List<PricingServiceFee>;
        _campaigns = results[2] as List<PricingCampaign>;
        _loading = false;
        _loadError = null;
        _selectedWasherId ??= _machines
            .where((machine) => machine.isWasher)
            .map((machine) => machine.id)
            .cast<int?>()
            .firstOrNull;
        _selectedDryerId ??= _machines
            .where((machine) => machine.isDryer)
            .map((machine) => machine.id)
            .cast<int?>()
            .firstOrNull;
        _selectedIroningId ??= _machines
            .where((machine) => machine.isIroningStation)
            .map((machine) => machine.id)
            .cast<int?>()
            .firstOrNull;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError =
            'Pricing data could not be loaded right now. Check backend connectivity and try again.';
      });
    }
  }

  Machine? _machineById(int? id) {
    if (id == null) {
      return null;
    }
    for (final machine in _machines) {
      if (machine.id == id) {
        return machine;
      }
    }
    return null;
  }

  Future<void> _editMachinePrice(Machine machine) async {
    final controller = TextEditingController(text: machine.price.toStringAsFixed(0));
    final nextValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${machine.name} Rate'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Machine price',
            prefixText: CurrencyFormatter.currencyPrefixForContext(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value <= 0) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (nextValue == null) {
      return;
    }

    await widget.repository.updateMachinePrice(
      machineId: machine.id,
      price: nextValue,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${machine.name} updated to ${CurrencyFormatter.formatAmountForContext(context, nextValue)}.',
        ),
      ),
    );
    _loadData(showLoading: false);
  }

  Future<void> _editServiceFee(PricingServiceFee fee) async {
    final controller = TextEditingController(text: fee.amount.toStringAsFixed(0));
    var enabled = fee.isEnabled;
    final result = await showDialog<(double, bool)>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(fee.displayName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile.adaptive(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  onChanged: (value) {
                    setLocalState(() {
                      enabled = value;
                    });
                  },
                ),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Fee amount',
                    prefixText:
                        CurrencyFormatter.currencyPrefixForContext(context),
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
                  final value = double.tryParse(controller.text.trim());
                  if (value == null || value < 0) {
                    return;
                  }
                  Navigator.of(context).pop((value, enabled));
                },
                child: const Text('Update Fee'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (result == null) {
      return;
    }

    await widget.repository.updatePricingServiceFee(
      serviceCode: fee.serviceCode,
      amount: result.$1,
      isEnabled: result.$2,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${fee.displayName} updated.')),
    );
    _loadData(showLoading: false);
  }

  Future<void> _createCampaign() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final discountController = TextEditingController(text: '10');
    final minOrderController = TextEditingController(text: '0');
    String discountType = PricingDiscountType.percent;
    String appliesToService = 'ALL';

    final payload = await showDialog<_CampaignDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Create Campaign'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Campaign name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Discount type'),
                  items: const [
                    DropdownMenuItem(
                      value: PricingDiscountType.percent,
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(
                      value: PricingDiscountType.fixed,
                      child: Text('Flat amount'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      discountType = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: discountType == PricingDiscountType.percent
                        ? 'Discount percent'
                        : 'Discount amount',
                    prefixText: discountType == PricingDiscountType.percent
                        ? null
                        : CurrencyFormatter.currencyPrefixForContext(context),
                    suffixText: discountType == PricingDiscountType.percent ? '%' : null,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: appliesToService,
                  decoration: const InputDecoration(labelText: 'Applies to'),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All services')),
                    DropdownMenuItem(value: LaundryService.washing, child: Text('Washing')),
                    DropdownMenuItem(value: LaundryService.drying, child: Text('Drying')),
                    DropdownMenuItem(value: LaundryService.ironing, child: Text('Ironing')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setLocalState(() {
                      appliesToService = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Minimum order amount',
                    prefixText:
                        CurrencyFormatter.currencyPrefixForContext(context),
                  ),
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
                final discountValue = double.tryParse(discountController.text.trim());
                final minOrder = double.tryParse(minOrderController.text.trim());
                if (nameController.text.trim().isEmpty ||
                    discountValue == null ||
                    discountValue <= 0 ||
                    minOrder == null ||
                    minOrder < 0) {
                  return;
                }
                Navigator.of(context).pop(
                  _CampaignDraft(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    discountType: discountType,
                    discountValue: discountValue,
                    appliesToService: appliesToService,
                    minOrderAmount: minOrder,
                  ),
                );
              },
              child: const Text('Create Campaign'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    discountController.dispose();
    minOrderController.dispose();

    if (payload == null) {
      return;
    }

    await widget.repository.createPricingCampaign(
      name: payload.name,
      description: payload.description,
      discountType: payload.discountType,
      discountValue: payload.discountValue,
      appliesToService: payload.appliesToService,
      minOrderAmount: payload.minOrderAmount,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campaign created successfully.')),
    );
    _loadData(showLoading: false);
  }

  Future<void> _toggleCampaign(PricingCampaign campaign, bool isActive) async {
    await widget.repository.updatePricingCampaign(
      campaignId: campaign.id,
      isActive: isActive,
    );
    if (!mounted) {
      return;
    }
    _loadData(showLoading: false);
  }

  Future<void> _previewQuote() async {
    final quote = await widget.repository.previewPricingQuote(
      washer: _machineById(_selectedWasherId),
      dryer: _machineById(_selectedDryerId),
      ironingStation: _machineById(_selectedIroningId),
      selectedServices: _selectedServices.toList(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _latestQuote = quote;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCampaignCount = _campaigns.where((campaign) => campaign.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Desk'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadData(showLoading: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_problem_outlined,
                          size: 40,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF0E9F8A)],
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
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pricing Control Center',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Finalize and operate four pricing actions from one place: machine rate cards, service fees, promotional campaigns, and live quote preview.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                          _ActionMetricCard(label: 'Rate Cards', value: '${_machines.length}'),
                          _ActionMetricCard(label: 'Service Fees', value: '${_serviceFees.length}'),
                          _ActionMetricCard(label: 'Active Campaigns', value: '$activeCampaignCount'),
                          _ActionMetricCard(
                            label: 'Latest Quote',
                            value: _latestQuote == null
                                ? 'Run Preview'
                                : CurrencyFormatter.formatAmountForContext(
                                    context,
                                    _latestQuote!.finalTotal,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _PricingActionChip(title: '1. Machine Rate Cards'),
                    _PricingActionChip(title: '2. Service Fee Controls'),
                    _PricingActionChip(title: '3. Campaign Management'),
                    _PricingActionChip(title: '4. Quote Preview'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildMachineRatesSection(context),
                const SizedBox(height: 20),
                _buildServiceFeesSection(context),
                const SizedBox(height: 20),
                _buildCampaignsSection(context),
                const SizedBox(height: 20),
                _buildQuoteSection(context),
              ],
                ),
    );
  }

  Widget _buildMachineRatesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Machine Rate Cards', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Update base washer, dryer, and ironing station prices. These rates feed the quote preview and future order totals.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final columns = constraints.maxWidth > 1100
                    ? 3
                    : constraints.maxWidth > 720
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _machines.map((machine) {
                    return SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(machine.name, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text('${machine.type} • ${machine.capacityKg} kg'),
                              const SizedBox(height: 10),
                              Text(
                                CurrencyFormatter.formatAmountForContext(
                                  context,
                                  machine.price,
                                ),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: const Color(0xFF0F766E),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _editMachinePrice(machine),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit Rate'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceFeesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Fee Controls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Manage optional pricing layers on top of the machine rate card. These are applied by selected service and flow into quote totals automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ..._serviceFees.map(
              (fee) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(fee.displayName),
                subtitle: Text(fee.isEnabled ? 'Enabled' : 'Disabled'),
                trailing: FilledButton.tonal(
                  onPressed: () => _editServiceFee(fee),
                  child: Text(
                    CurrencyFormatter.formatAmountForContext(
                      context,
                      fee.amount,
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

  Widget _buildCampaignsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Campaign Management', style: Theme.of(context).textTheme.titleLarge),
                ),
                FilledButton.icon(
                  onPressed: _createCampaign,
                  icon: const Icon(Icons.add),
                  label: const Text('New Campaign'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Launch, pause, and target discounts by service. Active campaigns are applied automatically in quote preview and future order calculations.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_campaigns.isEmpty)
              const Text('No campaigns yet. Create one to test offer-based pricing.')
            else
              ..._campaigns.map(
                (campaign) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                campaign.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Switch.adaptive(
                              value: campaign.isActive,
                              onChanged: (value) => _toggleCampaign(campaign, value),
                            ),
                          ],
                        ),
                        if ((campaign.description ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(campaign.description!),
                          ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _CampaignMeta(label: 'Type', value: campaign.discountType),
                            _CampaignMeta(
                              label: 'Value',
                              value: campaign.discountType == PricingDiscountType.percent
                                  ? '${campaign.discountValue.toStringAsFixed(0)}%'
                                  : CurrencyFormatter.formatAmountForContext(
                                      context,
                                      campaign.discountValue,
                                    ),
                            ),
                            _CampaignMeta(
                              label: 'Scope',
                              value: campaign.appliesToService ?? 'ALL',
                            ),
                            _CampaignMeta(
                              label: 'Min Order',
                              value: CurrencyFormatter.formatAmountForContext(
                                context,
                                campaign.minOrderAmount,
                              ),
                            ),
                            _CampaignMeta(
                              label: 'Updated',
                              value: _dateFormat.format(campaign.updatedAt),
                            ),
                          ],
                        ),
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

  Widget _buildQuoteSection(BuildContext context) {
    final washers = _machines.where((machine) => machine.isWasher).toList();
    final dryers = _machines.where((machine) => machine.isDryer).toList();
    final ironingStations =
        _machines.where((machine) => machine.isIroningStation).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Quote Preview', style: Theme.of(context).textTheme.titleLarge),
                ),
                FilledButton.icon(
                  onPressed: _previewQuote,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Run Preview'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Preview what the final price will look like after machine rates, service fees, and active campaigns are combined.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedWasherId,
                    decoration: const InputDecoration(labelText: 'Washer'),
                    items: washers
                        .map(
                          (machine) => DropdownMenuItem<int?>(
                            value: machine.id,
                            child: Text(
                              '${machine.name} • ${CurrencyFormatter.formatAmountForContext(context, machine.price)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWasherId = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedDryerId,
                    decoration: const InputDecoration(labelText: 'Dryer'),
                    items: dryers
                        .map(
                          (machine) => DropdownMenuItem<int?>(
                            value: machine.id,
                            child: Text(
                              '${machine.name} • ${CurrencyFormatter.formatAmountForContext(context, machine.price)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDryerId = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedIroningId,
                    decoration: const InputDecoration(labelText: 'Ironing'),
                    items: ironingStations
                        .map(
                          (machine) => DropdownMenuItem<int?>(
                            value: machine.id,
                            child: Text(
                              '${machine.name} • ${CurrencyFormatter.formatAmountForContext(context, machine.price)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedIroningId = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ServiceChip(
                  label: 'Washing',
                  selected: _selectedServices.contains(LaundryService.washing),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedServices.add(LaundryService.washing);
                      } else {
                        _selectedServices.remove(LaundryService.washing);
                      }
                    });
                  },
                ),
                _ServiceChip(
                  label: 'Drying',
                  selected: _selectedServices.contains(LaundryService.drying),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedServices.add(LaundryService.drying);
                      } else {
                        _selectedServices.remove(LaundryService.drying);
                      }
                    });
                  },
                ),
                _ServiceChip(
                  label: 'Ironing',
                  selected: _selectedServices.contains(LaundryService.ironing),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedServices.add(LaundryService.ironing);
                      } else {
                        _selectedServices.remove(LaundryService.ironing);
                      }
                    });
                  },
                ),
              ],
            ),
            if (_latestQuote != null) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuoteMetric(label: 'Machines', value: _latestQuote!.machineSubtotal),
                  _QuoteMetric(label: 'Service Fees', value: _latestQuote!.serviceFeeTotal),
                  _QuoteMetric(label: 'Discounts', value: -_latestQuote!.discountTotal),
                  _QuoteMetric(label: 'Final Total', value: _latestQuote!.finalTotal, emphasized: true),
                ],
              ),
              const SizedBox(height: 16),
              ..._latestQuote!.lines.map(
                (line) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.label),
                  subtitle: Text(line.type),
                  trailing: Text(
                    CurrencyFormatter.formatAmountForContext(
                      context,
                      line.amount,
                    ),
                    style: TextStyle(
                      color: line.amount < 0 ? const Color(0xFFB42318) : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampaignDraft {
  const _CampaignDraft({
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.appliesToService,
    required this.minOrderAmount,
  });

  final String name;
  final String? description;
  final String discountType;
  final double discountValue;
  final String? appliesToService;
  final double minOrderAmount;
}

class _ActionMetricCard extends StatelessWidget {
  const _ActionMetricCard({required this.label, required this.value});

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

class _PricingActionChip extends StatelessWidget {
  const _PricingActionChip({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(title),
    );
  }
}

class _CampaignMeta extends StatelessWidget {
  const _CampaignMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _QuoteMetric extends StatelessWidget {
  const _QuoteMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tone = emphasized ? const Color(0xFF0F766E) : const Color(0xFF155E75);
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
          Text(label),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatAmountForContext(context, value),
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
