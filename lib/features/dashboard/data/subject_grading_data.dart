enum SchoolLevel { gymnasio, lyceum }

class SubjectExamInfo {
  final SchoolLevel level;
  final String grade; // Α, Β, Γ
  final String direction; // Γενική, Ανθρωπιστικών, κλπ
  final String subject;
  final String type; // Βασικό, Προσανατολισμού

  const SubjectExamInfo({
    required this.level,
    required this.grade,
    required this.direction,
    required this.subject,
    required this.type,
  });
}

class SubjectGradingData {
  static const List<SubjectExamInfo> finalExamSubjects = [
    // Γυμνάσιο Α
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Νεοελληνική Γλώσσα και Γραμματεία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Αρχαία Ελληνικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Μαθηματικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Φυσική',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Ιστορία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Βιολογία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Αγγλικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Οδύσσεια',
      type: 'Βασικό',
    ),

    // Γυμνάσιο Β
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Νεοελληνική Γλώσσα και Γραμματεία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Αρχαία Ελληνικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Μαθηματικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Φυσική',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Ιστορία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Βιολογία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Αγγλικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Ιλιάδα',
      type: 'Βασικό',
    ),

    // Γυμνάσιο Γ
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Νεοελληνική Γλώσσα και Γραμματεία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Αρχαία Ελληνικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Μαθηματικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Φυσική',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Ιστορία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Βιολογία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Αγγλικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.gymnasio,
      grade: 'Γ',
      direction: 'Γενική',
      subject: 'Ελένη',
      type: 'Βασικό',
    ),

    // Λύκειο Α
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Νέα Ελληνικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Αρχαία Ελληνική Γλώσσα και Γραμματεία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Ιστορία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Άλγεβρα',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Γεωμετρία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Φυσική',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Χημεία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Α',
      direction: 'Γενική',
      subject: 'Αγγλικά',
      type: 'Βασικό',
    ),

    // Λύκειο Β
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Νεοελληνική Γλώσσα και Λογοτεχνία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Ιστορία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Άλγεβρα',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Γεωμετρία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Βιολογία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Γενική',
      subject: 'Αγγλικά',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Αρχαία Ελληνικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Λατινικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Θετικών Σπουδών',
      subject: 'Μαθηματικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Β',
      direction: 'Θετικών Σπουδών',
      subject: 'Φυσική',
      type: 'Προσανατολισμού',
    ),

    // Λύκειο Γ
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Νεοελληνική Γλώσσα και Λογοτεχνία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Μαθηματικά (Γενικής Παιδείας)',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Αρχαία Ελληνικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Ιστορία',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Ανθρωπιστικών Σπουδών',
      subject: 'Λατινικά',
      type: 'Προσανατολισμού',
    ),

    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Θετικών Σπουδών',
      subject: 'Νεοελληνική Γλώσσα και Λογοτεχνία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Θετικών Σπουδών',
      subject: 'Ιστορία (Γενικής Παιδείας)',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Θετικών Σπουδών',
      subject: 'Μαθηματικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Θετικών Σπουδών',
      subject: 'Φυσική',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Θετικών Σπουδών',
      subject: 'Χημεία',
      type: 'Προσανατολισμού',
    ),

    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Νεοελληνική Γλώσσα και Λογοτεχνία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Ιστορία (Γενικής Παιδείας)',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Φυσική',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Χημεία',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Βιολογία',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Υγείας',
      subject: 'Μαθηματικά (Γενικής Παιδείας)',
      type: 'Βασικό',
    ),

    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Οικονομίας και Πληροφορικής',
      subject: 'Νεοελληνική Γλώσσα και Λογοτεχνία',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Οικονομίας και Πληροφορικής',
      subject: 'Ιστορία (Γενικής Παιδείας)',
      type: 'Βασικό',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Οικονομίας και Πληροφορικής',
      subject: 'Μαθηματικά',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Οικονομίας και Πληροφορικής',
      subject: 'Πληροφορική',
      type: 'Προσανατολισμού',
    ),
    SubjectExamInfo(
      level: SchoolLevel.lyceum,
      grade: 'Γ',
      direction: 'Σπουδών Οικονομίας και Πληροφορικής',
      subject: 'Οικονομία',
      type: 'Προσανατολισμού',
    ),
  ];

  static bool hasFinalExam(String subject, String currentClass) {
    // CurrentClass format is usually "Α' Γυμνασίου" or "Β' Λυκείου - Ανθρωπιστικών"
    final level = currentClass.contains('Γυμνασίου')
        ? SchoolLevel.gymnasio
        : SchoolLevel.lyceum;

    // Extract grade (A, B, G) - actually we need to map the Greek characters
    String gradeChar = '';
    if (currentClass.startsWith('Α')) {
      gradeChar = 'Α';
    } else if (currentClass.startsWith('Β')) {
      gradeChar = 'Β';
    } else if (currentClass.startsWith('Γ')) {
      gradeChar = 'Γ';
    }

    // Extract direction
    String direction = 'Γενική'; // default
    if (currentClass.contains(' - ')) {
      direction = currentClass.split(' - ').last;
      // Handle slight name differences in direction
      if (direction.contains('Ανθρωπιστικών'))
        direction = 'Ανθρωπιστικών Σπουδών';
      if (direction.contains('Θετικών')) direction = 'Θετικών Σπουδών';
      if (direction.contains('Υγείας')) direction = 'Σπουδών Υγείας';
      if (direction.contains('Οικονομίας'))
        direction = 'Σπουδών Οικονομίας και Πληροφορικής';
    }

    // Normalize subject name for comparison
    final normalizedSubject = subject.trim();

    return finalExamSubjects.any(
      (info) =>
          info.level == level &&
          info.grade == gradeChar &&
          (info.direction == direction || info.direction == 'Γενική') &&
          _isSameSubject(info.subject, normalizedSubject),
    );
  }

  static bool _isSameSubject(String csvSubject, String appSubject) {
    if (csvSubject == appSubject) return true;

    // Explicit exclusions for false positives from 'contains'
    if (appSubject.contains('Φυσική Αγωγή') && !csvSubject.contains('Αγωγή'))
      return false;
    if (csvSubject.contains('Φυσική Αγωγή') && !appSubject.contains('Αγωγή'))
      return false;

    if (appSubject.contains('Αντιγόνη') && !csvSubject.contains('Αντιγόνη'))
      return false;
    if (csvSubject.contains('Αντιγόνη') && !appSubject.contains('Αντιγόνη'))
      return false;

    // Fuzzy matching for common subjects that might have slightly different names
    final map = {
      'Νεοελληνική Γλώσσα και Γραμματεία': [
        'Νεοελληνική Γλώσσα',
        'Νέα Ελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
        'Νεοελληνική Γλώσσα και Λογοτεχνία',
      ],
      'Μαθηματικά': [
        'Μαθηματικά (Άλγεβρα & Γεωμετρία)',
        'Άλγεβρα',
        'Γεωμετρία',
        'Μαθηματικά Προσανατολισμού',
      ],
      'Νέα Ελληνικά': [
        'Νεοελληνική Γλώσσα και Λογοτεχνία',
        'Νεοελληνική Γλώσσα',
        'Νέα Ελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
      ],
      'Αρχαία Ελληνικά': [
        'Αρχαία Ελληνική Γλώσσα και Γραμματεία',
        'Αρχαία',
        'Αρχαία Ελληνικά (Προσανατολισμού)',
      ],
      'Νεοελληνική Γλώσσα και Λογοτεχνία': [
        'Νέα Ελληνικά',
        'Νεοελληνική Γλώσσα',
        'Νεοελληνική Λογοτεχνία',
      ],
    };

    if (map[csvSubject]?.contains(appSubject) ?? false) return true;
    if (map[appSubject]?.contains(csvSubject) ?? false) return true;

    // Fallback: check if one contains the other (case insensitive and space-trimmed)
    final s1 = csvSubject.replaceAll(' ', '').toLowerCase();
    final s2 = appSubject.replaceAll(' ', '').toLowerCase();

    return s1.contains(s2) || s2.contains(s1);
  }
}
