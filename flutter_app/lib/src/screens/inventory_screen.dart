import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../models/inventory.dart';
import '../widgets/inventory_category_icon.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.repository,
  });

  final PosRepository repository;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  InventoryDashboard? _dashboard;
  List<InventoryItem> _items = const [];
  bool _loadingDashboard = true;
  bool _loadingItems = true;
  String? _selectedCategory;
  String? _selectedStockStatus;
  String? _selectedSupplier;
  String? _selectedBranch;
  String? _selectedLocation;
  String _sortBy = 'reorderUrgency';
  String _sortOrder = 'desc';
  Timer? _searchDebounce;
  int? _creatingRestockRequestItemId;
  final Set<int> _expandedItemIds = <int>{};
  final Set<int> _loadingMovementItemIds = <int>{};
  final Map<int, List<InventoryStockMovement>> _movementHistoryByItemId = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadItems();
  }

  Future<void> _toggleItemDetails(InventoryItem item) async {
    final shouldExpand = !_expandedItemIds.contains(item.id);
    setState(() {
      if (shouldExpand) {
        _expandedItemIds.add(item.id);
      } else {
        _expandedItemIds.remove(item.id);
      }
    });

    if (!shouldExpand || _movementHistoryByItemId.containsKey(item.id)) {
      return;
    }

    setState(() {
      _loadingMovementItemIds.add(item.id);
    });

    try {
      final history = await widget.repository.getInventoryItemMovements(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _movementHistoryByItemId[item.id] = history;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMovementItemIds.remove(item.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingDashboard = true;
    });
    final dashboard = await widget.repository.getInventoryDashboard();
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboard = dashboard;
      _loadingDashboard = false;
    });
  }

  Future<void> _loadItems() async {
    setState(() {
      _loadingItems = true;
    });
    final items = await widget.repository.getInventoryItems(
      searchQuery: _searchController.text,
      category: _selectedCategory,
      stockStatus: _selectedStockStatus,
      supplier: _selectedSupplier,
      branch: _selectedBranch,
      location: _selectedLocation,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loadingItems = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadDashboard(),
      _loadItems(),
    ]);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadItems);
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    _loadItems();
  }

  void _updateFilters({
    String? stockStatus,
    String? supplier,
    String? branch,
    String? location,
    String? sortBy,
    String? sortOrder,
    bool clear = false,
  }) {
    setState(() {
      if (clear) {
        _searchController.clear();
        _selectedCategory = null;
        _selectedStockStatus = null;
        _selectedSupplier = null;
        _selectedBranch = null;
        _selectedLocation = null;
        _sortBy = 'reorderUrgency';
        _sortOrder = 'desc';
      } else {
        _selectedStockStatus = stockStatus ?? _selectedStockStatus;
        _selectedSupplier = supplier ?? _selectedSupplier;
        _selectedBranch = branch ?? _selectedBranch;
        _selectedLocation = location ?? _selectedLocation;
        _sortBy = sortBy ?? _sortBy;
        _sortOrder = sortOrder ?? _sortOrder;
      }
    });
    _loadItems();
  }

  Future<void> _createRestockRequest(InventoryItem item) async {
    setState(() {
      _creatingRestockRequestItemId = item.id;
    });

    try {
      final requestedQuantity = item.reorderPoint > 0 ? item.reorderPoint : 1;
      await widget.repository.createInventoryRestockRequest(
        inventoryItemId: item.id,
        requestedQuantity: requestedQuantity,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restock request created for ${item.name}. It is now awaiting operator approval.',
          ),
        ),
      );
      await _refreshAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create restock request: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creatingRestockRequestItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final categories =
        dashboard?.categories ?? const <InventoryCategorySummary>[];
    final metrics = dashboard?.metrics;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E7C93), Color(0xFF29A6BB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x221E7C93),
                    blurRadius: 20,
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
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Dashboard',
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
                          'Track stock risk, pending replenishment, and item movement from one screen, then narrow into the exact items that need action.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      _InventorySummaryPill(
                        label: 'Categories',
                        value: '${categories.length}',
                      ),
                      _InventorySummaryPill(
                        label: 'Visible Items',
                        value: '${_items.length}',
                      ),
                      _InventorySummaryPill(
                        label: 'Selected',
                        value: _selectedCategory ?? 'All',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_loadingDashboard || metrics == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InventoryMetricCard(
                    label: 'Low Stock',
                    value: '${metrics.lowStockCount}',
                    accent: const Color(0xFFD18A2C),
                  ),
                  _InventoryMetricCard(
                    label: 'Out Of Stock',
                    value: '${metrics.outOfStockCount}',
                    accent: const Color(0xFFC54141),
                  ),
                  _InventoryMetricCard(
                    label: 'Stock Value',
                    value: 'INR ${metrics.stockValue.toStringAsFixed(0)}',
                    accent: const Color(0xFF2C9A65),
                  ),
                  _InventoryMetricCard(
                    label: 'Pending POs',
                    value: '${metrics.pendingPurchaseOrders}',
                    accent: const Color(0xFF5E7CE2),
                  ),
                  _InventoryMetricCard(
                    label: 'Expiring Soon',
                    value: '${metrics.expiringSoonCount}',
                    accent: const Color(0xFFA54CC9),
                  ),
                ],
              ),
            const SizedBox(height: 28),
            Text(
              'Category Options',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep the compact category shortcuts, but use them as a filter over the full inventory dataset.',
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
                  children: categories
                      .map(
                        (category) => SizedBox(
                          width: cardWidth,
                          child: _InventoryCategoryCard(
                            summary: category,
                            selected: _selectedCategory == category.category,
                            onTap: () => _selectCategory(category.category),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Search, Filter, And Sort',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_outlined),
                        hintText: 'Search by item name or SKU',
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadItems();
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _loadItems(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _FilterDropdown(
                          width: 180,
                          label: 'Stock status',
                          value: _selectedStockStatus,
                          items: const [
                            DropdownMenuItem(
                              value: InventoryStockStatus.healthy,
                              child: Text('Healthy'),
                            ),
                            DropdownMenuItem(
                              value: InventoryStockStatus.low,
                              child: Text('Low'),
                            ),
                            DropdownMenuItem(
                              value: InventoryStockStatus.outOfStock,
                              child: Text('Out of stock'),
                            ),
                            DropdownMenuItem(
                              value: InventoryStockStatus.inProcurement,
                              child: Text('In procurement'),
                            ),
                          ],
                          onChanged: (value) =>
                              _updateFilters(stockStatus: value),
                        ),
                        _FilterDropdown(
                          width: 180,
                          label: 'Supplier',
                          value: _selectedSupplier,
                          items: (dashboard?.suppliers ?? const <String>[])
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _updateFilters(supplier: value),
                        ),
                        _FilterDropdown(
                          width: 180,
                          label: 'Branch',
                          value: _selectedBranch,
                          items: (dashboard?.branches ?? const <String>[])
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _updateFilters(branch: value),
                        ),
                        _FilterDropdown(
                          width: 180,
                          label: 'Location',
                          value: _selectedLocation,
                          items: (dashboard?.locations ?? const <String>[])
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _updateFilters(location: value),
                        ),
                        _FilterDropdown(
                          width: 180,
                          label: 'Sort by',
                          value: _sortBy,
                          items: const [
                            DropdownMenuItem(
                              value: 'reorderUrgency',
                              child: Text('Reorder urgency'),
                            ),
                            DropdownMenuItem(
                              value: 'quantity',
                              child: Text('Quantity'),
                            ),
                            DropdownMenuItem(
                              value: 'lastRestockedAt',
                              child: Text('Last restocked'),
                            ),
                          ],
                          onChanged: (value) => _updateFilters(sortBy: value),
                        ),
                        _FilterDropdown(
                          width: 160,
                          label: 'Sort order',
                          value: _sortOrder,
                          items: const [
                            DropdownMenuItem(
                              value: 'desc',
                              child: Text('Descending'),
                            ),
                            DropdownMenuItem(
                              value: 'asc',
                              child: Text('Ascending'),
                            ),
                          ],
                          onChanged: (value) =>
                              _updateFilters(sortOrder: value),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _updateFilters(clear: true),
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _selectedCategory == null
                  ? 'All Inventory Items'
                  : '$_selectedCategory Items',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (_loadingItems)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No inventory items match the current search and filters.',
                  ),
                ),
              )
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InventoryItemCard(
                    item: item,
                    creatingRequest: _creatingRestockRequestItemId == item.id,
                    expanded: _expandedItemIds.contains(item.id),
                    loadingHistory: _loadingMovementItemIds.contains(item.id),
                    movementHistory: _movementHistoryByItemId[item.id] ?? const [],
                    onToggleDetails: () => _toggleItemDetails(item),
                    onCreateRestockRequest:
                        item.stockStatus == InventoryStockStatus.outOfStock &&
                                item.activeRestockRequestId == null
                            ? () => _createRestockRequest(item)
                            : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryMetricCard extends StatelessWidget {
  const _InventoryMetricCard({
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
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _InventoryCategoryCard extends StatelessWidget {
  const _InventoryCategoryCard({
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final InventoryCategorySummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualForCategory(summary.category);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F9FC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? visual.accent : const Color(0xFFE0EAF0),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: InventoryCategoryIcon(
                    type: visual.iconType,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  summary.category,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF223746),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.itemCount} items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({
    required this.item,
    required this.creatingRequest,
    required this.expanded,
    required this.loadingHistory,
    required this.movementHistory,
    required this.onToggleDetails,
    required this.onCreateRestockRequest,
  });

  final InventoryItem item;
  final bool creatingRequest;
  final bool expanded;
  final bool loadingHistory;
  final List<InventoryStockMovement> movementHistory;
  final VoidCallback onToggleDetails;
  final VoidCallback? onCreateRestockRequest;

  @override
  Widget build(BuildContext context) {
    final visual = _visualForCategory(item.category);
    final activeRequestApproved =
        item.activeRestockRequestStatus ==
        InventoryRestockRequestStatus.approved;
    final activeRequestPending =
        item.activeRestockRequestStatus ==
        InventoryRestockRequestStatus.pending;
    final lastRestockedLabel = item.lastRestockedAt == null
        ? 'Not recorded'
        : DateFormat('dd MMM yyyy').format(item.lastRestockedAt!);
    final expiryLabel = item.expiresAt == null
        ? 'No expiry'
        : DateFormat('dd MMM yyyy').format(item.expiresAt!);
    final approvedAtLabel = item.activeRestockApprovedAt == null
        ? 'Awaiting approval'
        : DateFormat('dd MMM yyyy').format(item.activeRestockApprovedAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: InventoryCategoryIcon(
                    type: visual.iconType,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.sku} • ${item.category}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _InventoryStatusChip(status: item.stockStatus),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ItemMeta(
                  label: 'Quantity',
                  value: '${item.quantityOnHand} ${item.unit}',
                ),
                _ItemMeta(
                  label: 'Reorder Point',
                  value: '${item.reorderPoint} ${item.unit}',
                ),
                _ItemMeta(
                  label: 'Stock Value',
                  value: 'INR ${item.stockValue.toStringAsFixed(0)}',
                ),
                _ItemMeta(
                  label: 'Supplier',
                  value: item.supplier ?? 'Unassigned',
                ),
                _ItemMeta(
                  label: 'Branch / Location',
                  value: '${item.branch} / ${item.location}',
                ),
                _ItemMeta(
                  label: 'Last Restocked',
                  value: lastRestockedLabel,
                ),
                _ItemMeta(
                  label: 'Expiry',
                  value: expiryLabel,
                ),
                _ItemMeta(
                  label: 'Urgency',
                  value: '${item.reorderUrgencyScore}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ItemMeta(
                  label: 'Barcode',
                  value: item.barcode ?? 'Not assigned',
                ),
                _ItemMeta(
                  label: 'Pack Size',
                  value: item.packSize ?? 'Not set',
                ),
                _ItemMeta(
                  label: 'Unit Type',
                  value: item.unitType,
                ),
                _ItemMeta(
                  label: 'Par Level',
                  value: '${item.parLevel} ${item.unit}',
                ),
                _ItemMeta(
                  label: 'Selling Price',
                  value: item.sellingPrice == null
                      ? 'Not applicable'
                      : 'INR ${item.sellingPrice!.toStringAsFixed(0)}',
                ),
                _ItemMeta(
                  label: 'Record Status',
                  value: item.isActive ? 'Active' : 'Inactive',
                ),
              ],
            ),
            if (item.stockStatus == InventoryStockStatus.outOfStock ||
                item.stockStatus == InventoryStockStatus.inProcurement) ...[
              const SizedBox(height: 16),
              if (activeRequestApproved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C9A65).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order checkout is approved and the item is now in procurement.',
                        style: const TextStyle(
                          color: Color(0xFF2C9A65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _ItemMeta(
                            label: 'Restock Order',
                            value: item.activeRestockRequestNumber ??
                                '#${item.activeRestockRequestId ?? '-'}',
                          ),
                          _ItemMeta(
                            label: 'Approved Quantity',
                            value:
                                '${item.activeRestockRequestedQuantity ?? 0} ${item.unit}',
                          ),
                          _ItemMeta(
                            label: 'Approved On',
                            value: approvedAtLabel,
                          ),
                        ],
                      ),
                      if ((item.activeRestockOperatorRemarks ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Operator remarks: ${item.activeRestockOperatorRemarks!}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF1F5C41),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (activeRequestPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD78B2E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Restock request has been sent to the operator screen and is awaiting approval.',
                    style: TextStyle(
                      color: Color(0xFFD78B2E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: creatingRequest ? null : onCreateRestockRequest,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    creatingRequest
                        ? 'Creating Restock Request...'
                        : 'Reorder / Restock',
                  ),
                ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onToggleDetails,
              icon: Icon(
                expanded
                    ? Icons.expand_less_outlined
                    : Icons.history_toggle_off_outlined,
              ),
              label: Text(
                expanded ? 'Hide Movement History' : 'Show Movement History',
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 16),
              _MovementLedger(
                loading: loadingHistory,
                history: movementHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementLedger extends StatelessWidget {
  const _MovementLedger({
    required this.loading,
    required this.history,
  });

  final bool loading;
  final List<InventoryStockMovement> history;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Movement History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ledger entries help explain exactly how the current balance was reached.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4B6475),
                ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.isEmpty)
            Text(
              'No movement history recorded yet for this item.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...history.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MovementRow(entry: entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.entry,
  });

  final InventoryStockMovement entry;

  @override
  Widget build(BuildContext context) {
    final movementColor = _movementColor(entry.movementType);
    final quantityLabel = entry.quantityDelta > 0
        ? '+${entry.quantityDelta}'
        : '${entry.quantityDelta}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0EAF0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: movementColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _movementLabel(entry.movementType),
              style: TextStyle(
                color: movementColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _ItemMeta(label: 'Delta', value: quantityLabel),
          _ItemMeta(label: 'Balance', value: '${entry.balanceAfter}'),
          _ItemMeta(
            label: 'When',
            value: DateFormat('dd MMM yyyy').format(entry.occurredAt),
          ),
          _ItemMeta(
            label: 'Reference',
            value: [
              entry.referenceType,
              entry.referenceId,
            ].whereType<String>().where((value) => value.isNotEmpty).join(' • ')
                .trim().isEmpty
                ? 'Manual entry'
                : [
                    entry.referenceType,
                    entry.referenceId,
                  ].whereType<String>().where((value) => value.isNotEmpty).join(' • '),
          ),
          if ((entry.performedByName ?? '').trim().isNotEmpty)
            _ItemMeta(label: 'By', value: entry.performedByName!),
          if ((entry.notes ?? '').trim().isNotEmpty)
            SizedBox(
              width: 320,
              child: Text(
                entry.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

Color _movementColor(String movementType) {
  switch (movementType) {
    case InventoryStockMovementType.received:
    case InventoryStockMovementType.returned:
      return const Color(0xFF2C9A65);
    case InventoryStockMovementType.transferred:
      return const Color(0xFF1E7C93);
    case InventoryStockMovementType.damaged:
      return const Color(0xFFC54141);
    case InventoryStockMovementType.manualCorrection:
      return const Color(0xFF7B5CC7);
    case InventoryStockMovementType.consumed:
    default:
      return const Color(0xFFD78B2E);
  }
}

String _movementLabel(String movementType) {
  switch (movementType) {
    case InventoryStockMovementType.received:
      return 'Received';
    case InventoryStockMovementType.consumed:
      return 'Consumed';
    case InventoryStockMovementType.transferred:
      return 'Transferred';
    case InventoryStockMovementType.damaged:
      return 'Damaged';
    case InventoryStockMovementType.returned:
      return 'Returned';
    case InventoryStockMovementType.manualCorrection:
      return 'Manual Correction';
    default:
      return movementType;
  }
}

class _InventoryStatusChip extends StatelessWidget {
  const _InventoryStatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case InventoryStockStatus.inProcurement:
        color = const Color(0xFF1E7C93);
        label = 'In Procurement';
        break;
      case InventoryStockStatus.outOfStock:
        color = const Color(0xFFC54141);
        label = 'Out Of Stock';
        break;
      case InventoryStockStatus.low:
        color = const Color(0xFFD78B2E);
        label = 'Low';
        break;
      default:
        color = const Color(0xFF2C9A65);
        label = 'Healthy';
    }

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

class _ItemMeta extends StatelessWidget {
  const _ItemMeta({
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

class _InventorySummaryPill extends StatelessWidget {
  const _InventorySummaryPill({
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('All'),
          ),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _CategoryVisual {
  const _CategoryVisual({
    required this.iconType,
    required this.accent,
  });

  final InventoryCategoryIconType iconType;
  final Color accent;
}

_CategoryVisual _visualForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'detergent':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.detergent,
        accent: Color(0xFF4EA6E8),
      );
    case 'soap':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.soap,
        accent: Color(0xFFDE9C52),
      );
    case 'liquid':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.liquid,
        accent: Color(0xFF49B97E),
      );
    case 'disinfectant':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.disinfectant,
        accent: Color(0xFF756BDA),
      );
    case 'bleach':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.bleach,
        accent: Color(0xFFE06D6D),
      );
    case 'softener':
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.softener,
        accent: Color(0xFFE07CB0),
      );
    default:
      return const _CategoryVisual(
        iconType: InventoryCategoryIconType.detergent,
        accent: Color(0xFF4EA6E8),
      );
  }
}
