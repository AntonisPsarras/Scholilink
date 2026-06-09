import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_logic.dart';
import '../data/homework_history_layout.dart';
import '../domain/homework_post_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/app_shell_insets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class HomeworkHistoryScreen extends ConsumerStatefulWidget {
  const HomeworkHistoryScreen({super.key});

  @override
  ConsumerState<HomeworkHistoryScreen> createState() =>
      _HomeworkHistoryScreenState();
}

class _HomeworkHistoryScreenState extends ConsumerState<HomeworkHistoryScreen> {
  String _selectedYear = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.month >= 9
        ? '${now.year}-${now.year + 1}'
        : '${now.year - 1}-${now.year}';
  }

  List<String> _availableYears() {
    final now = DateTime.now();
    final currentStart = now.month >= 9 ? now.year : now.year - 1;
    return List.generate(3, (i) {
      final start = currentStart - i;
      return '$start-${start + 1}';
    });
  }

  Widget _buildVirtualItem(
    BuildContext context,
    HomeworkHistoryVirtualItem item,
    S s,
    String uid,
  ) {
    switch (item.type) {
      case HomeworkHistoryVirtualKind.summary:
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: context.brand.mintSuccess.withValues(
                        alpha: 0.2,
                      ),
                      radius: 20,
                      child: Icon(
                        Icons.check_circle,
                        color: context.brand.mintSuccess,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.completedCount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      s.lang == 'el' ? 'Ολοκληρωμένες' : 'Completed',
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
                Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: context.brand.sunsetWarning.withValues(
                        alpha: 0.2,
                      ),
                      radius: 20,
                      child: Icon(
                        Icons.pending_actions_rounded,
                        color: context.brand.sunsetWarning,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.forgottenCount}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      s.lang == 'el' ? 'Εκκρεμότητες' : 'Pending',
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case HomeworkHistoryVirtualKind.gap:
        return SizedBox(height: item.gapHeight);
      case HomeworkHistoryVirtualKind.subjectHeader:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${item.subject!} (${item.subjectCount})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        );
      case HomeworkHistoryVirtualKind.homeworkCard:
        final hw = item.post!;
        final isCompleted = hw.isCompleted;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onLongPress: () => _confirmDelete(context, hw, uid),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.pending_actions_rounded,
                    color: isCompleted
                        ? context.brand.mintSuccess
                        : context.brand.sunsetWarning,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hw.content,
                          style: TextStyle(
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? context.brand.neutralGrey
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hw.completedAt != null)
                          Text(
                            '${hw.completedAt!.day}/${hw.completedAt!.month}/${hw.completedAt!.year}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.brand.neutralGrey,
                            ),
                          ),
                        if (!isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    CustomSnackBar.show(
                                      context: context,
                                      message: s.lang == 'el'
                                          ? 'Λειτουργία σε ανάπτυξη...'
                                          : 'Feature in development...',
                                      type: SnackBarType.info,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.brand.sunsetWarning
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      s.lang == 'el'
                                          ? 'Ρώτα Συμμαθητή'
                                          : 'Ask Classmate',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.brand.sunsetWarning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final s = S(user?.preferredLanguage ?? 'el');
    final layoutAsync = ref.watch(homeworkHistoryLayoutProvider(_selectedYear));

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.homeworkHistory),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // School year selector
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: context.brand.royalLavender,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.schoolYear,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _selectedYear,
                        items: _availableYears()
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedYear = val);
                          }
                        },
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          color: context.brand.royalLavender,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // History list
                Expanded(
                  child: layoutAsync.when(
                    data: (layout) {
                      if (layout.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: context.brand.neutralGrey.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.lang == 'el'
                                    ? 'Δεν υπάρχει ιστορικό εργασιών.'
                                    : 'No homework history.',
                                style: TextStyle(
                                  color: context.brand.neutralGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final uid = user?.uid ?? '';
                      final bottomPad = pushedRouteBottomPadding(context);

                      return ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                        itemCount: layout.virtualItems.length,
                        itemBuilder: (context, index) {
                          final row = layout.virtualItems[index];
                          return _buildVirtualItem(context, row, s, uid);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HomeworkPost hw,
    String uid,
  ) async {
    final s = S(ref.read(authStateProvider).value?.preferredLanguage ?? 'el');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          s.lang == 'el' ? 'Διαγραφή από ιστορικό;' : 'Delete from history?',
        ),
        content: Text(
          s.lang == 'el'
              ? 'Αυτή η ενέργεια δεν μπορεί να αναιρεθεί.'
              : 'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('OK', style: TextStyle(color: context.brand.errorRed)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('homework_history')
          .doc(_selectedYear)
          .collection('items')
          .doc(hw.postId)
          .delete();
      ref.invalidate(homeworkHistoryProvider(_selectedYear));
    }
  }
}
