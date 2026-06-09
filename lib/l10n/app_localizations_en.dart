// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get languageGreek => 'Greek';

  @override
  String get languageEnglish => 'English';

  @override
  String get pleaseLogIn => 'Please log in';

  @override
  String get loginWelcomeTitle => 'Welcome!';

  @override
  String get loginWelcomeSubtitle => 'Welcome to ScholiLink';

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get onboardingSelectGradeWarning => 'Please select your grade';

  @override
  String get onboardingSelectBirthDateWarning =>
      'Please select your Date of Birth';

  @override
  String get onboardingBirthDateLabel => 'Date of Birth';

  @override
  String get onboardingBirthDateHint => 'Select Date of Birth';

  @override
  String get onboardingGradeHint => 'Select Grade';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSaveFinish => 'Save & Finish';

  @override
  String get onboardingValidationNationality =>
      'Select nationality and education system.';

  @override
  String get onboardingValidationTutoring =>
      'Select at least one tutoring subject.';

  @override
  String get onboardingValidationSubjects => 'Add at least one subject.';

  @override
  String get onboardingValidationDemographics =>
      'Set date of birth and custom year/grade.';

  @override
  String get onboardingValidationGeneric => 'Complete this step.';

  @override
  String get onboardingNationalityTitle => 'Nationality selection';

  @override
  String get onboardingNationalitySubtitle =>
      'Choose your nationality so we can configure the correct path.';

  @override
  String get onboardingNationalityGreekTitle => 'Greek';

  @override
  String get onboardingNationalityGreekSubtitle => 'Recommended option';

  @override
  String get onboardingNationalityOtherTitle => 'Other';

  @override
  String get onboardingNationalityOtherSubtitle =>
      'International or custom system';

  @override
  String get onboardingChooseSystemTitle => 'Choose system';

  @override
  String get onboardingSystemGreekTitle => 'Greek Education System';

  @override
  String get onboardingSystemGreekSubtitle =>
      'Greek curriculum with English UI';

  @override
  String get onboardingSystemCustomTitle => 'Custom System';

  @override
  String get onboardingSystemCustomSubtitle =>
      'Fully custom subjects and grade naming';

  @override
  String get onboardingDemographicsTitle => 'Demographics';

  @override
  String get onboardingTutoringTitle => 'Tutoring';

  @override
  String get onboardingCustomSubjectsTitle => 'Custom Subjects';

  @override
  String get onboardingCustomSubjectsSubtitle =>
      'Add and manage your school subjects.';

  @override
  String get onboardingCustomGradeLabel => 'Year / Grade';

  @override
  String get onboardingCustomGradeHint => 'e.g. 2nd Year of High School';

  @override
  String get onboardingCalendarTitle => 'School Calendar';

  @override
  String get onboardingCalendarSubtitle =>
      'Use the existing schedule editor or skip this step for now.';

  @override
  String get onboardingEditSchedule => 'Edit Schedule';

  @override
  String get onboardingSkipForNow => 'Skip for now';

  @override
  String get onboardingPreferencesTitle => 'Preferences';

  @override
  String get onboardingCalendarSync => 'Calendar sync';

  @override
  String get onboardingProfileVisibility => 'Profile visibility';

  @override
  String get settingsLanguageTitle => 'App Language';

  @override
  String get settingsLanguageSubtitle =>
      'Choose the display language across your dashboard.';

  @override
  String get settingsShowDeadlinesTitle => 'Show Deadlines on Calendar';

  @override
  String get settingsShowDeadlinesSubtitle =>
      'Show upcoming projects and presentations on the home calendar';

  @override
  String get settingsSyncCalendarTitle => 'Sync to Google Calendar';

  @override
  String get settingsSyncCalendarConnected =>
      '✓ Connected — new exams and deadlines sync automatically';

  @override
  String get settingsSyncCalendarDisconnected =>
      'Auto-add exams and deadlines to your Google Calendar';

  @override
  String get settingsProfilePrivacyTitle => 'Profile Privacy';

  @override
  String get settingsShowBioTitle => 'Show About Me';

  @override
  String get settingsShowBioSubtitle =>
      'Allows others to see your \"About Me\" section';

  @override
  String get settingsShowAchievementsTitle => 'Show Achievements';

  @override
  String get settingsShowAchievementsSubtitle =>
      'Allows others to see your academic achievements';

  @override
  String get settingsShareGradesTitle => 'Share Grades';

  @override
  String get settingsShareGradesSubtitle =>
      'Show progress charts and grades to classmates';

  @override
  String get settingsLogoutLabel => 'Log Out';

  @override
  String get aiStudyAssistantTitle => 'AI Study Assistant';

  @override
  String get aiStudyAssistantSidebar => 'AI Assistant';

  @override
  String get aiNewChat => 'New Chat';

  @override
  String get aiChatInProgress => 'In progress';

  @override
  String get aiWelcomePitch =>
      'Hello! I am ScholiLink AI.\nHow can I help you today?';

  @override
  String get aiAskAnythingHint => 'Ask me anything...';

  @override
  String get aiHistorySection => 'History';

  @override
  String get aiChatHistoryDrawerTitle => 'Chat history';

  @override
  String get aiNoChatsYet => 'No conversations yet.';

  @override
  String get aiCopied => 'Copied';

  @override
  String get aiCopy => 'Copy';

  @override
  String get smartNotesTitle => 'Smart Notes';

  @override
  String get smartNotesWelcome =>
      'Create smart notes from your text or images!';

  @override
  String get smartNotesNoteSettingsLabel => 'Note settings';

  @override
  String get smartNotesPasteOrAskHint => 'Paste text or ask a question...';

  @override
  String get smartNotesNewNotes => 'New Notes';

  @override
  String get smartNotesSidebarShort => 'Notes';

  @override
  String get smartNotesHistoryDrawerTitle => 'Notes history';

  @override
  String get smartNotesNoNotesYet => 'No notes yet.';

  @override
  String get smartNotesPromptFromImagesOnly =>
      'Create notes from the images I sent.';

  @override
  String get smartNotesLengthSection => 'Note length';

  @override
  String get smartNotesDepthSection => 'Analysis depth';

  @override
  String get smartNotesLenShort => 'Short';

  @override
  String get smartNotesLenMedium => 'Medium';

  @override
  String get smartNotesLenLong => 'Long';

  @override
  String get smartNotesDepthBasic => 'Basic';

  @override
  String get smartNotesDepthStandard => 'Standard';

  @override
  String get smartNotesDepthInDepth => 'In depth';
}
