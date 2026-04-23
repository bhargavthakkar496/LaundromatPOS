import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashboardWrapGrid extends StatelessWidget {
  const DashboardWrapGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minChildWidth = 180,
    this.maxColumns,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minChildWidth;
  final int? maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final computedColumns =
            ((constraints.maxWidth + spacing) / (minChildWidth + spacing))
                .floor();
        final safeColumns = math.max(1, computedColumns);
        final columns = maxColumns == null
            ? safeColumns
            : math.min(maxColumns!, safeColumns);
        final childWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: childWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
