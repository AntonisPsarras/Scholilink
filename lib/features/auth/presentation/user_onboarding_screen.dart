import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/app_locale.dart';
import '../../../../shared/l10n.dart';
import '../../../../shared/utils/firebase_error_handler.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/subject_chip.dart';
import '../../../../theme/app_theme.dart';
import '../../../core/social_callables.dart';
import '../../dashboard/presentation/schedule_editor_screen.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'onboarding_draft.dart';

class UserOnboardingScreen extends ConsumerStatefulWidget {
  const UserOnboardingScreen({super.key});

  @override
  ConsumerState<UserOnboardingScreen> createState() =>
      _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends ConsumerState<UserOnboardingScreen> {
  int _stepIndex = 0;
  bool _isSubmitting = false;
  final TextEditingController _customSubjectController =
      TextEditingController();

  @override
  void dispose() {
    _customSubjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final t = AppLocalizations.of(context)!;
    final s = S(draft.preferredLanguage);
    final steps = notifier.buildStepsForBranch();
    if (_stepIndex >= steps.length) {
      _stepIndex = steps.length - 1;
    }
    final currentStep = steps[_stepIndex];
    final progress = (_stepIndex + 1) / steps.length;
    final isLastStep = _stepIndex == steps.length - 1;

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.completeSetup),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_stepIndex + 1}/${steps.length}',
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                      color: context.brand.royalLavender,
                      backgroundColor: context.brand.neutralGrey.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(
                    context: context,
                    user: user,
                    draft: draft,
                    currentStep: currentStep,
                    t: t,
                    s: s,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _stepIndex == 0 || _isSubmitting
                            ? null
                            : () {
                                setState(() => _stepIndex -= 1);
                              },
                        child: Text(t.onboardingBack),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.brand.royalLavender,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _onNextPressed(
                                currentStep: currentStep,
                                isLastStep: isLastStep,
                                t: t,
                                s: s,
                                user: user,
                              ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isLastStep
                                    ? t.onboardingSaveFinish
                                    : t.onboardingNext,
                              ),
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

  Widget _buildStepContent({
    required BuildContext context,
    required AppUser user,
    required OnboardingDraft draft,
    required OnboardingStepType currentStep,
    required AppLocalizations t,
    required S s,
  }) {
    switch (currentStep) {
      case OnboardingStepType.nationality:
        return _NationalityStep(draft: draft, t: t);
      case OnboardingStepType.greekDemographics:
        return _GreekDemographicsStep(draft: draft, t: t, s: s);
      case OnboardingStepType.greekTutoring:
        return _GreekTutoringStep(draft: draft, s: s, t: t);
      case OnboardingStepType.greekCalendar:
      case OnboardingStepType.internationalCalendar:
        return _CalendarStep(
          s: s,
          user: user,
          draft: draft,
          t: t,
          onSkip: () => ref
              .read(onboardingDraftProvider.notifier)
              .setCalendarSkipped(true),
        );
      case OnboardingStepType.greekPreferences:
      case OnboardingStepType.internationalPreferences:
        return _PreferencesStep(draft: draft, s: s, t: t);
      case OnboardingStepType.internationalSubjects:
        return _InternationalSubjectsStep(
          draft: draft,
          s: s,
          t: t,
          controller: _customSubjectController,
        );
      case OnboardingStepType.internationalDemographics:
        return _InternationalDemographicsStep(draft: draft, t: t, s: s);
    }
  }

  Future<void> _onNextPressed({
    required OnboardingStepType currentStep,
    required bool isLastStep,
    required AppLocalizations t,
    required S s,
    required AppUser user,
  }) async {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    if (!notifier.canProceed(currentStep)) {
      CustomSnackBar.show(
        context: context,
        message: _validationMessageForStep(currentStep, t, s),
        type: SnackBarType.warning,
      );
      return;
    }

    if (!isLastStep) {
      setState(() => _stepIndex += 1);
      return;
    }

    final draft = ref.read(onboardingDraftProvider);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(appLocaleProvider.notifier)
          .setLanguage(draft.preferredLanguage, persistToProfile: false);

      await ref
          .read(authRepositoryProvider)
          .updateUserProfile(
            user.copyWith(
              preferredLanguage: draft.preferredLanguage,
              autoAddHomework: draft.autoAddHomework,
              syncToDeviceCalendar: draft.syncToDeviceCalendar,
              showBio: draft.showBio,
              shareGrades: draft.shareGrades,
              subjects: draft.subjects,
            ),
          );

      await callCompleteStudentOnboarding(
        currentClass: notifier.buildCurrentClassLabel(),
        subjects: draft.subjects,
        hasTutoring: draft.hasTutoring,
        tutoringSubjects: draft.hasTutoring ? draft.tutoringSubjects : const [],
        birthDateMillis: draft.dateOfBirth!.millisecondsSinceEpoch,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: FirebaseErrorHandler.getMessage(e, s.lang),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _validationMessageForStep(
    OnboardingStepType step,
    AppLocalizations t,
    S s,
  ) {
    switch (step) {
      case OnboardingStepType.nationality:
        return t.onboardingValidationNationality;
      case OnboardingStepType.greekDemographics:
        return t.onboardingSelectGradeWarning;
      case OnboardingStepType.greekTutoring:
        return t.onboardingValidationTutoring;
      case OnboardingStepType.internationalSubjects:
        return t.onboardingValidationSubjects;
      case OnboardingStepType.internationalDemographics:
        return t.onboardingValidationDemographics;
      case OnboardingStepType.greekCalendar:
      case OnboardingStepType.internationalCalendar:
      case OnboardingStepType.greekPreferences:
      case OnboardingStepType.internationalPreferences:
        return t.onboardingValidationGeneric;
    }
  }
}

class _NationalityStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final AppLocalizations t;
  const _NationalityStep({required this.draft, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingNationalityTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          t.onboardingNationalitySubtitle,
          style: TextStyle(color: context.brand.neutralGrey),
        ),
        const SizedBox(height: 20),
        _ChoiceCard(
          title: t.onboardingNationalityGreekTitle,
          subtitle: t.onboardingNationalityGreekSubtitle,
          isSelected: draft.nationality == OnboardingNationality.greek,
          isPrimary: true,
          onTap: () => notifier.setNationality(OnboardingNationality.greek),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          title: t.onboardingNationalityOtherTitle,
          subtitle: t.onboardingNationalityOtherSubtitle,
          isSelected: draft.nationality == OnboardingNationality.other,
          onTap: () => notifier.setNationality(OnboardingNationality.other),
        ),
        if (draft.nationality == OnboardingNationality.other) ...[
          const SizedBox(height: 20),
          Text(
            t.onboardingChooseSystemTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            title: t.onboardingSystemGreekTitle,
            subtitle: t.onboardingSystemGreekSubtitle,
            isSelected:
                draft.educationSystem == OnboardingEducationSystem.greek,
            onTap: () =>
                notifier.setOtherSystem(OnboardingEducationSystem.greek),
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            title: t.onboardingSystemCustomTitle,
            subtitle: t.onboardingSystemCustomSubtitle,
            isSelected:
                draft.educationSystem == OnboardingEducationSystem.custom,
            onTap: () =>
                notifier.setOtherSystem(OnboardingEducationSystem.custom),
          ),
        ],
      ],
    );
  }
}

class _GreekDemographicsStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final AppLocalizations t;
  final S s;
  const _GreekDemographicsStep({
    required this.draft,
    required this.t,
    required this.s,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final showDirectionDropdown =
        draft.selectedYear == "Β' Λυκείου" ||
        draft.selectedYear == "Γ' Λυκείου";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingDemographicsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Text(
          t.onboardingBirthDateLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(
                const Duration(days: 365 * 15),
              ),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (date != null) notifier.setDateOfBirth(date);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: t.onboardingBirthDateHint,
            ),
            child: Text(
              draft.dateOfBirth != null
                  ? '${draft.dateOfBirth!.day}/${draft.dateOfBirth!.month}/${draft.dateOfBirth!.year}'
                  : t.onboardingBirthDateHint,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(s.grade, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: draft.selectedYear,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: t.onboardingGradeHint,
          ),
          items: greekYears
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: notifier.setGreekYear,
        ),
        if (showDirectionDropdown) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.selectedDirection,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: s.selectDirection,
            ),
            items: (greekDirectionsForYear[draft.selectedYear] ?? const [])
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: notifier.setGreekDirection,
          ),
        ],
      ],
    );
  }
}

class _GreekTutoringStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final S s;
  final AppLocalizations t;
  const _GreekTutoringStep({
    required this.draft,
    required this.s,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingTutoringTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                s.hasTutoring,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Switch(
              value: draft.hasTutoring,
              onChanged: notifier.setHasTutoring,
              activeTrackColor: context.brand.royalLavender,
            ),
          ],
        ),
        if (draft.subjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(s.subjects, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: draft.subjects
                .map(
                  (subject) => SubjectChip(
                    subject: subject,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (draft.hasTutoring && draft.subjects.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            s.tutoringSubjects,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: draft.subjects.map((subject) {
              final selected = draft.tutoringSubjects.contains(subject);
              return SubjectChip(
                subject: subject,
                selected: selected,
                onTap: () => notifier.toggleTutoringSubject(subject),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _InternationalSubjectsStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final S s;
  final AppLocalizations t;
  final TextEditingController controller;
  const _InternationalSubjectsStep({
    required this.draft,
    required this.s,
    required this.t,
    required this.controller,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingCustomSubjectsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          t.onboardingCustomSubjectsSubtitle,
          style: TextStyle(color: context.brand.neutralGrey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: s.customSubjectHint,
                ),
                onSubmitted: (_) {
                  notifier.addCustomSubject(controller.text);
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                notifier.addCustomSubject(controller.text);
                controller.clear();
              },
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: context.brand.royalLavender,
              ),
              color: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: draft.subjects
              .map(
                (subject) => SubjectChip(
                  subject: subject,
                  onDeleted: () => notifier.removeCustomSubject(subject),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _InternationalDemographicsStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final AppLocalizations t;
  final S s;
  const _InternationalDemographicsStep({
    required this.draft,
    required this.t,
    required this.s,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingDemographicsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().subtract(
                const Duration(days: 365 * 15),
              ),
              firstDate: DateTime(1990),
              lastDate: DateTime.now(),
            );
            if (date != null) notifier.setDateOfBirth(date);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: t.onboardingBirthDateHint,
              labelText: t.onboardingBirthDateLabel,
            ),
            child: Text(
              draft.dateOfBirth != null
                  ? '${draft.dateOfBirth!.day}/${draft.dateOfBirth!.month}/${draft.dateOfBirth!.year}'
                  : t.onboardingBirthDateHint,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: notifier.setCustomGradeLabel,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: t.onboardingCustomGradeLabel,
            hintText: t.onboardingCustomGradeHint,
          ),
        ),
      ],
    );
  }
}

class _CalendarStep extends StatelessWidget {
  final S s;
  final AppUser user;
  final OnboardingDraft draft;
  final AppLocalizations t;
  final VoidCallback onSkip;
  const _CalendarStep({
    required this.s,
    required this.user,
    required this.draft,
    required this.t,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingCalendarTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          t.onboardingCalendarSubtitle,
          style: TextStyle(color: context.brand.neutralGrey),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScheduleEditorScreen(
                  onboardingMode: true,
                  subjectOverrides: draft.subjects,
                  tutoringSubjectOverrides: draft.tutoringSubjects,
                ),
              ),
            );
          },
          icon: const Icon(Icons.edit_calendar),
          label: Text(t.onboardingEditSchedule),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: onSkip, child: Text(t.onboardingSkipForNow)),
      ],
    );
  }
}

class _PreferencesStep extends ConsumerWidget {
  final OnboardingDraft draft;
  final S s;
  final AppLocalizations t;
  const _PreferencesStep({
    required this.draft,
    required this.s,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.onboardingPreferencesTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: Text(s.autoAddHomework),
            value: draft.autoAddHomework,
            onChanged: notifier.setAutoAddHomework,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: Text(t.onboardingCalendarSync),
            value: draft.syncToDeviceCalendar,
            onChanged: notifier.setSyncToDeviceCalendar,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: Text(t.onboardingProfileVisibility),
            value: draft.showBio,
            onChanged: notifier.setShowBio,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            title: Text(s.shareGrades),
            value: draft.shareGrades,
            onChanged: notifier.setShareGrades,
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isPrimary
        ? context.brand.royalLavender
        : context.brand.mintSuccess;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 18 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? accent
                : context.brand.neutralGrey.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: context.brand.neutralGrey)),
          ],
        ),
      ),
    );
  }
}
