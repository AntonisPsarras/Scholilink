enum GradeLevel { level1, level2, level3 }

enum SubjectType { groupA, groupB }

class RawSubjectGrade {
  final String name;
  final SubjectType type;
  final double? term1;
  final double? term2;
  final double? finalExam;

  const RawSubjectGrade({
    required this.name,
    required this.type,
    this.term1,
    this.term2,
    this.finalExam,
  });
}

class ComputedSubjectGrade {
  final String name;
  final double finalGrade;

  const ComputedSubjectGrade({required this.name, required this.finalGrade});
}

class WrapperSubjectGrade {
  final String wrapperName;
  final List<ComputedSubjectGrade> branches;
  final double wrapperGrade;

  const WrapperSubjectGrade({
    required this.wrapperName,
    required this.branches,
    required this.wrapperGrade,
  });
}

class GradingResult {
  final List<ComputedSubjectGrade> standaloneSubjects;
  final List<WrapperSubjectGrade> wrapperSubjects;
  final double gmo;
  final bool isPassing;

  const GradingResult({
    required this.standaloneSubjects,
    required this.wrapperSubjects,
    required this.gmo,
    required this.isPassing,
  });
}
