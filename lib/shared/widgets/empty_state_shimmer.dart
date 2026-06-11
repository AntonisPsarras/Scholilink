import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_theme.dart';
import '../../shared/glass_container.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: (iconColor ?? context.brand.primaryPurple).withValues(
                  alpha: 0.1,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor ?? context.brand.primaryPurple,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.brand.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: context.brand.neutralGrey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class SectionLoadingShimmer extends StatelessWidget {
  final double height;
  final double borderRadius;

  const SectionLoadingShimmer({
    super.key,
    this.height = 100,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: height,
      width: double.infinity,
      borderRadius: borderRadius,
      blur: 0,
      animate: false,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.brand.primaryPurple,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the add-homework dialog while homework OCR runs.
class HomeworkOcrFormSkeleton extends StatelessWidget {
  const HomeworkOcrFormSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade400;
    final highlight = Colors.grey.shade100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Επεξεργασία φωτογραφίας...',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: context.brand.darkText,
          ),
        ),
        const SizedBox(height: 16),
        Shimmer.fromColors(
          baseColor: base.withValues(alpha: 0.35),
          highlightColor: highlight,
          period: const Duration(milliseconds: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _shimmerLine(height: 52, radius: 12),
              const SizedBox(height: 12),
              _shimmerLine(height: 48, radius: 12),
              const SizedBox(height: 12),
              _shimmerLine(height: 48, radius: 12),
              const SizedBox(height: 12),
              _shimmerLine(height: 88, radius: 12),
              const SizedBox(height: 12),
              _shimmerLine(height: 44, radius: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shimmerLine({required double height, required double radius}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
