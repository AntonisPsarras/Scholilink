import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/exam_readiness/domain/readiness_score.dart';
import '../../features/exam_readiness/providers/exam_readiness_providers.dart';
import '../../theme/app_theme.dart';

class ExamReadinessWidget extends ConsumerWidget {
  const ExamReadinessWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readinessAsync = ref.watch(readinessScoresProvider);
    return readinessAsync.when(
      data: (scores) {
        final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
        final recentScores = scores
            .where((s) => s.updatedAt.isAfter(oneWeekAgo))
            .toList();
        if (recentScores.isEmpty) return const SizedBox.shrink();

        final avg = recentScores.isEmpty
            ? 0.0
            : recentScores
                      .map((e) => e.rollingAverage)
                      .reduce((a, b) => a + b) /
                  recentScores.length;
        final band = readinessBandFromScore(avg);
        final color = _colorForBand(band, context);
        final label = _labelForBand(band);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Εξεταστική Ετοιμότητα',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${avg.toStringAsFixed(1)}%  •  $label',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _colorForBand(ReadinessBand band, BuildContext context) {
    switch (band) {
      case ReadinessBand.weak:
        return context.brand.errorRed;
      case ReadinessBand.moderate:
        return context.brand.sunsetWarning;
      case ReadinessBand.good:
        return Colors.teal;
      case ReadinessBand.excellent:
        return context.brand.mintSuccess;
    }
  }

  String _labelForBand(ReadinessBand band) {
    switch (band) {
      case ReadinessBand.weak:
        return 'αδύνατος';
      case ReadinessBand.moderate:
        return 'μέτριος';
      case ReadinessBand.good:
        return 'καλός';
      case ReadinessBand.excellent:
        return 'άριστος';
    }
  }
}
