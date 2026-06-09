import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:student_dashboard/features/auth/presentation/onboarding_draft.dart';

void main() {
  test('Greek branch resolves with forced Greek language', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(onboardingDraftProvider.notifier);
    notifier.setNationality(OnboardingNationality.greek);
    final draft = container.read(onboardingDraftProvider);
    final steps = notifier.buildStepsForBranch();

    expect(draft.educationSystem, OnboardingEducationSystem.greek);
    expect(draft.preferredLanguage, 'el');
    expect(steps.contains(OnboardingStepType.greekDemographics), isTrue);
    expect(steps.contains(OnboardingStepType.internationalSubjects), isFalse);
  });

  test('Other + custom routes to international flow', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(onboardingDraftProvider.notifier);
    notifier.setNationality(OnboardingNationality.other);
    notifier.setOtherSystem(OnboardingEducationSystem.custom);
    final draft = container.read(onboardingDraftProvider);
    final steps = notifier.buildStepsForBranch();

    expect(draft.preferredLanguage, 'en');
    expect(steps.contains(OnboardingStepType.internationalSubjects), isTrue);
    expect(steps.contains(OnboardingStepType.greekDemographics), isFalse);
  });

  test('Tutoring step requires at least one tutoring subject when enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(onboardingDraftProvider.notifier);
    notifier.setNationality(OnboardingNationality.greek);
    notifier.setGreekYear("Α' Γυμνασίου");
    notifier.setHasTutoring(true);

    expect(notifier.canProceed(OnboardingStepType.greekTutoring), isFalse);

    final firstSubject = container.read(onboardingDraftProvider).subjects.first;
    notifier.toggleTutoringSubject(firstSubject);
    expect(notifier.canProceed(OnboardingStepType.greekTutoring), isTrue);
  });
}
