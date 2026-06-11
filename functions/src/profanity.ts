/** Keep in sync with `lib/shared/utils/profanity_filter.dart`. */
const BLOCKED_WORDS_RAW = [
  'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'dick', 'pussy', 'slut',
  'whore',
  'faggot', 'nigger', 'nigga', 'retard', 'kill yourself', 'kys',
  'μαλάκα', 'μαλακα', 'μαλάκας', 'μαλακας', 'πουτάνα', 'πουτανα', 'καριόλα',
  'καριολα',
  'γαμώ', 'γαμω', 'γ@μω', 'γαμιόλα', 'γαμιολα', 'αρχίδια', 'αρχιδια',
  'πούστη', 'πουστη',
  'πούστης', 'πουστης', 'ξεφτίλα', 'αλήτη', 'μπάσταρδε', 'μπασταρδε', 'ψόφα',
  'μουνί', 'μουνι',
  'malaka', 'malakas', 'poutana', 'kariola', 'gamo', 'gmaw', 'g@mw',
  'gamiola',
  'arxidia', 'arhidia', 'pousti', 'poustis', 'kseftila', 'aliti', 'mpastarde',
  'bastarde', 'psofa', 'mouni',
];

const ACCENT_MAP: Record<string, string> = {
  'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
  'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ',
};

const LOOKALIKES: Record<string, string> = {
  'α': 'a', 'β': 'b', 'ε': 'e', 'η': 'h', 'ι': 'i', 'κ': 'k', 'ο': 'o',
  'ρ': 'p', 'τ': 't', 'υ': 'y', 'χ': 'x', 'ω': 'w',
};

function normalizeProfanityText(text: string): string {
  let t = text.toLowerCase();
  t = t
    .replaceAll('@', 'a')
    .replaceAll('0', 'o')
    .replaceAll('1', 'i')
    .replaceAll('3', 'e')
    .replaceAll('$', 's')
    .replaceAll('!', 'i')
    .replaceAll('5', 's');

  for (const [accent, normal] of Object.entries(ACCENT_MAP)) {
    t = t.replaceAll(accent, normal);
  }
  for (const [greek, english] of Object.entries(LOOKALIKES)) {
    t = t.replaceAll(greek, english);
  }
  return t.replace(/[^\w\s]/g, '');
}

const NORMALIZED_BLOCKED_WORDS = new Set(
  BLOCKED_WORDS_RAW.map((w) => normalizeProfanityText(w)),
);

/** Deterministic profanity check (mirrors Flutter [ProfanityFilter]). */
export function containsProfanity(text: string): boolean {
  if (!text.trim()) return false;

  const normalizedFull = normalizeProfanityText(text);
  const words = normalizedFull.split(/\s+/);
  for (const word of words) {
    if (word && NORMALIZED_BLOCKED_WORDS.has(word)) {
      return true;
    }
  }

  for (const badPhrase of NORMALIZED_BLOCKED_WORDS) {
    if (badPhrase.includes(' ') && normalizedFull.includes(badPhrase)) {
      return true;
    }
  }
  return false;
}
