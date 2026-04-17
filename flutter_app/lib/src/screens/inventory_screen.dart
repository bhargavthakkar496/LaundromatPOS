import 'package:flutter/material.dart';

import '../widgets/inventory_category_icon.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final List<_InventoryCategory> _categories = _seedCategories();
  late _InventoryCategory _selectedCategory = _categories.first;

  List<_InventoryCategory> _seedCategories() {
    return const [
      _InventoryCategory(
        title: 'Detergent',
        shortTitle: 'Detergent',
        iconType: InventoryCategoryIconType.detergent,
        accent: Color(0xFF4EA6E8),
        items: [
          _InventoryItem('Ultra Wash Powder', '5 bags', 'Low', 'Aisle A1'),
          _InventoryItem('Eco Fresh Powder', '14 bags', 'Healthy', 'Aisle A1'),
          _InventoryItem('Front Load Mix', '8 bags', 'Healthy', 'Aisle A2'),
        ],
      ),
      _InventoryCategory(
        title: 'Soap',
        shortTitle: 'Soap',
        iconType: InventoryCategoryIconType.soap,
        accent: Color(0xFFDE9C52),
        items: [
          _InventoryItem('Bar Soap Classic', '22 bars', 'Healthy', 'Aisle B1'),
          _InventoryItem('Fabric Soap Cake', '11 bars', 'Healthy', 'Aisle B1'),
          _InventoryItem('Hand Soap Backup', '4 bars', 'Low', 'Aisle B2'),
        ],
      ),
      _InventoryCategory(
        title: 'Liquid',
        shortTitle: 'Liquid',
        iconType: InventoryCategoryIconType.liquid,
        accent: Color(0xFF49B97E),
        items: [
          _InventoryItem(
              'Liquid Wash Pro', '9 canisters', 'Healthy', 'Aisle C1'),
          _InventoryItem('Express Liquid', '3 canisters', 'Low', 'Aisle C1'),
          _InventoryItem(
              'Wool Care Liquid', '7 canisters', 'Healthy', 'Aisle C2'),
        ],
      ),
      _InventoryCategory(
        title: 'Disinfectant',
        shortTitle: 'Disinfect',
        iconType: InventoryCategoryIconType.disinfectant,
        accent: Color(0xFF756BDA),
        items: [
          _InventoryItem('Surface Guard', '12 bottles', 'Healthy', 'Aisle D1'),
          _InventoryItem('Drum Sanitizer', '6 bottles', 'Healthy', 'Aisle D2'),
          _InventoryItem(
              'Wipe Down Spray', '2 bottles', 'Critical', 'Aisle D1'),
        ],
      ),
      _InventoryCategory(
        title: 'Bleach',
        shortTitle: 'Bleach',
        iconType: InventoryCategoryIconType.bleach,
        accent: Color(0xFFE06D6D),
        items: [
          _InventoryItem(
              'White Bright Bleach', '10 jugs', 'Healthy', 'Aisle E1'),
          _InventoryItem('Heavy Duty Bleach', '5 jugs', 'Low', 'Aisle E2'),
          _InventoryItem('Color Safe Bleach', '8 jugs', 'Healthy', 'Aisle E2'),
        ],
      ),
      _InventoryCategory(
        title: 'Softener',
        shortTitle: 'Softener',
        iconType: InventoryCategoryIconType.softener,
        accent: Color(0xFFE07CB0),
        items: [
          _InventoryItem(
              'Lavender Softener', '13 pouches', 'Healthy', 'Aisle F1'),
          _InventoryItem('Cotton Bloom', '9 pouches', 'Healthy', 'Aisle F1'),
          _InventoryItem('Baby Soft Mix', '4 pouches', 'Low', 'Aisle F2'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCategory;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: ListView(
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
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Categories',
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
                        'Mock stock is seeded by product category so the store manager can browse inventory the same way they use the home dashboard.',
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
                    _InventorySummaryPill(
                      label: 'Categories',
                      value: '${_categories.length}',
                    ),
                    _InventorySummaryPill(
                      label: 'Items',
                      value:
                          '${_categories.fold<int>(0, (sum, item) => sum + item.items.length)}',
                    ),
                    _InventorySummaryPill(
                      label: 'Selected',
                      value: selected.title,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Category Options',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Categories stay aligned in the same compact tile grid used on the home screen.',
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
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: _categories
                    .map(
                      (category) => SizedBox(
                        width: cardWidth,
                        child: _InventoryCategoryCard(
                          category: category,
                          selected: identical(category, selected),
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            '${selected.title} Stock',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          ...selected.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: InventoryCategoryIcon(
                      type: selected.iconType,
                      size: 24,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.location} • ${item.stockLabel}'),
                  trailing: Text(
                    item.status,
                    style: TextStyle(
                      color: _statusColor(item.status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Critical':
        return const Color(0xFFC54141);
      case 'Low':
        return const Color(0xFFD78B2E);
      default:
        return const Color(0xFF2C9A65);
    }
  }
}

class _InventoryCategory {
  const _InventoryCategory({
    required this.title,
    required this.shortTitle,
    required this.iconType,
    required this.accent,
    required this.items,
  });

  final String title;
  final String shortTitle;
  final InventoryCategoryIconType iconType;
  final Color accent;
  final List<_InventoryItem> items;
}

class _InventoryItem {
  const _InventoryItem(
    this.name,
    this.stockLabel,
    this.status,
    this.location,
  );

  final String name;
  final String stockLabel;
  final String status;
  final String location;
}

class _InventoryCategoryCard extends StatelessWidget {
  const _InventoryCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _InventoryCategory category;
  final bool selected;
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
            color: selected ? const Color(0xFFF0F9FC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? category.accent : const Color(0xFFE0EAF0),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: InventoryCategoryIcon(
                    type: category.iconType,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 58,
                  child: Text(
                    category.shortTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF223746),
                          letterSpacing: 0,
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
