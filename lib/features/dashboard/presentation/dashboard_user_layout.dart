import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../../auth/domain/user_model.dart';

/// Immutable snapshot of [AppUser] fields that affect dashboard layout and copy.
/// Used with [Provider.select] so high-churn fields (e.g. [AppUser.aiSparks])
/// do not rebuild the whole dashboard.
@immutable
class DashboardUserLayout {
  final String preferredLanguage;
  final String greetingFirstName;
  final String? currentClass;
  final bool hasTakenSampleTest;
  final int absences;
  final List<String> subjects;
  final List<String> classroomIds;
  final bool showMoriaCalculator;

  /// Same as [AppUser.scheduleExamClassId] — use for exams, calendar, homework stream, schedules.
  final String scheduleExamClassId;

  const DashboardUserLayout({
    required this.preferredLanguage,
    required this.greetingFirstName,
    required this.currentClass,
    required this.hasTakenSampleTest,
    required this.absences,
    required this.subjects,
    required this.classroomIds,
    required this.showMoriaCalculator,
    required this.scheduleExamClassId,
  });

  factory DashboardUserLayout.fromUser(AppUser u) {
    final trimmed = u.fullName.trim();
    final first = trimmed.isEmpty ? '' : trimmed.split(RegExp(r'\s+')).first;
    final cc = u.currentClass;
    final moria = cc != null && cc.startsWith('Γ\' Λυκείου');
    return DashboardUserLayout(
      preferredLanguage: u.preferredLanguage,
      greetingFirstName: first,
      currentClass: cc,
      hasTakenSampleTest: u.hasTakenSampleTest,
      absences: u.absences,
      subjects: List<String>.from(u.subjects),
      classroomIds: List<String>.from(u.classroomIds),
      showMoriaCalculator: moria,
      scheduleExamClassId: u.scheduleExamClassId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardUserLayout &&
        other.preferredLanguage == preferredLanguage &&
        other.greetingFirstName == greetingFirstName &&
        other.currentClass == currentClass &&
        other.hasTakenSampleTest == hasTakenSampleTest &&
        other.absences == absences &&
        listEquals(other.subjects, subjects) &&
        listEquals(other.classroomIds, classroomIds) &&
        other.showMoriaCalculator == showMoriaCalculator &&
        other.scheduleExamClassId == scheduleExamClassId;
  }

  @override
  int get hashCode => Object.hash(
    preferredLanguage,
    greetingFirstName,
    currentClass,
    hasTakenSampleTest,
    absences,
    Object.hashAll(subjects),
    Object.hashAll(classroomIds),
    showMoriaCalculator,
    scheduleExamClassId,
  );
}
