import 'package:flutter/material.dart';

import '../ui/tokens/app_radius.dart';
import '../ui/tokens/app_spacing.dart';

class DashboardHeroBanner extends StatelessWidget {
  const DashboardHeroBanner({
    super.key,
    required this.title,
    required this.description,
    required this.metrics,
    this.summary,
    this.maxContentWidth = 560,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF0E7490), Color(0xFF1AA0B8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.shadow = const BoxShadow(
      color: Color(0x220E7490),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  });

  final String title;
  final String description;
  final String? summary;
  final List<Widget> metrics;
  final double maxContentWidth;
  final LinearGradient gradient;
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: gradient,
        boxShadow: [shadow],
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    summary!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: metrics,
          ),
        ],
      ),
    );
  }
}
