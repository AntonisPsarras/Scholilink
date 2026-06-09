// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get language => 'Γλώσσα';

  @override
  String get languageGreek => 'Ελληνικά';

  @override
  String get languageEnglish => 'Αγγλικά';

  @override
  String get pleaseLogIn => 'Παρακαλώ συνδεθείτε';

  @override
  String get loginWelcomeTitle => 'Καλώς ήρθατε!';

  @override
  String get loginWelcomeSubtitle => 'Καλώς ήρθατε στο ScholiLink';

  @override
  String errorPrefix(Object error) {
    return 'Σφάλμα: $error';
  }

  @override
  String get onboardingSelectGradeWarning => 'Παρακαλώ επιλέξτε την τάξη σας';

  @override
  String get onboardingSelectBirthDateWarning =>
      'Παρακαλώ εισάγετε Ημερομηνία Γέννησης';

  @override
  String get onboardingBirthDateLabel => 'Ημερομηνία Γέννησης';

  @override
  String get onboardingBirthDateHint => 'Επιλέξτε Ημερομηνία Γέννησης';

  @override
  String get onboardingGradeHint => 'Επιλέξτε Τάξη';

  @override
  String get onboardingBack => 'Πίσω';

  @override
  String get onboardingNext => 'Επόμενο';

  @override
  String get onboardingSaveFinish => 'Αποθήκευση & Ολοκλήρωση';

  @override
  String get onboardingValidationNationality =>
      'Επιλέξτε εθνικότητα και σύστημα εκπαίδευσης.';

  @override
  String get onboardingValidationTutoring =>
      'Επίλεξε τουλάχιστον ένα μάθημα ιδιαίτερων.';

  @override
  String get onboardingValidationSubjects =>
      'Προσθέστε τουλάχιστον ένα μάθημα.';

  @override
  String get onboardingValidationDemographics =>
      'Συμπληρώστε ημερομηνία γέννησης και έτος/τάξη.';

  @override
  String get onboardingValidationGeneric => 'Συμπλήρωσε το βήμα.';

  @override
  String get onboardingNationalityTitle => 'Επιλογή εθνικότητας';

  @override
  String get onboardingNationalitySubtitle =>
      'Πρώτα επιλέξτε εθνικότητα για να ορίσουμε τη σωστή διαδρομή.';

  @override
  String get onboardingNationalityGreekTitle => 'Ελληνική';

  @override
  String get onboardingNationalityGreekSubtitle => 'Προτεινόμενη επιλογή';

  @override
  String get onboardingNationalityOtherTitle => 'Άλλη';

  @override
  String get onboardingNationalityOtherSubtitle =>
      'Διεθνές ή προσαρμοσμένο σύστημα';

  @override
  String get onboardingChooseSystemTitle => 'Επίλεξε σύστημα';

  @override
  String get onboardingSystemGreekTitle => 'Ελληνικό Εκπαιδευτικό Σύστημα';

  @override
  String get onboardingSystemGreekSubtitle =>
      'Ροή ελληνικών τάξεων με αγγλικό UI';

  @override
  String get onboardingSystemCustomTitle => 'Προσαρμοσμένο Σύστημα';

  @override
  String get onboardingSystemCustomSubtitle =>
      'Πλήρως προσαρμοσμένα μαθήματα/έτη';

  @override
  String get onboardingDemographicsTitle => 'Δημογραφικά';

  @override
  String get onboardingTutoringTitle => 'Ιδιαίτερα';

  @override
  String get onboardingCustomSubjectsTitle => 'Προσαρμοσμένα Μαθήματα';

  @override
  String get onboardingCustomSubjectsSubtitle =>
      'Πρόσθεσε τα σχολικά σου μαθήματα.';

  @override
  String get onboardingCustomGradeLabel => 'Έτος / Τάξη';

  @override
  String get onboardingCustomGradeHint => 'π.χ. 2ο Έτος Λυκείου';

  @override
  String get onboardingCalendarTitle => 'Σχολικό Ημερολόγιο';

  @override
  String get onboardingCalendarSubtitle =>
      'Χρησιμοποίησε τον υπάρχοντα editor προγράμματος ή παράλειψε το βήμα.';

  @override
  String get onboardingEditSchedule => 'Επεξεργασία Προγράμματος';

  @override
  String get onboardingSkipForNow => 'Παράλειψη για τώρα';

  @override
  String get onboardingPreferencesTitle => 'Προτιμήσεις';

  @override
  String get onboardingCalendarSync => 'Συγχρονισμός ημερολογίου';

  @override
  String get onboardingProfileVisibility => 'Εμφάνιση προφίλ';

  @override
  String get settingsLanguageTitle => 'Γλώσσα Εφαρμογής';

  @override
  String get settingsLanguageSubtitle =>
      'Διάλεξε τη γλώσσα εμφάνισης σε όλο το dashboard.';

  @override
  String get settingsShowDeadlinesTitle => 'Εμφάνιση Προθεσμιών στο Ημερολόγιο';

  @override
  String get settingsShowDeadlinesSubtitle =>
      'Εμφάνιση projects & παρουσιάσεων στο ημερολόγιο της αρχικής σελίδας';

  @override
  String get settingsSyncCalendarTitle => 'Συγχρονισμός με Google Calendar';

  @override
  String get settingsSyncCalendarConnected =>
      '✓ Συνδεδεμένο — νέες εξετάσεις & προθεσμίες αποθηκεύονται αυτόματα';

  @override
  String get settingsSyncCalendarDisconnected =>
      'Αυτόματη προσθήκη εξετάσεων & προθεσμιών στο Google Calendar';

  @override
  String get settingsProfilePrivacyTitle => 'Απόρρητο Προφίλ';

  @override
  String get settingsShowBioTitle => 'Εμφάνιση Βιογραφικού';

  @override
  String get settingsShowBioSubtitle =>
      'Επιτρέπει σε άλλους να βλέπουν το κείμενο \"Σχετικά με μένα\"';

  @override
  String get settingsShowAchievementsTitle => 'Εμφάνιση Επιτευγμάτων';

  @override
  String get settingsShowAchievementsSubtitle =>
      'Επιτρέπει σε άλλους να βλέπουν τα ακαδημαϊκά σας επιτεύγματα';

  @override
  String get settingsShareGradesTitle => 'Κοινοποίηση Βαθμών';

  @override
  String get settingsShareGradesSubtitle =>
      'Εμφάνιση γραφημάτων προόδου και βαθμών στους συμμαθητές';

  @override
  String get settingsLogoutLabel => 'Αποσύνδεση';

  @override
  String get aiStudyAssistantTitle => 'AI Βοηθός Μελέτης';

  @override
  String get aiStudyAssistantSidebar => 'AI Βοηθός';

  @override
  String get aiNewChat => 'Νέα Συζήτηση';

  @override
  String get aiChatInProgress => 'Σε εξέλιξη';

  @override
  String get aiWelcomePitch =>
      'Γεια σου! Είμαι ο ScholiLink AI.\nΠώς μπορώ να σε βοηθήσω σήμερα;';

  @override
  String get aiAskAnythingHint => 'Ρώτα με οτιδήποτε...';

  @override
  String get aiHistorySection => 'Ιστορικό';

  @override
  String get aiChatHistoryDrawerTitle => 'Ιστορικό Συζητήσεων';

  @override
  String get aiNoChatsYet => 'Δεν υπάρχουν συζητήσεις ακόμα.';

  @override
  String get aiCopied => 'Αντιγράφηκε';

  @override
  String get aiCopy => 'Αντιγραφή';

  @override
  String get smartNotesTitle => 'Έξυπνες Σημειώσεις';

  @override
  String get smartNotesWelcome =>
      'Δημιούργησε έξυπνες σημειώσεις\nαπό το κείμενο ή τις εικόνες σου!';

  @override
  String get smartNotesNoteSettingsLabel => 'Ρυθμίσεις σημείωσης';

  @override
  String get smartNotesPasteOrAskHint =>
      'Επικόλλησε κείμενο ή κάνε μια ερώτηση...';

  @override
  String get smartNotesNewNotes => 'Νέες Σημειώσεις';

  @override
  String get smartNotesSidebarShort => 'Σημειώσεις';

  @override
  String get smartNotesHistoryDrawerTitle => 'Ιστορικό Σημειώσεων';

  @override
  String get smartNotesNoNotesYet => 'Δεν υπάρχουν σημειώσεις ακόμα.';

  @override
  String get smartNotesPromptFromImagesOnly =>
      'Δημιούργησε σημειώσεις από τις εικόνες που έστειλα.';

  @override
  String get smartNotesLengthSection => 'Μέγεθος σημείωσης';

  @override
  String get smartNotesDepthSection => 'Βάθος ανάλυσης';

  @override
  String get smartNotesLenShort => 'Σύντομη';

  @override
  String get smartNotesLenMedium => 'Μεσαία';

  @override
  String get smartNotesLenLong => 'Μεγάλη';

  @override
  String get smartNotesDepthBasic => 'Βασική';

  @override
  String get smartNotesDepthStandard => 'Τυπική';

  @override
  String get smartNotesDepthInDepth => 'Σε βάθος';
}
