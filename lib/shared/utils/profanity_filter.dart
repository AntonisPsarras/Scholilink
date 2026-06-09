class ProfanityFilter {
  // A basic list of offensive words in Greek, Greeklish, and English.
  static const List<String> _blockedWordsRaw = [
    // English
    'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'dick', 'pussy', 'slut',
    'whore',
    'faggot', 'nigger', 'nigga', 'retard', 'kill yourself', 'kys',

    // Greek
    'μαλάκα', 'μαλακα', 'μαλάκας', 'μαλακας', 'πουτάνα', 'πουτανα', 'καριόλα',
    'καριολα',
    'γαμώ', 'γαμω', 'γ@μω', 'γαμιόλα', 'γαμιολα', 'αρχίδια', 'αρχιδια',
    'πούστη', 'πουστη',
    'πούστης', 'πουστης', 'ξεφτίλα', 'αλήτη', 'μπάσταρδε', 'μπασταρδε', 'ψόφα',
    'μουνί', 'μουνι',

    // Greeklish
    'malaka', 'malakas', 'poutana', 'kariola', 'gamo', 'gmaw', 'g@mw',
    'gamiola',
    'arxidia', 'arhidia', 'pousti', 'poustis', 'kseftila', 'aliti', 'mpastarde',
    'bastarde', 'psofa', 'mouni',
  ];

  static Set<String>? _normalizedBlockedWords;

  static Set<String> get _blockedWords {
    _normalizedBlockedWords ??= _blockedWordsRaw
        .map((w) => _normalize(w))
        .toSet();
    return _normalizedBlockedWords!;
  }

  /// Normalizes text by:
  /// 1. Lowercasing
  /// 2. Removing Greek accents (tonos)
  /// 3. Replacing common obfuscations (@ -> a, 0 -> o, 1 -> i, etc.)
  /// 4. Removing all punctuation and special characters
  static String _normalize(String text) {
    String t = text.toLowerCase();

    // Obfuscation replacement
    t = t
        .replaceAll('@', 'a')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('\$', 's')
        .replaceAll('!', 'i')
        .replaceAll('5', 's');

    // Unify similar look-alikes (Greek -> English equivalents for matching)
    final lookalikes = {
      'α': 'a',
      'β': 'b',
      'ε': 'e',
      'η': 'h',
      'ι': 'i',
      'κ': 'k',
      'ο': 'o',
      'ρ': 'p',
      'τ': 't',
      'υ': 'y',
      'χ': 'x',
      'ω': 'w',
    };

    // Greek Accent Removal & Unification
    final accentMap = {
      'ά': 'α',
      'έ': 'ε',
      'ή': 'η',
      'ί': 'ι',
      'ό': 'ο',
      'ύ': 'υ',
      'ώ': 'ω',
      'ϊ': 'ι',
      'ϋ': 'υ',
      'ΐ': 'ι',
      'ΰ': 'υ',
    };

    accentMap.forEach((accent, normal) {
      t = t.replaceAll(accent, normal);
    });

    lookalikes.forEach((greek, english) {
      t = t.replaceAll(greek, english);
    });

    // Remove everything that isn't a word character or whitespace
    return t.replaceAll(RegExp(r'[^\w\s]'), '');
  }

  /// Checks if the given text contains any profanity.
  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;

    final normalizedFull = _normalize(text);
    final words = normalizedFull.split(RegExp(r'\s+'));

    for (final word in words) {
      if (word.isNotEmpty && _blockedWords.contains(word)) {
        return true;
      }
    }

    // Also check for whole phrases in normalized text
    for (final badPhrase in _blockedWords.where((w) => w.contains(' '))) {
      if (normalizedFull.contains(badPhrase)) {
        return true;
      }
    }

    return false;
  }
}
