String _normalizeGreek(String input) {
  final lower = input.toLowerCase().trim();
  const replacements = {
    'ά': 'α',
    'έ': 'ε',
    'ή': 'η',
    'ί': 'ι',
    'ϊ': 'ι',
    'ΐ': 'ι',
    'ό': 'ο',
    'ύ': 'υ',
    'ϋ': 'υ',
    'ΰ': 'υ',
    'ώ': 'ω',
  };
  var out = lower;
  replacements.forEach((k, v) => out = out.replaceAll(k, v));
  out = out.replaceAll(RegExp(r'^[\-\.\*•]+\s*'), '');
  return out
      .replaceAll(RegExp(r'[^a-z0-9α-ω\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? matchBestSubject(String extracted, List<String> availableSubjects) {
  if (extracted.trim().isEmpty || availableSubjects.isEmpty) return null;
  final target = _normalizeGreek(extracted);
  String? best;
  var bestScore = -1;
  for (final subject in availableSubjects) {
    final s = _normalizeGreek(subject);
    var score = 0;
    if (s == target) score += 100;
    if (s.contains(target) || target.contains(s)) score += 50;
    final targetTokens = target.split(' ').where((e) => e.isNotEmpty).toSet();
    final subjectTokens = s.split(' ').where((e) => e.isNotEmpty).toSet();
    score += targetTokens.intersection(subjectTokens).length * 10;
    if (score > bestScore) {
      bestScore = score;
      best = subject;
    }
  }
  if (bestScore < 8) return null;
  return best;
}

String? normalizeTermLabel(String raw, bool isGreek) {
  final t = raw.trim();
  if (t == '1ο Τετράμηνο' || t == '1st Term') {
    return isGreek ? '1ο Τετράμηνο' : '1st Term';
  }
  if (t == '2ο Τετράμηνο' || t == '2nd Term') {
    return isGreek ? '2ο Τετράμηνο' : '2nd Term';
  }
  if (t == 'Τελικές Εξετάσεις' || t == 'Final Exams') {
    return isGreek ? 'Τελικές Εξετάσεις' : 'Final Exams';
  }
  final n = _normalizeGreek(raw);
  if (n.contains('τελικ') || n.contains('exam') || n.contains('final')) {
    return isGreek ? 'Τελικές Εξετάσεις' : 'Final Exams';
  }
  final hasTetra = n.contains('τετρα') || n.contains('τετρ');
  if (hasTetra) {
    // Second term: "Β Τετράμηνο" → lowercase β; or explicit "2ο".
    if (n.startsWith('β') ||
        t.contains('2ο') ||
        n.contains('δευτ') ||
        t.startsWith('Β') ||
        t.startsWith('Β\'') ||
        t.startsWith('Β ')) {
      return isGreek ? '2ο Τετράμηνο' : '2nd Term';
    }
    return isGreek ? '1ο Τετράμηνο' : '1st Term';
  }
  if (n.contains('1') || n.contains('πρωτ')) {
    return isGreek ? '1ο Τετράμηνο' : '1st Term';
  }
  if (n.contains('2') || n.contains('δευτ')) {
    return isGreek ? '2ο Τετράμηνο' : '2nd Term';
  }
  return null;
}
