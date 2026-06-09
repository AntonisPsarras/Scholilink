import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_el.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('el'),
    Locale('en'),
  ];

  /// No description provided for @language.
  ///
  /// In el, this message translates to:
  /// **'Γλώσσα'**
  String get language;

  /// No description provided for @languageGreek.
  ///
  /// In el, this message translates to:
  /// **'Ελληνικά'**
  String get languageGreek;

  /// No description provided for @languageEnglish.
  ///
  /// In el, this message translates to:
  /// **'Αγγλικά'**
  String get languageEnglish;

  /// No description provided for @pleaseLogIn.
  ///
  /// In el, this message translates to:
  /// **'Παρακαλώ συνδεθείτε'**
  String get pleaseLogIn;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In el, this message translates to:
  /// **'Καλώς ήρθατε!'**
  String get loginWelcomeTitle;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Καλώς ήρθατε στο ScholiLink'**
  String get loginWelcomeSubtitle;

  /// No description provided for @errorPrefix.
  ///
  /// In el, this message translates to:
  /// **'Σφάλμα: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @onboardingSelectGradeWarning.
  ///
  /// In el, this message translates to:
  /// **'Παρακαλώ επιλέξτε την τάξη σας'**
  String get onboardingSelectGradeWarning;

  /// No description provided for @onboardingSelectBirthDateWarning.
  ///
  /// In el, this message translates to:
  /// **'Παρακαλώ εισάγετε Ημερομηνία Γέννησης'**
  String get onboardingSelectBirthDateWarning;

  /// No description provided for @onboardingBirthDateLabel.
  ///
  /// In el, this message translates to:
  /// **'Ημερομηνία Γέννησης'**
  String get onboardingBirthDateLabel;

  /// No description provided for @onboardingBirthDateHint.
  ///
  /// In el, this message translates to:
  /// **'Επιλέξτε Ημερομηνία Γέννησης'**
  String get onboardingBirthDateHint;

  /// No description provided for @onboardingGradeHint.
  ///
  /// In el, this message translates to:
  /// **'Επιλέξτε Τάξη'**
  String get onboardingGradeHint;

  /// No description provided for @onboardingBack.
  ///
  /// In el, this message translates to:
  /// **'Πίσω'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In el, this message translates to:
  /// **'Επόμενο'**
  String get onboardingNext;

  /// No description provided for @onboardingSaveFinish.
  ///
  /// In el, this message translates to:
  /// **'Αποθήκευση & Ολοκλήρωση'**
  String get onboardingSaveFinish;

  /// No description provided for @onboardingValidationNationality.
  ///
  /// In el, this message translates to:
  /// **'Επιλέξτε εθνικότητα και σύστημα εκπαίδευσης.'**
  String get onboardingValidationNationality;

  /// No description provided for @onboardingValidationTutoring.
  ///
  /// In el, this message translates to:
  /// **'Επίλεξε τουλάχιστον ένα μάθημα ιδιαίτερων.'**
  String get onboardingValidationTutoring;

  /// No description provided for @onboardingValidationSubjects.
  ///
  /// In el, this message translates to:
  /// **'Προσθέστε τουλάχιστον ένα μάθημα.'**
  String get onboardingValidationSubjects;

  /// No description provided for @onboardingValidationDemographics.
  ///
  /// In el, this message translates to:
  /// **'Συμπληρώστε ημερομηνία γέννησης και έτος/τάξη.'**
  String get onboardingValidationDemographics;

  /// No description provided for @onboardingValidationGeneric.
  ///
  /// In el, this message translates to:
  /// **'Συμπλήρωσε το βήμα.'**
  String get onboardingValidationGeneric;

  /// No description provided for @onboardingNationalityTitle.
  ///
  /// In el, this message translates to:
  /// **'Επιλογή εθνικότητας'**
  String get onboardingNationalityTitle;

  /// No description provided for @onboardingNationalitySubtitle.
  ///
  /// In el, this message translates to:
  /// **'Πρώτα επιλέξτε εθνικότητα για να ορίσουμε τη σωστή διαδρομή.'**
  String get onboardingNationalitySubtitle;

  /// No description provided for @onboardingNationalityGreekTitle.
  ///
  /// In el, this message translates to:
  /// **'Ελληνική'**
  String get onboardingNationalityGreekTitle;

  /// No description provided for @onboardingNationalityGreekSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Προτεινόμενη επιλογή'**
  String get onboardingNationalityGreekSubtitle;

  /// No description provided for @onboardingNationalityOtherTitle.
  ///
  /// In el, this message translates to:
  /// **'Άλλη'**
  String get onboardingNationalityOtherTitle;

  /// No description provided for @onboardingNationalityOtherSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Διεθνές ή προσαρμοσμένο σύστημα'**
  String get onboardingNationalityOtherSubtitle;

  /// No description provided for @onboardingChooseSystemTitle.
  ///
  /// In el, this message translates to:
  /// **'Επίλεξε σύστημα'**
  String get onboardingChooseSystemTitle;

  /// No description provided for @onboardingSystemGreekTitle.
  ///
  /// In el, this message translates to:
  /// **'Ελληνικό Εκπαιδευτικό Σύστημα'**
  String get onboardingSystemGreekTitle;

  /// No description provided for @onboardingSystemGreekSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Ροή ελληνικών τάξεων με αγγλικό UI'**
  String get onboardingSystemGreekSubtitle;

  /// No description provided for @onboardingSystemCustomTitle.
  ///
  /// In el, this message translates to:
  /// **'Προσαρμοσμένο Σύστημα'**
  String get onboardingSystemCustomTitle;

  /// No description provided for @onboardingSystemCustomSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Πλήρως προσαρμοσμένα μαθήματα/έτη'**
  String get onboardingSystemCustomSubtitle;

  /// No description provided for @onboardingDemographicsTitle.
  ///
  /// In el, this message translates to:
  /// **'Δημογραφικά'**
  String get onboardingDemographicsTitle;

  /// No description provided for @onboardingTutoringTitle.
  ///
  /// In el, this message translates to:
  /// **'Ιδιαίτερα'**
  String get onboardingTutoringTitle;

  /// No description provided for @onboardingCustomSubjectsTitle.
  ///
  /// In el, this message translates to:
  /// **'Προσαρμοσμένα Μαθήματα'**
  String get onboardingCustomSubjectsTitle;

  /// No description provided for @onboardingCustomSubjectsSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Πρόσθεσε τα σχολικά σου μαθήματα.'**
  String get onboardingCustomSubjectsSubtitle;

  /// No description provided for @onboardingCustomGradeLabel.
  ///
  /// In el, this message translates to:
  /// **'Έτος / Τάξη'**
  String get onboardingCustomGradeLabel;

  /// No description provided for @onboardingCustomGradeHint.
  ///
  /// In el, this message translates to:
  /// **'π.χ. 2ο Έτος Λυκείου'**
  String get onboardingCustomGradeHint;

  /// No description provided for @onboardingCalendarTitle.
  ///
  /// In el, this message translates to:
  /// **'Σχολικό Ημερολόγιο'**
  String get onboardingCalendarTitle;

  /// No description provided for @onboardingCalendarSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Χρησιμοποίησε τον υπάρχοντα editor προγράμματος ή παράλειψε το βήμα.'**
  String get onboardingCalendarSubtitle;

  /// No description provided for @onboardingEditSchedule.
  ///
  /// In el, this message translates to:
  /// **'Επεξεργασία Προγράμματος'**
  String get onboardingEditSchedule;

  /// No description provided for @onboardingSkipForNow.
  ///
  /// In el, this message translates to:
  /// **'Παράλειψη για τώρα'**
  String get onboardingSkipForNow;

  /// No description provided for @onboardingPreferencesTitle.
  ///
  /// In el, this message translates to:
  /// **'Προτιμήσεις'**
  String get onboardingPreferencesTitle;

  /// No description provided for @onboardingCalendarSync.
  ///
  /// In el, this message translates to:
  /// **'Συγχρονισμός ημερολογίου'**
  String get onboardingCalendarSync;

  /// No description provided for @onboardingProfileVisibility.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση προφίλ'**
  String get onboardingProfileVisibility;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In el, this message translates to:
  /// **'Γλώσσα Εφαρμογής'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Διάλεξε τη γλώσσα εμφάνισης σε όλο το dashboard.'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsShowDeadlinesTitle.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση Προθεσμιών στο Ημερολόγιο'**
  String get settingsShowDeadlinesTitle;

  /// No description provided for @settingsShowDeadlinesSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση projects & παρουσιάσεων στο ημερολόγιο της αρχικής σελίδας'**
  String get settingsShowDeadlinesSubtitle;

  /// No description provided for @settingsSyncCalendarTitle.
  ///
  /// In el, this message translates to:
  /// **'Συγχρονισμός με Google Calendar'**
  String get settingsSyncCalendarTitle;

  /// No description provided for @settingsSyncCalendarConnected.
  ///
  /// In el, this message translates to:
  /// **'✓ Συνδεδεμένο — νέες εξετάσεις & προθεσμίες αποθηκεύονται αυτόματα'**
  String get settingsSyncCalendarConnected;

  /// No description provided for @settingsSyncCalendarDisconnected.
  ///
  /// In el, this message translates to:
  /// **'Αυτόματη προσθήκη εξετάσεων & προθεσμιών στο Google Calendar'**
  String get settingsSyncCalendarDisconnected;

  /// No description provided for @settingsProfilePrivacyTitle.
  ///
  /// In el, this message translates to:
  /// **'Απόρρητο Προφίλ'**
  String get settingsProfilePrivacyTitle;

  /// No description provided for @settingsShowBioTitle.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση Βιογραφικού'**
  String get settingsShowBioTitle;

  /// No description provided for @settingsShowBioSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Επιτρέπει σε άλλους να βλέπουν το κείμενο \"Σχετικά με μένα\"'**
  String get settingsShowBioSubtitle;

  /// No description provided for @settingsShowAchievementsTitle.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση Επιτευγμάτων'**
  String get settingsShowAchievementsTitle;

  /// No description provided for @settingsShowAchievementsSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Επιτρέπει σε άλλους να βλέπουν τα ακαδημαϊκά σας επιτεύγματα'**
  String get settingsShowAchievementsSubtitle;

  /// No description provided for @settingsShareGradesTitle.
  ///
  /// In el, this message translates to:
  /// **'Κοινοποίηση Βαθμών'**
  String get settingsShareGradesTitle;

  /// No description provided for @settingsShareGradesSubtitle.
  ///
  /// In el, this message translates to:
  /// **'Εμφάνιση γραφημάτων προόδου και βαθμών στους συμμαθητές'**
  String get settingsShareGradesSubtitle;

  /// No description provided for @settingsLogoutLabel.
  ///
  /// In el, this message translates to:
  /// **'Αποσύνδεση'**
  String get settingsLogoutLabel;

  /// No description provided for @aiStudyAssistantTitle.
  ///
  /// In el, this message translates to:
  /// **'AI Βοηθός Μελέτης'**
  String get aiStudyAssistantTitle;

  /// No description provided for @aiStudyAssistantSidebar.
  ///
  /// In el, this message translates to:
  /// **'AI Βοηθός'**
  String get aiStudyAssistantSidebar;

  /// No description provided for @aiNewChat.
  ///
  /// In el, this message translates to:
  /// **'Νέα Συζήτηση'**
  String get aiNewChat;

  /// No description provided for @aiChatInProgress.
  ///
  /// In el, this message translates to:
  /// **'Σε εξέλιξη'**
  String get aiChatInProgress;

  /// No description provided for @aiWelcomePitch.
  ///
  /// In el, this message translates to:
  /// **'Γεια σου! Είμαι ο ScholiLink AI.\nΠώς μπορώ να σε βοηθήσω σήμερα;'**
  String get aiWelcomePitch;

  /// No description provided for @aiAskAnythingHint.
  ///
  /// In el, this message translates to:
  /// **'Ρώτα με οτιδήποτε...'**
  String get aiAskAnythingHint;

  /// No description provided for @aiHistorySection.
  ///
  /// In el, this message translates to:
  /// **'Ιστορικό'**
  String get aiHistorySection;

  /// No description provided for @aiChatHistoryDrawerTitle.
  ///
  /// In el, this message translates to:
  /// **'Ιστορικό Συζητήσεων'**
  String get aiChatHistoryDrawerTitle;

  /// No description provided for @aiNoChatsYet.
  ///
  /// In el, this message translates to:
  /// **'Δεν υπάρχουν συζητήσεις ακόμα.'**
  String get aiNoChatsYet;

  /// No description provided for @aiCopied.
  ///
  /// In el, this message translates to:
  /// **'Αντιγράφηκε'**
  String get aiCopied;

  /// No description provided for @aiCopy.
  ///
  /// In el, this message translates to:
  /// **'Αντιγραφή'**
  String get aiCopy;

  /// No description provided for @smartNotesTitle.
  ///
  /// In el, this message translates to:
  /// **'Έξυπνες Σημειώσεις'**
  String get smartNotesTitle;

  /// No description provided for @smartNotesWelcome.
  ///
  /// In el, this message translates to:
  /// **'Δημιούργησε έξυπνες σημειώσεις\nαπό το κείμενο ή τις εικόνες σου!'**
  String get smartNotesWelcome;

  /// No description provided for @smartNotesNoteSettingsLabel.
  ///
  /// In el, this message translates to:
  /// **'Ρυθμίσεις σημείωσης'**
  String get smartNotesNoteSettingsLabel;

  /// No description provided for @smartNotesPasteOrAskHint.
  ///
  /// In el, this message translates to:
  /// **'Επικόλλησε κείμενο ή κάνε μια ερώτηση...'**
  String get smartNotesPasteOrAskHint;

  /// No description provided for @smartNotesNewNotes.
  ///
  /// In el, this message translates to:
  /// **'Νέες Σημειώσεις'**
  String get smartNotesNewNotes;

  /// No description provided for @smartNotesSidebarShort.
  ///
  /// In el, this message translates to:
  /// **'Σημειώσεις'**
  String get smartNotesSidebarShort;

  /// No description provided for @smartNotesHistoryDrawerTitle.
  ///
  /// In el, this message translates to:
  /// **'Ιστορικό Σημειώσεων'**
  String get smartNotesHistoryDrawerTitle;

  /// No description provided for @smartNotesNoNotesYet.
  ///
  /// In el, this message translates to:
  /// **'Δεν υπάρχουν σημειώσεις ακόμα.'**
  String get smartNotesNoNotesYet;

  /// No description provided for @smartNotesPromptFromImagesOnly.
  ///
  /// In el, this message translates to:
  /// **'Δημιούργησε σημειώσεις από τις εικόνες που έστειλα.'**
  String get smartNotesPromptFromImagesOnly;

  /// No description provided for @smartNotesLengthSection.
  ///
  /// In el, this message translates to:
  /// **'Μέγεθος σημείωσης'**
  String get smartNotesLengthSection;

  /// No description provided for @smartNotesDepthSection.
  ///
  /// In el, this message translates to:
  /// **'Βάθος ανάλυσης'**
  String get smartNotesDepthSection;

  /// No description provided for @smartNotesLenShort.
  ///
  /// In el, this message translates to:
  /// **'Σύντομη'**
  String get smartNotesLenShort;

  /// No description provided for @smartNotesLenMedium.
  ///
  /// In el, this message translates to:
  /// **'Μεσαία'**
  String get smartNotesLenMedium;

  /// No description provided for @smartNotesLenLong.
  ///
  /// In el, this message translates to:
  /// **'Μεγάλη'**
  String get smartNotesLenLong;

  /// No description provided for @smartNotesDepthBasic.
  ///
  /// In el, this message translates to:
  /// **'Βασική'**
  String get smartNotesDepthBasic;

  /// No description provided for @smartNotesDepthStandard.
  ///
  /// In el, this message translates to:
  /// **'Τυπική'**
  String get smartNotesDepthStandard;

  /// No description provided for @smartNotesDepthInDepth.
  ///
  /// In el, this message translates to:
  /// **'Σε βάθος'**
  String get smartNotesDepthInDepth;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['el', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
