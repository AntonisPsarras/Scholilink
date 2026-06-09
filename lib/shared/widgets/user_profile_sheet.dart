import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/dashboard/domain/exam_result_model.dart';
import '../../features/dashboard/domain/grade_model.dart';
import '../../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../image_utils.dart';
import '../l10n.dart';
import 'package:intl/intl.dart';

class UserProfileSheet extends ConsumerWidget {
  final String userId;

  const UserProfileSheet({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));
    final resultsAsync = ref.watch(userExamResultsProvider(userId));
    final gradesAsync = ref.watch(userGradesProvider(userId));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: context.brand.backgroundSnow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Ο χρήστης δεν βρέθηκε'));
          }

          final s = S(user.preferredLanguage);

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle for bottom sheet
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: context.brand.neutralGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Profile Header
                _buildHeader(context, user, s),
                const SizedBox(height: 24),

                // Bio Section
                if (user.showBio && user.bio.isNotEmpty) ...[
                  _buildSectionTitle(
                    context,
                    s.lang == 'el' ? 'Σχετικά' : 'About',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.brand.darkText,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Achievements Section
                if (user.showAchievements && user.achievements.isNotEmpty) ...[
                  _buildSectionTitle(
                    context,
                    s.lang == 'el' ? 'Επιτεύγματα' : 'Achievements',
                  ),
                  const SizedBox(height: 12),
                  _buildAchievementsList(context, user.achievements),
                  const SizedBox(height: 24),
                ],

                // Academic Snapshot (Privacy Gated)
                if (user.shareGrades) ...[
                  _buildSectionTitle(
                    context,
                    s.lang == 'el' ? 'Ακαδημαϊκή Εικόνα' : 'Academic Snapshot',
                  ),
                  const SizedBox(height: 16),
                  resultsAsync.when(
                    data: (results) => _buildResultsChart(context, results),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => Text(
                      s.lang == 'el'
                          ? 'Σφάλμα στη φόρτωση βαθμολογιών'
                          : 'Error loading grades',
                    ),
                  ),
                  const SizedBox(height: 16),
                  gradesAsync.when(
                    data: (grades) => _buildRecentGrades(context, grades),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ] else ...[
                  _buildPrivateNotice(context, s),
                ],

                const SizedBox(height: 32),

                // Action Buttons
                _buildActionButtons(context, s),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Σφάλμα: $e')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppUser user, S s) {
    return Column(
      children: [
        Hero(
          tag: 'profile_${user.uid}',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.brand.royalLavender.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: user.profilePictureUrl == null
                ? CircleAvatar(
                    radius: 50,
                    backgroundColor: context.brand.royalLavender.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: context.brand.royalLavender,
                      ),
                    ),
                  )
                : ClipOval(
                    child: Builder(
                      builder: (context) {
                        final url = user.profilePictureUrl!;
                        if (isBase64DataUri(url)) {
                          return Image.memory(
                            Uint8List.fromList(decodeBase64DataUri(url)),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          );
                        }
                        final dpr = MediaQuery.devicePixelRatioOf(context);
                        final px = (100 * dpr).round();
                        return CachedNetworkImage(
                          imageUrl: url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          memCacheWidth: px,
                          memCacheHeight: px,
                          maxWidthDiskCache: px,
                          maxHeightDiskCache: px,
                          placeholder: (_, __) => Container(
                            width: 100,
                            height: 100,
                            color: context.brand.royalLavender.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: context.brand.royalLavender,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: context.brand.darkText,
          ),
        ),
        Text(
          user.currentClass ?? (s.lang == 'el' ? 'Μαθητής' : 'Student'),
          style: TextStyle(
            fontSize: 14,
            color: context.brand.neutralGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.brand.darkText,
      ),
    );
  }

  Widget _buildAchievementsList(
    BuildContext context,
    List<String> achievements,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: achievements.map((achievement) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.brand.sunsetWarning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.brand.sunsetWarning.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars, color: context.brand.sunsetWarning, size: 16),
              const SizedBox(width: 6),
              Text(
                achievement,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.brand.darkText,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultsChart(BuildContext context, List<ExamResult> results) {
    if (results.isEmpty) {
      return Text(
        'Δεν υπάρχουν διαθέσιμα αποτελέσματα εξετάσεων',
        style: TextStyle(fontSize: 12, color: context.brand.neutralGrey),
      );
    }

    // Sort results by date
    final sorted = List<ExamResult>.from(results)
      ..sort((a, b) => a.date.compareTo(b.date));
    final displayResults = sorted.length > 5
        ? sorted.sublist(sorted.length - 5)
        : sorted;

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (displayResults.length - 1).toDouble(),
          minY: 0,
          maxY: 20,
          lineBarsData: [
            LineChartBarData(
              spots: displayResults
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.score))
                  .toList(),
              isCurved: true,
              color: context.brand.royalLavender,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: context.brand.royalLavender.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGrades(BuildContext context, List<GradeRecord> grades) {
    if (grades.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final recent = grades.take(3).toList();

    return Column(
      children: recent
          .map(
            (g) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF252536) : cs.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.brand.royalLavender.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 16,
                      color: context.brand.royalLavender,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.subject,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM').format(g.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: dark
                                ? cs.onSurfaceVariant
                                : context.brand.neutralGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    g.grade.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.brand.royalLavender,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPrivateNotice(BuildContext context, S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.brand.neutralGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.brand.neutralGrey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: context.brand.neutralGrey, size: 28),
          const SizedBox(height: 12),
          Text(
            s.lang == 'el'
                ? 'Οι βαθμολογίες είναι ιδιωτικές'
                : 'Grades are private',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.brand.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.lang == 'el'
                ? 'Ο χρήστης έχει επιλέξει να μην μοιράζεται τα αποτελέσματά του.'
                : 'This user has chosen not to share their academic results.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.brand.neutralGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, S s) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Add friend logic or Message logic
              Navigator.pop(context);
            },
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(s.lang == 'el' ? 'Προσθήκη Φίλου' : 'Add Friend'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.royalLavender,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: context.brand.royalLavender.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.chat_bubble_outline,
              color: context.brand.royalLavender,
            ),
          ),
        ),
      ],
    );
  }
}
