import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../shared/app_shell_insets.dart';
import '../../../shared/l10n.dart';
import '../data/dashboard_logic.dart';
import '../domain/grade_model.dart';
import '../../auth/data/auth_repository.dart';

/// Detail view for one subject: sparkline (last ≤8 grades), stats, and full record list.
class SubjectGradeDetailScreen extends ConsumerWidget {
  const SubjectGradeDetailScreen({
    super.key,
    required this.subject,
    required this.schoolYear,
  });

  final String subject;
  final String schoolYear;

  static const int _maxChartPoints = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final gradesAsync = ref.watch(gradesProvider);

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: context.brand.darkText),
        ),
        body: gradesAsync.when(
          data: (all) {
            final forSubject = all.where((g) => g.subject == subject).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
            if (forSubject.isEmpty) {
              return Center(
                child: Text(
                  s.lang == 'el'
                      ? 'Δεν υπάρχουν βαθμοί για αυτό το μάθημα.'
                      : 'No grades for this subject.',
                  style: TextStyle(color: context.brand.neutralGrey),
                ),
              );
            }

            final chartSlice = forSubject.length > _maxChartPoints
                ? forSubject.sublist(forSubject.length - _maxChartPoints)
                : List<GradeRecord>.from(forSubject);

            final avg =
                chartSlice.map((e) => e.grade).reduce((a, b) => a + b) /
                chartSlice.length;
            final maxG = chartSlice
                .map((e) => e.grade)
                .reduce((a, b) => a > b ? a : b);
            final minG = chartSlice
                .map((e) => e.grade)
                .reduce((a, b) => a < b ? a : b);

            final listDesc = List<GradeRecord>.from(forSubject)
              ..sort((a, b) => b.date.compareTo(a.date));

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                pushedRouteBottomPadding(context),
              ),
              children: [
                Text(
                  '${s.lang == 'el' ? 'Σχολικό έτος' : 'School year'}: $schoolYear',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.brand.neutralGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                if (chartSlice.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      s.lang == 'el'
                          ? 'Χρειάζονται τουλάχιστον 2 βαθμοί για το γράφημα'
                          : 'At least 2 grades are required for the chart.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.brand.neutralGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: LineChart(_buildChartData(context, chartSlice, s)),
                  ),
                  const SizedBox(height: 16),
                ],
                _StatRow(average: avg, max: maxG, min: minG, s: s),
                const SizedBox(height: 24),
                Text(
                  s.lang == 'el' ? 'Καταχωρήσεις' : 'Entries',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.brand.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                ...listDesc.map((g) => _GradeEntryTile(record: g, s: s)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  LineChartData _buildChartData(
    BuildContext context,
    List<GradeRecord> series,
    S s,
  ) {
    final purple = context.brand.primaryPurple;
    final spots = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i].grade),
    ];

    return LineChartData(
      minX: 0,
      maxX: (series.length - 1).toDouble(),
      minY: 0,
      maxY: 20,
      clipData: const FlClipData.all(),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        show: false,
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 10,
            color: context.brand.neutralGrey.withValues(alpha: 0.55),
            strokeWidth: 1,
            dashArray: const [5, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 2),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.brand.neutralGrey,
              ),
              labelResolver: (line) => s.lang == 'el' ? 'Βάση: 10' : 'Pass: 10',
            ),
          ),
        ],
      ),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: purple,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, i) =>
                FlDotCirclePainter(radius: 4, color: purple, strokeWidth: 0),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.average,
    required this.max,
    required this.min,
    required this.s,
  });

  final double average;
  final double max;
  final double min;
  final S s;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.brand.darkText,
      fontSize: 12,
      height: 1.35,
    );
    final el = s.lang == 'el';
    return Row(
      children: [
        Expanded(
          child: Text(
            el
                ? 'Μέσος όρος: ${average.toStringAsFixed(1)}'
                : 'Average: ${average.toStringAsFixed(1)}',
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            el
                ? 'Υψηλότερος: ${max.toStringAsFixed(1)}'
                : 'Highest: ${max.toStringAsFixed(1)}',
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            el
                ? 'Χαμηλότερος: ${min.toStringAsFixed(1)}'
                : 'Lowest: ${min.toStringAsFixed(1)}',
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _GradeEntryTile extends StatelessWidget {
  const _GradeEntryTile({required this.record, required this.s});

  final GradeRecord record;
  final S s;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${record.date.day}/${record.date.month}/${record.date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.term,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.brand.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.lang == 'el' ? 'Ημ/νία' : 'Date'}: $dateStr · ${s.lang == 'el' ? 'Έτος' : 'Year'}: ${record.schoolYear}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.brand.neutralGrey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            record.grade.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: context.brand.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }
}
