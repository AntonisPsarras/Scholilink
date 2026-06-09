/// Utility class for calculating grades according to the Greek public school system.
/// All grades are on a 0-20 scale.
class GradeCalculator {
  /// Calculates the annual grade for Gymnasio (Middle School) Group A subjects.
  /// Formula: 1/3 * (Term 1 + Term 2 + Final Exam)
  /// If terms or exams are missing, it calculates a running average based on available data.
  static double calculateGymnasioGroupA(
    double? term1,
    double? term2,
    double? exam,
  ) {
    if (term1 != null && term2 != null && exam != null) {
      return (term1 + term2 + exam) / 3.0;
    } else if (term1 != null && term2 != null) {
      return (term1 + term2) / 2.0;
    } else if (term1 != null) {
      return term1;
    } else if (term2 != null) {
      return term2;
    }
    return 0.0;
  }

  /// Calculates the annual grade for Gymnasio Group B and C subjects.
  /// Formula: Average of Term 1 and Term 2.
  static double calculateGymnasioGroupBC(double? term1, double? term2) {
    if (term1 != null && term2 != null) {
      return (term1 + term2) / 2.0;
    } else if (term1 != null) {
      return term1;
    } else if (term2 != null) {
      return term2;
    }
    return 0.0;
  }

  /// Checks if a Gymnasio student is promoted to the next grade.
  /// Rule: Score at least 10 in every subject, OR general average across all subjects >= 13.
  static bool checkGymnasioPromotion(List<double> subjectGrades) {
    if (subjectGrades.isEmpty) return false;

    bool passedAll = subjectGrades.every((grade) => grade >= 10.0);
    if (passedAll) return true;

    double sum = subjectGrades.fold(0.0, (prev, curr) => prev + curr);
    double generalAverage = sum / subjectGrades.length;

    return generalAverage >= 13.0;
  }

  /// Calculates the annual grade for 1st and 2nd Lyceum (High School).
  /// Formula: Average of Annual Oral Grade (average of two terms) and Final Written Exam.
  static double calculateLyceumGradesAB(
    double? term1,
    double? term2,
    double? exam,
  ) {
    double oralGrade = _calculateOralGrade(term1, term2);

    if (oralGrade > 0 && exam != null) {
      return (oralGrade + exam) / 2.0;
    } else if (oralGrade > 0) {
      return oralGrade;
    } else if (exam != null) {
      return exam;
    }
    return 0.0;
  }

  /// Calculates the annual grade for 3rd Lyceum.
  /// Formula: 60% Annual Oral Grade + 40% Final Written Exam.
  static double calculateLyceumGradeC(
    double? term1,
    double? term2,
    double? exam,
  ) {
    double oralGrade = _calculateOralGrade(term1, term2);

    if (oralGrade > 0 && exam != null) {
      return (oralGrade * 0.6) + (exam * 0.4);
    } else if (oralGrade > 0) {
      return oralGrade;
    } else if (exam != null) {
      return exam;
    }
    return 0.0;
  }

  /// Helper to calculate the Annual Oral Grade (average of available terms).
  static double _calculateOralGrade(double? term1, double? term2) {
    if (term1 != null && term2 != null) {
      return (term1 + term2) / 2.0;
    } else if (term1 != null) {
      return term1;
    } else if (term2 != null) {
      return term2;
    }
    return 0.0;
  }
}

/// Utility for calculating Panhellenic points (Moria).
class MoriaCalculator {
  /// Calculates total Panhellenic points (Moria).
  /// Formula: Sum(Grade_i * Weight_i) * 100
  /// [grades] should have exactly 4 values (0-20 scale).
  /// [orientation] determines the weight distribution for the subjects.
  static double calculateTotal(
    List<double> grades, {
    String orientation = 'Ανθρωπιστική',
  }) {
    if (grades.length != 4) return 0.0;

    // Greek system standard weights (1.3/0.7/0.7/0.7 coefficients)
    // Mapping 13.3%, 2.7%, 2.0%, 2.0% effectively
    List<double> weights;

    switch (orientation) {
      case 'Ανθρωπιστική':
        // Ancient Greek (3.3), History (2.7), Latin (2.0), Language (2.0)
        weights = [3.3, 2.7, 2.0, 2.0];
        break;
      case 'Θετική':
        // Math (3.3), Physics (2.7), Chemistry (2.0), Language (2.0)
        weights = [3.3, 2.7, 2.0, 2.0];
        break;
      case 'Υγεία':
        // Biology (3.3), Chemistry (2.7), Physics (2.0), Language (2.0)
        weights = [3.3, 2.7, 2.0, 2.0];
        break;
      case 'Οικονομία':
        // Math (3.3), Economics (2.7), Informatics (2.0), Language (2.0)
        weights = [3.3, 2.7, 2.0, 2.0];
        break;
      default:
        weights = [2.5, 2.5, 2.5, 2.5];
    }

    double total = 0.0;
    for (int i = 0; i < 4; i++) {
      total += grades[i] * weights[i];
    }
    return total * 100.0;
  }

  /// Returns subject names based on orientation.
  static List<String> getSubjectsForOrientation(String orientation) {
    switch (orientation) {
      case 'Ανθρωπιστική':
        return ['Αρχαία Ελληνικά', 'Ιστορία', 'Λατινικά', 'Νεοελληνική Γλώσσα'];
      case 'Θετική':
        return ['Μαθηματικά', 'Φυσική', 'Χημεία', 'Νεοελληνική Γλώσσα'];
      case 'Υγεία':
        return ['Βιολογία', 'Χημεία', 'Φυσική', 'Νεοελληνική Γλώσσα'];
      case 'Οικονομία':
        return [
          'Μαθηματικά',
          'Οικονομία (ΑΟΘ)',
          'Πληροφορική (ΑΕΠΠ)',
          'Νεοελληνική Γλώσσα',
        ];
      default:
        return ['Μάθημα 1', 'Μάθημα 2', 'Μάθημα 3', 'Μάθημα 4'];
    }
  }
}
