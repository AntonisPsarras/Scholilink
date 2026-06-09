import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OnboardingNationality { greek, other }

enum OnboardingEducationSystem { greek, custom }

enum OnboardingStepType {
  nationality,
  greekDemographics,
  greekTutoring,
  greekCalendar,
  greekPreferences,
  internationalSubjects,
  internationalDemographics,
  internationalCalendar,
  internationalPreferences,
}

class OnboardingDraft {
  final OnboardingNationality? nationality;
  final OnboardingEducationSystem? educationSystem;
  final String preferredLanguage;
  final DateTime? dateOfBirth;
  final String? selectedYear;
  final String? selectedDirection;
  final String customGradeLabel;
  final List<String> subjects;
  final bool hasTutoring;
  final List<String> tutoringSubjects;
  final bool calendarSkipped;
  final bool autoAddHomework;
  final bool syncToDeviceCalendar;
  final bool showBio;
  final bool shareGrades;

  const OnboardingDraft({
    this.nationality,
    this.educationSystem,
    this.preferredLanguage = 'el',
    this.dateOfBirth,
    this.selectedYear,
    this.selectedDirection,
    this.customGradeLabel = '',
    this.subjects = const [],
    this.hasTutoring = false,
    this.tutoringSubjects = const [],
    this.calendarSkipped = false,
    this.autoAddHomework = false,
    this.syncToDeviceCalendar = false,
    this.showBio = true,
    this.shareGrades = false,
  });

  OnboardingDraft copyWith({
    OnboardingNationality? nationality,
    OnboardingEducationSystem? educationSystem,
    String? preferredLanguage,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    String? selectedYear,
    String? selectedDirection,
    String? customGradeLabel,
    List<String>? subjects,
    bool? hasTutoring,
    List<String>? tutoringSubjects,
    bool? calendarSkipped,
    bool? autoAddHomework,
    bool? syncToDeviceCalendar,
    bool? showBio,
    bool? shareGrades,
  }) {
    return OnboardingDraft(
      nationality: nationality ?? this.nationality,
      educationSystem: educationSystem ?? this.educationSystem,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      selectedYear: selectedYear ?? this.selectedYear,
      selectedDirection: selectedDirection ?? this.selectedDirection,
      customGradeLabel: customGradeLabel ?? this.customGradeLabel,
      subjects: subjects ?? this.subjects,
      hasTutoring: hasTutoring ?? this.hasTutoring,
      tutoringSubjects: tutoringSubjects ?? this.tutoringSubjects,
      calendarSkipped: calendarSkipped ?? this.calendarSkipped,
      autoAddHomework: autoAddHomework ?? this.autoAddHomework,
      syncToDeviceCalendar: syncToDeviceCalendar ?? this.syncToDeviceCalendar,
      showBio: showBio ?? this.showBio,
      shareGrades: shareGrades ?? this.shareGrades,
    );
  }
}

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void setNationality(OnboardingNationality nationality) {
    if (nationality == OnboardingNationality.greek) {
      state = state.copyWith(
        nationality: nationality,
        educationSystem: OnboardingEducationSystem.greek,
        preferredLanguage: 'el',
      );
      return;
    }
    state = state.copyWith(nationality: nationality, preferredLanguage: 'en');
  }

  void setOtherSystem(OnboardingEducationSystem system) {
    state = state.copyWith(educationSystem: system, preferredLanguage: 'en');
  }

  bool get isGreekPath =>
      state.educationSystem == OnboardingEducationSystem.greek;

  List<OnboardingStepType> buildStepsForBranch() {
    final base = <OnboardingStepType>[OnboardingStepType.nationality];
    if (state.educationSystem == null) return base;

    if (isGreekPath) {
      return [
        ...base,
        OnboardingStepType.greekDemographics,
        OnboardingStepType.greekTutoring,
        OnboardingStepType.greekCalendar,
        OnboardingStepType.greekPreferences,
      ];
    }
    return [
      ...base,
      OnboardingStepType.internationalSubjects,
      OnboardingStepType.internationalDemographics,
      OnboardingStepType.internationalCalendar,
      OnboardingStepType.internationalPreferences,
    ];
  }

  bool canProceed(OnboardingStepType step) {
    switch (step) {
      case OnboardingStepType.nationality:
        return state.nationality != null && state.educationSystem != null;
      case OnboardingStepType.greekDemographics:
        if (state.dateOfBirth == null || state.selectedYear == null) {
          return false;
        }
        final requiresDirection =
            state.selectedYear == "Β' Λυκείου" ||
            state.selectedYear == "Γ' Λυκείου";
        return !requiresDirection || state.selectedDirection != null;
      case OnboardingStepType.greekTutoring:
        if (!state.hasTutoring) return true;
        return state.tutoringSubjects.isNotEmpty;
      case OnboardingStepType.greekCalendar:
      case OnboardingStepType.internationalCalendar:
        return true;
      case OnboardingStepType.greekPreferences:
      case OnboardingStepType.internationalPreferences:
        return true;
      case OnboardingStepType.internationalSubjects:
        return state.subjects.isNotEmpty;
      case OnboardingStepType.internationalDemographics:
        return state.dateOfBirth != null &&
            state.customGradeLabel.trim().isNotEmpty;
    }
  }

  void setDateOfBirth(DateTime date) {
    state = state.copyWith(dateOfBirth: date);
  }

  void setGreekYear(String? year) {
    state = state.copyWith(
      selectedYear: year,
      selectedDirection: null,
      subjects: _subjectsForGreekSelection(year: year, direction: null),
      tutoringSubjects: const [],
    );
  }

  void setGreekDirection(String? direction) {
    state = state.copyWith(
      selectedDirection: direction,
      subjects: _subjectsForGreekSelection(
        year: state.selectedYear,
        direction: direction,
      ),
      tutoringSubjects: const [],
    );
  }

  void setHasTutoring(bool hasTutoring) {
    state = state.copyWith(
      hasTutoring: hasTutoring,
      tutoringSubjects: hasTutoring ? state.tutoringSubjects : const [],
    );
  }

  void toggleTutoringSubject(String subject) {
    final next = [...state.tutoringSubjects];
    if (next.contains(subject)) {
      next.remove(subject);
    } else {
      next.add(subject);
    }
    state = state.copyWith(tutoringSubjects: next);
  }

  void addCustomSubject(String subject) {
    final trimmed = subject.trim();
    if (trimmed.isEmpty) return;
    if (state.subjects.contains(trimmed)) return;
    state = state.copyWith(subjects: [...state.subjects, trimmed]);
  }

  void removeCustomSubject(String subject) {
    state = state.copyWith(
      subjects: state.subjects.where((s) => s != subject).toList(),
      tutoringSubjects: state.tutoringSubjects
          .where((s) => s != subject)
          .toList(),
    );
  }

  void setCustomGradeLabel(String value) {
    state = state.copyWith(customGradeLabel: value);
  }

  void setCalendarSkipped(bool skipped) {
    state = state.copyWith(calendarSkipped: skipped);
  }

  void setAutoAddHomework(bool value) {
    state = state.copyWith(autoAddHomework: value);
  }

  void setSyncToDeviceCalendar(bool value) {
    state = state.copyWith(syncToDeviceCalendar: value);
  }

  void setShowBio(bool value) {
    state = state.copyWith(showBio: value);
  }

  void setShareGrades(bool value) {
    state = state.copyWith(shareGrades: value);
  }

  String buildCurrentClassLabel() {
    if (isGreekPath) {
      final year = state.selectedYear ?? '';
      final direction = state.selectedDirection;
      if (direction == null || direction.isEmpty) return year;
      return '$year - $direction';
    }
    return state.customGradeLabel.trim();
  }

  List<String> _subjectsForGreekSelection({
    required String? year,
    required String? direction,
  }) {
    if (year == null) return const [];
    if ((year == "Β' Λυκείου" || year == "Γ' Λυκείου") && direction != null) {
      return [
        ...(_greekSubjectMapping["$year - Γενικής Παιδείας"] ?? const []),
        ...(_greekSubjectMapping["$year - $direction"] ?? const []),
      ];
    }
    return _greekSubjectMapping[year] ?? const [];
  }
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

const List<String> greekYears = [
  "Α' Γυμνασίου",
  "Β' Γυμνασίου",
  "Γ' Γυμνασίου",
  "Α' Λυκείου",
  "Β' Λυκείου",
  "Γ' Λυκείου",
];

const Map<String, List<String>> greekDirectionsForYear = {
  "Β' Λυκείου": ['Ανθρωπιστικών', 'Θετικών Σπουδών'],
  "Γ' Λυκείου": [
    'Ανθρωπιστικών',
    'Θετικών Σπουδών',
    'Σπουδών Υγείας',
    'Οικονομίας/Πληροφορικής',
  ],
};

const Map<String, List<String>> _greekSubjectMapping = {
  "Α' Γυμνασίου": [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Οδύσσεια',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Γεωγραφία',
    'Οικιακή Οικονομία',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  "Β' Γυμνασίου": [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Ιλιάδα',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Γεωγραφία',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  "Γ' Γυμνασίου": [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Ελένη',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Κοινωνική & Πολιτική Αγωγή',
    'Τεχνολογία',
    'Πληροφορική',
    'Μουσική',
    'Εικαστικά',
    'Φυσική Αγωγή',
    'Εργαστήρια Δεξιοτήτων',
  ],
  "Α' Λυκείου": [
    'Νέα Ελληνική Γλώσσα',
    'Νεοελληνική Λογοτεχνία',
    'Αρχαία Ελληνικά',
    'Αγγλικά',
    'Άλγεβρα',
    'Γεωμετρία',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Θρησκευτικά',
    'Κοινωνική & Πολιτική Αγωγή',
    'Εφαρμογές Πληροφορικής',
    '2η Ξένη Γλώσσα',
    'Φυσική Αγωγή',
  ],
  "Β' Λυκείου - Γενικής Παιδείας": [
    'Νεοελληνική Γλώσσα και Λογοτεχνία',
    'Αρχαία Ελληνικά — Σοφοκλέους Αντιγόνη / Θουκυδίδη Περικλέους Επιτάφιος',
    'Άλγεβρα',
    'Γεωμετρία',
    'Φυσική',
    'Χημεία',
    'Βιολογία',
    'Ιστορία',
    'Φιλοσοφία (ή μάθημα επιλογής)',
    'Αγγλικά',
    '2η Ξένη Γλώσσα',
    'Θρησκευτικά',
    'Φυσική Αγωγή',
  ],
  "Β' Λυκείου - Ανθρωπιστικών": [
    'Αρχαία Ελληνική Γλώσσα και Γραμματεία',
    'Λατινικά',
  ],
  "Β' Λυκείου - Θετικών Σπουδών": [
    'Μαθηματικά Προσανατολισμού',
    'Φυσική Προσανατολισμού',
  ],
  "Γ' Λυκείου - Γενικής Παιδείας": [
    'Νεοελληνική Γλώσσα και Λογοτεχνία',
    'Θρησκευτικά',
    'Αγγλικά',
    'Φυσική Αγωγή',
    'Ιστορία',
  ],
  "Γ' Λυκείου - Ανθρωπιστικών": ['Αρχαία Ελληνικά', 'Λατινικά', 'Ιστορία'],
  "Γ' Λυκείου - Θετικών Σπουδών": ['Μαθηματικά', 'Φυσική', 'Χημεία'],
  "Γ' Λυκείου - Σπουδών Υγείας": ['Βιολογία', 'Φυσική', 'Χημεία'],
  "Γ' Λυκείου - Οικονομίας/Πληροφορικής": [
    'Μαθηματικά',
    'Πληροφορική',
    'Οικονομία',
  ],
};
