import 'package:flutter/material.dart';

import '../ui/tokens/app_colors.dart';
import '../ui/tokens/app_radius.dart';
import '../ui/tokens/app_spacing.dart';

enum MetricCardStyle {
  outlined,
  tinted,
  glass,
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    this.style = MetricCardStyle.outlined,
    this.width,
    this.showIndicator = false,
  });

  final String label;
  final String value;
  final Color accent;
  final MetricCardStyle style;
  final double? width;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        style == MetricCardStyle.glass ? Colors.white : accent;
    final labelColor = style == MetricCardStyle.glass
        ? Colors.white.withValues(alpha: 0.88)
        : Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(_radius),
        border: _border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIndicator) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: labelColor,
                ),
          ),
        ],
      ),
    );
  }

  Color _backgroundColor(BuildContext context) {
    switch (style) {
      case MetricCardStyle.tinted:
        return accent.withValues(alpha: 0.08);
      case MetricCardStyle.glass:
        return Colors.white.withValues(alpha: 0.13);
      case MetricCardStyle.outlined:
        return Colors.white;
    }
  }

  Border? get _border {
    switch (style) {
      case MetricCardStyle.glass:
        return Border.all(color: Colors.white.withValues(alpha: 0.16));
      case MetricCardStyle.outlined:
        return Border.all(color: AppColors.borderSubtle);
      case MetricCardStyle.tinted:
        return null;
    }
  }

  double get _radius {
    switch (style) {
      case MetricCardStyle.glass:
      case MetricCardStyle.outlined:
        return AppRadius.lg;
      case MetricCardStyle.tinted:
        return AppRadius.lg;
    }
  }
}
