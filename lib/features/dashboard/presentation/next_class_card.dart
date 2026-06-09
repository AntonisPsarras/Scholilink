import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../data/dashboard_logic.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';

class NextClassCard extends ConsumerWidget {
  const NextClassCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final s = S(user.preferredLanguage);
        final classId = user.scheduleExamClassId;
        final scheduleAsync = ref.watch(scheduleProvider(classId));

        return scheduleAsync.when(
          data: (days) {
            final nextClass = _findNextClass(days);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.brand.royalLavender,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: context.brand.royalLavender.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.access_time_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextClass != null
                              ? '${s.nextClass}: ${nextClass['time']}'
                              : s.day,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextClass != null
                              ? nextClass['subject']!
                              : (s.lang == 'el'
                                    ? 'Κανένα μάθημα'
                                    : 'No Upcoming Classes'),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (nextClass == null)
                          Text(
                            s.lang == 'el'
                                ? 'Δείτε το πρόγραμμα'
                                : 'Check timetable for details',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (err, stack) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Map<String, String>? _findNextClass(List<Map<String, dynamic>> days) {
    if (days.isEmpty) return null;

    final now = DateTime.now();
    final currentDayName = DateFormat('EEEE').format(now);

    final dayData = days.firstWhere(
      (d) => d['dayName'] == currentDayName,
      orElse: () => {},
    );

    if (dayData.isEmpty || dayData['classes'] == null) return null;

    final classes = List<Map<String, dynamic>>.from(dayData['classes']);
    final nowTime = DateFormat('HH:mm').format(now);

    for (final cls in classes) {
      if (cls['subject'] != 'Break' && cls['time'].compareTo(nowTime) > 0) {
        return Map<String, String>.from(cls);
      }
    }

    return null;
  }
}
