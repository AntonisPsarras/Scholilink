// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../classroom/data/friendship_service.dart';
import '../../auth/domain/user_model.dart';
import '../../dashboard/services/google_calendar_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_preference.dart';
import '../../../theme/theme_providers.dart';
import '../../../shared/app_locale.dart';
import '../../../shared/l10n.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/subject_chip.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'ai_settings_screen.dart';
import 'manage_subjects_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        final t = AppLocalizations.of(context)!;
        if (user == null) return Center(child: Text(t.pleaseLogIn));

        final s = S(user.preferredLanguage);
        final lang = user.preferredLanguage;
        final currentLanguageCode = ref.watch(appLocaleProvider).languageCode;

        return AppTheme.globalGradient(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(s.settings),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Text(
                              s.themeAppearance,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Text(
                              s.themeAppearanceDesc,
                              style: TextStyle(
                                color: context.brand.neutralGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          RadioListTile<ThemePreference>(
                            title: Text(s.themeLight),
                            value: ThemePreference.light,
                            groupValue: ref.watch(themePreferenceProvider),
                            onChanged: (v) async {
                              if (v == null) return;
                              await ref
                                  .read(themePreferenceProvider.notifier)
                                  .setPreference(v);
                            },
                          ),
                          RadioListTile<ThemePreference>(
                            title: Text(s.themeDark),
                            value: ThemePreference.dark,
                            groupValue: ref.watch(themePreferenceProvider),
                            onChanged: (v) async {
                              if (v == null) return;
                              await ref
                                  .read(themePreferenceProvider.notifier)
                                  .setPreference(v);
                            },
                          ),
                          RadioListTile<ThemePreference>(
                            title: Text(s.themeSystem),
                            value: ThemePreference.system,
                            groupValue: ref.watch(themePreferenceProvider),
                            onChanged: (v) async {
                              if (v == null) return;
                              await ref
                                  .read(themePreferenceProvider.notifier)
                                  .setPreference(v);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.settingsLanguageTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.settingsLanguageSubtitle,
                              style: TextStyle(
                                color: context.brand.neutralGrey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              label: t.language,
                              child: SegmentedButton<String>(
                                segments: [
                                  ButtonSegment<String>(
                                    value: 'el',
                                    label: Text('🇬🇷 ${t.languageGreek}'),
                                  ),
                                  ButtonSegment<String>(
                                    value: 'en',
                                    label: Text('🇬🇧 ${t.languageEnglish}'),
                                  ),
                                ],
                                selected: {currentLanguageCode},
                                showSelectedIcon: false,
                                onSelectionChanged: (selection) async {
                                  final nextLanguage = selection.first;
                                  await ref
                                      .read(appLocaleProvider.notifier)
                                      .setLanguage(nextLanguage);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              lang == 'el' ? 'Ειδοποιήσεις' : 'Notifications',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              lang == 'el'
                                  ? 'Ενεργοποίησε μόνο όσες ειδοποιήσεις σε βοηθούν πραγματικά.'
                                  : 'Keep only the notifications that help you most.',
                              style: TextStyle(
                                color: context.brand.neutralGrey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SwitchListTile(
                            title: Text(lang == 'el' ? 'Μηνύματα' : 'Messages'),
                            value: user.notifyMessages,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyMessages: val),
                                  );
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              lang == 'el'
                                  ? 'Ξεχασμένες εργασίες'
                                  : 'Missed homework reminders',
                            ),
                            value: user.notifyHomeworkOverdue,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyHomeworkOverdue: val),
                                  );
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              lang == 'el'
                                  ? 'Προετοιμασία εξετάσεων'
                                  : 'Exam prep reminders',
                            ),
                            value: user.notifyExamPrepOverdue,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyExamPrepOverdue: val),
                                  );
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              lang == 'el'
                                  ? 'Ημερήσιο digest προθεσμιών'
                                  : 'Daily deadline digest',
                            ),
                            value: user.notifyDailyDigest,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyDailyDigest: val),
                                  );
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              lang == 'el'
                                  ? 'Υπενθύμιση αδράνειας'
                                  : 'Inactivity nudges',
                            ),
                            value: user.notifyInactivity,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyInactivity: val),
                                  );
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              lang == 'el'
                                  ? 'Νέες αναρτήσεις τάξης'
                                  : 'New classroom updates',
                            ),
                            value: user.notifyClassUpdates,
                            onChanged: (val) {
                              ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(notifyClassUpdates: val),
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _BlockedUsersCard(lang: lang),

                    const SizedBox(height: 12),

                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.brand.royalLavender.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.key_outlined,
                            color: context.brand.royalLavender,
                          ),
                        ),
                        title: const Text(
                          'AI Configuration',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          lang == 'el'
                              ? 'Πρόσθεσε δικό σου Gemini API key (BYOK).'
                              : 'Add your own Gemini API key (BYOK).',
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AiSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Auto-Add Homework Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          s.autoAddHomework,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.autoAddHomeworkDesc,
                            style: TextStyle(
                              color: context.brand.neutralGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        value: user.autoAddHomework,
                        activeTrackColor: context.brand.royalLavender
                            .withValues(alpha: 0.5),
                        activeThumbColor: context.brand.royalLavender,
                        onChanged: (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(
                                user.copyWith(autoAddHomework: val),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Show Deadlines on Calendar Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          t.settingsShowDeadlinesTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            t.settingsShowDeadlinesSubtitle,
                            style: TextStyle(
                              color: context.brand.neutralGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.brand.sunsetWarning.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note_outlined,
                            color: context.brand.sunsetWarning,
                            size: 20,
                          ),
                        ),
                        value: user.showDeadlinesOnCalendar,
                        activeTrackColor: context.brand.sunsetWarning
                            .withValues(alpha: 0.5),
                        activeThumbColor: context.brand.sunsetWarning,
                        onChanged: (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(
                                user.copyWith(showDeadlinesOnCalendar: val),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sync to Google Calendar Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          t.settingsSyncCalendarTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            user.syncToDeviceCalendar
                                ? t.settingsSyncCalendarConnected
                                : t.settingsSyncCalendarDisconnected,
                            style: TextStyle(
                              color: user.syncToDeviceCalendar
                                  ? context.brand.mintSuccess.withValues(
                                      alpha: 0.8,
                                    )
                                  : context.brand.neutralGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF4285F4,
                            ).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          // Google Calendar icon (using a custom paint or just the calendar icon colored Google-blue)
                          child: const Icon(
                            Icons.calendar_month,
                            color: Color(0xFF4285F4),
                            size: 22,
                          ),
                        ),
                        value: user.syncToDeviceCalendar,
                        activeTrackColor: const Color(
                          0xFF4285F4,
                        ).withValues(alpha: 0.4),
                        activeThumbColor: const Color(0xFF4285F4),
                        onChanged: (val) async {
                          if (val) {
                            // Show connect dialog and trigger OAuth
                            final connected =
                                await GoogleCalendarService.showConnectDialog(
                                  context,
                                  ref,
                                );
                            if (connected) {
                              await ref
                                  .read(authRepositoryProvider)
                                  .updateUserProfile(
                                    user.copyWith(syncToDeviceCalendar: true),
                                  );
                            }
                          } else {
                            // Just disable — no sign-out needed
                            await ref
                                .read(authRepositoryProvider)
                                .updateUserProfile(
                                  user.copyWith(syncToDeviceCalendar: false),
                                );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Profile Privacy Section
                    const SizedBox(height: 24),
                    Text(
                      t.settingsProfilePrivacyTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),

                    // Show Bio Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          t.settingsShowBioTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.settingsShowBioSubtitle,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 13,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.brand.royalLavender.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: context.brand.royalLavender,
                            size: 20,
                          ),
                        ),
                        value: user.showBio,
                        activeTrackColor: context.brand.royalLavender
                            .withValues(alpha: 0.5),
                        activeThumbColor: context.brand.royalLavender,
                        onChanged: (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(user.copyWith(showBio: val));
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Show Achievements Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          t.settingsShowAchievementsTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.settingsShowAchievementsSubtitle,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 13,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.brand.sunsetWarning.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.stars_outlined,
                            color: context.brand.sunsetWarning,
                            size: 20,
                          ),
                        ),
                        value: user.showAchievements,
                        activeTrackColor: context.brand.sunsetWarning
                            .withValues(alpha: 0.5),
                        activeThumbColor: context.brand.sunsetWarning,
                        onChanged: (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(
                                user.copyWith(showAchievements: val),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Share Grades Toggle
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          t.settingsShareGradesTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          t.settingsShareGradesSubtitle,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 13,
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.brand.mintSuccess.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bar_chart_outlined,
                            color: context.brand.mintSuccess,
                            size: 20,
                          ),
                        ),
                        value: user.shareGrades,
                        activeTrackColor: context.brand.mintSuccess.withValues(
                          alpha: 0.5,
                        ),
                        activeThumbColor: context.brand.mintSuccess,
                        onChanged: (val) {
                          ref
                              .read(authRepositoryProvider)
                              .updateUserProfile(
                                user.copyWith(shareGrades: val),
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Manage Subjects
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.brand.royalLavender.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.menu_book_outlined,
                            color: context.brand.royalLavender,
                          ),
                        ),
                        title: Text(
                          s.manageSubjects,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          s.manageSubjectsDesc,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ManageSubjectsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Current subjects display
                    if (user.subjects.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        s.subjects,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.subjects.map((subject) {
                          return SubjectChip(
                            subject: subject,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 40),

                    // Logout button relocated from Profile View
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.brand.errorRed,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.transparent
                              : Colors.white.withValues(alpha: 0.5),
                          side: BorderSide(
                            color: context.brand.errorRed.withValues(
                              alpha: 0.5,
                            ),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          // Sign out and pop context to prevent orphaned screens
                          ref.read(authRepositoryProvider).signOut();
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        icon: const Icon(Icons.logout),
                        label: Text(
                          t.settingsLogoutLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) {
        final t = AppLocalizations.of(context)!;
        return Scaffold(body: Center(child: Text(t.errorPrefix('$err'))));
      },
    );
  }
}

class _BlockedUsersCard extends ConsumerWidget {
  const _BlockedUsersCard({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);
    final blocked = ref.watch(
      authStateProvider.select(
        (async) => async.valueOrNull?.blockedUsers ?? const <String>[],
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.blockedUsers,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (blocked.isEmpty)
              Text(
                s.noBlockedUsers,
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontSize: 13,
                ),
              )
            else
              for (final uid in blocked)
                _BlockedUserTile(key: ValueKey(uid), uid: uid, lang: lang),
          ],
        ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerStatefulWidget {
  const _BlockedUserTile({
    super.key,
    required this.uid,
    required this.lang,
  });

  final String uid;
  final String lang;

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  AppUser? _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await ref.read(friendshipServiceProvider).getUserByUid(widget.uid);
    if (mounted) setState(() => _user = user);
  }

  Future<void> _unblock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final s = S(widget.lang);
    try {
      await ref.read(authRepositoryProvider).unblockUser(widget.uid);
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: s.userUnblocked,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${s.error}: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final name = _user?.fullName.isNotEmpty == true
        ? _user!.fullName
        : widget.uid;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(
        profilePictureUrl: _user?.profilePictureUrl,
        fullName: name,
        radius: 20,
      ),
      title: Text(name),
      trailing: TextButton(
        onPressed: _busy ? null : _unblock,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(s.unblock),
      ),
    );
  }
}
