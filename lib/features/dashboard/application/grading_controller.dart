import 'package:student_dashboard/features/dashboard/domain/grading_models.dart';
import 'package:student_dashboard/features/dashboard/utils/grading_calculator.dart';

class GradingController {
  /// Calculates the final grades, groups wrapper subjects for grades 1 and 2,
  /// and computes the overall General Average (Γ.Μ.Ο.)
  GradingResult calculateStudentGrades(
    List<RawSubjectGrade> rawGrades,
    GradeLevel gradeLevel,
  ) {
    // 1. Calculate the base grade for all raw inputs
    List<ComputedSubjectGrade> allComputed = rawGrades.map((raw) {
      double fGrade = calculateBaseSubjectGrade(
        term1: raw.term1,
        term2: raw.term2,
        finalExam: raw.finalExam,
        type: raw.type,
      );
      return ComputedSubjectGrade(name: raw.name, finalGrade: fGrade);
    }).toList();

    // 2. If GradeLevel 3, wrappers are disabled entirely (all act as standalone)
    if (gradeLevel == GradeLevel.level3) {
      double gmo = calculateGMO(allComputed.map((e) => e.finalGrade).toList());
      return GradingResult(
        standaloneSubjects: allComputed,
        wrapperSubjects: [],
        gmo: gmo,
        isPassing: gmo >= 10.0,
      );
    }

    // 3. Wrapper logic for GradeLevel 1 & 2
    List<ComputedSubjectGrade> standalones = [];
    List<WrapperSubjectGrade> wrappers = [];

    List<ComputedSubjectGrade> ellinikiGlossa = [];
    List<ComputedSubjectGrade> mathimatika = [];
    List<ComputedSubjectGrade> fysikesEpistimes = [];

    // Safely group by string matching, ignoring accents and cases
    for (var computed in allComputed) {
      String name = computed.name.toLowerCase();
      String normalized = _removeGreekAccents(name);

      // Match Ελληνική Γλώσσα branches
      if (normalized.contains('αρχαια') ||
          normalized.contains('νεοελληνικη') ||
          normalized.contains('λογοτεχνια') ||
          normalized.contains('νεα ελληνικα')) {
        ellinikiGlossa.add(computed);
      }
      // Match Μαθηματικά branches
      else if (normalized.contains('αλγεβρα') ||
          normalized.contains('γεωμετρια')) {
        mathimatika.add(computed);
      }
      // Match Φυσικές Επιστήμες branches.
      // Need to avoid matching "Φυσική Αγωγή" (Physical Education)
      else if (normalized.contains('φυσικη') && !normalized.contains('αγωγη')) {
        fysikesEpistimes.add(computed);
      } else if (normalized.contains('χημεια') ||
          normalized.contains('βιολογια')) {
        fysikesEpistimes.add(computed);
      }
      // Everything else acts as standalone
      else {
        standalones.add(computed);
      }
    }

    void processWrapper(
      String wrapperName,
      List<ComputedSubjectGrade> branches,
    ) {
      if (branches.isNotEmpty) {
        double avg = calculateGMO(branches.map((e) => e.finalGrade).toList());
        wrappers.add(
          WrapperSubjectGrade(
            wrapperName: wrapperName,
            branches: branches,
            wrapperGrade: avg,
          ),
        );
      }
    }

    processWrapper('Ελληνική Γλώσσα', ellinikiGlossa);
    processWrapper('Μαθηματικά', mathimatika);
    processWrapper('Φυσικές Επιστήμες', fysikesEpistimes);

    // 4. Calculate Final GMO using the standalone subjects and wrapper averages
    List<double> finalAverages = [
      ...standalones.map((e) => e.finalGrade),
      ...wrappers.map((e) => e.wrapperGrade),
    ];

    double gmo = calculateGMO(finalAverages);

    return GradingResult(
      standaloneSubjects: standalones,
      wrapperSubjects: wrappers,
      gmo: gmo,
      isPassing: gmo >= 10.0,
    );
  }

  String _removeGreekAccents(String input) {
    const withDia = 'άέήίόύώϊϋΐΰ';
    const withoutDia = 'αεηιουωιυιυ';
    String result = input;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }
}
