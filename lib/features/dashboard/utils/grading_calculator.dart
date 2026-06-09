import 'package:student_dashboard/features/dashboard/domain/grading_models.dart';

/// Calculates the base subject grade for a single branch or standalone subject.
/// Applies the logic for filling in missing term grades.
double calculateBaseSubjectGrade({
  required double? term1,
  required double? term2,
  double? finalExam,
  required SubjectType type,
}) {
  if (term1 == null && term2 == null && finalExam == null) {
    return 0.0;
  }

  double effectiveTerm1 = term1 ?? term2 ?? finalExam ?? 0.0;
  double effectiveTerm2 = term2 ?? term1 ?? finalExam ?? 0.0;

  // Base oral average for the year (rounded to 1 decimal internally)
  double annualOral = _roundTo1Decimal((effectiveTerm1 + effectiveTerm2) / 2);

  if (type == SubjectType.groupA && finalExam != null) {
    return _roundTo1Decimal((annualOral + finalExam) / 2);
  } else {
    // For GROUP_B, or if final grade is not available yet, just use the oral average
    return annualOral;
  }
}

/// Calculates the arithmetic mean (e.g. wrapper average or Γ.Μ.Ο.).
/// Ignores 0.0 values which represent empty/ungraded subjects.
double calculateGMO(List<double> grades) {
  var activeGrades = grades.where((g) => g > 0.0).toList();
  if (activeGrades.isEmpty) return 0.0;
  double sum = activeGrades.reduce((a, b) => a + b);
  return _roundTo1Decimal(sum / activeGrades.length);
}

double _roundTo1Decimal(double value) {
  // Greek grading usually relies on half-up rounding. toStringAsFixed handles this appropriately in Dart.
  return double.parse(value.toStringAsFixed(1));
}
