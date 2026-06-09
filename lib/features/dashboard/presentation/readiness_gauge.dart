import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ReadinessGauge extends StatelessWidget {
  final double percentage; // 0.0 to 1.0

  const ReadinessGauge({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    Color getColor() {
      if (percentage <= 0.40) return context.brand.errorRed;
      if (percentage <= 0.75) return context.brand.sunsetWarning;
      return context.brand.mintSuccess;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Readiness Score',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: context.brand.backgroundSnow,
            color: getColor(),
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Text(
            '${(percentage * 100).toInt()}% Ready for Exams',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: getColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
