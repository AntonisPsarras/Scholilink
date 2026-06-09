import {createHash, randomBytes, randomInt, timingSafeEqual} from 'crypto';
import {defineSecret} from 'firebase-functions/params';
import {setGlobalOptions} from 'firebase-functions/v2';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {logger} from 'firebase-functions';
import * as admin from 'firebase-admin';
import {GoogleGenerativeAI} from '@google/generative-ai';
import type {GenerateContentResult} from '@google/generative-ai';

// Match existing Cloud Run deployment region (see GCP console).
setGlobalOptions({region: 'us-central1', memory: '512MiB'});

admin.initializeApp();
const db = admin.firestore();

/**
 * Names must differ from plain `EMAILJS_*` env vars. Firebase CLI injects `.env` /
 * `.env.<projectId>` as non-secret env vars; Cloud Run rejects the same key as both
 * plain and secret. Use `PARENT_CONSENT_EMAILJS_*` secrets only for this callable.
 */
const emailJsServiceId = defineSecret('PARENT_CONSENT_EMAILJS_SERVICE_ID');
const emailJsTemplateId = defineSecret('PARENT_CONSENT_EMAILJS_TEMPLATE_ID');
const emailJsPublicKey = defineSecret('PARENT_CONSENT_EMAILJS_PUBLIC_KEY');
const emailJsPrivateKey = defineSecret('PARENT_CONSENT_EMAILJS_PRIVATE_KEY');

/** Separate EmailJS template for ScholiLink Pro email activation (avoids coupling to parental-consent secrets). */
const proActivationEmailJsServiceId = defineSecret('PRO_ACTIVATION_EMAILJS_SERVICE_ID');
const proActivationEmailJsTemplateId = defineSecret('PRO_ACTIVATION_EMAILJS_TEMPLATE_ID');
const proActivationEmailJsPublicKey = defineSecret('PRO_ACTIVATION_EMAILJS_PUBLIC_KEY');
const proActivationEmailJsPrivateKey = defineSecret('PRO_ACTIVATION_EMAILJS_PRIVATE_KEY');
/** Server-only pepper for hashing one-time activation codes stored under `user_private/{uid}` */
const proActivationCodePepper = defineSecret('PRO_ACTIVATION_CODE_PEPPER');

/**
 * Gemini API key for @google/generative-ai (Google AI Studio).
 *
 * Set runtime env var `GOOGLE_AI_API_KEY` for the function service.
 *
 * Create a key: https://aistudio.google.com/apikey — enable "Generative Language API" on the GCP project.
 */
function resolveGoogleAiApiKey(): string {
  const fromEnv = process.env.GOOGLE_AI_API_KEY?.trim();
  if (fromEnv) return fromEnv;
  return '';
}

function resolveTavilyApiKey(): string {
  const fromEnv = process.env.TAVILY_API_KEY?.trim();
  if (fromEnv) return fromEnv;
  return '';
}

function sanitizeUserApiKey(raw: unknown): string {
  if (typeof raw !== 'string') return '';
  const trimmed = raw.trim();
  if (!trimmed) return '';
  return /^AIza[\w-]{20,}$/.test(trimmed) ? trimmed : '';
}

async function runWebContextSearch(query: string, tavilyKey: string): Promise<string[]> {
  if (!query.trim() || !tavilyKey) return [];
  try {
    const res = await fetch('https://api.tavily.com/search', {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({
        api_key: tavilyKey,
        query,
        max_results: 5,
        search_depth: 'basic',
      }),
    });
    const body = await res.text();
    if (!res.ok) {
      logger.error('Tavily search failed', {status: res.status, body: body.slice(0, 500)});
      return [];
    }
    const parsed = parseJsonObject<Record<string, unknown>>(body, {});
    const results = Array.isArray(parsed.results) ? parsed.results : [];
    return results
      .filter((row): row is Record<string, unknown> => !!row && typeof row === 'object')
      .map((row) => {
        const title = firstNonEmptyString(row.title);
        const content = firstNonEmptyString(row.content);
        const url = firstNonEmptyString(row.url);
        return [title, content, url].filter(Boolean).join(' | ');
      })
      .filter(Boolean)
      .slice(0, 5);
  } catch (error) {
    logger.error('Tavily search exception', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : '',
    });
    return [];
  }
}

/**
 * Callable clients often strip custom messages for HttpsError code "internal".
 * Use a different code so Flutter can show the real hint in debug/UI.
 */
function throwVisibleAiFailure(prefix: string, error: unknown): never {
  const raw = error instanceof Error ? error.message : String(error);
  const noSecrets = raw.replace(/AIza[\w-]{10,}/gi, '[API_KEY_REDACTED]').slice(0, 400);
  const msg = `${prefix}${noSecrets.trim() ? `: ${noSecrets.trim()}` : ''}`;
  console.error('throwVisibleAiFailure:', prefix, raw);
  throw new HttpsError('failed-precondition', msg.length > 280 ? `${msg.slice(0, 277)}...` : msg);
}

/**
 * Model id for Google AI Studio / Generative Language API (override via env `GEMINI_MODEL`).
 * Default `gemini-2.5-flash`; set `GEMINI_MODEL` in Cloud Run / emulator if your key uses another id.
 */
const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || 'gemini-2.5-flash';

/** HTTPS consent page parents open from the approval email. */
function resolveParentConsentBaseUrl(): string {
  const configured = process.env.PARENT_CONSENT_BASE_URL?.trim();
  if (configured) {
    return configured.replace(/\/$/, '');
  }
  const projectId = admin.app().options.projectId?.trim();
  if (projectId) {
    return `https://${projectId}.web.app/consent.html`;
  }
  return '';
}

// Set APP_DEEP_LINK_SCHEME in functions/.env to match your app's deep-link scheme.
const APP_DEEP_LINK_SCHEME = process.env.APP_DEEP_LINK_SCHEME?.trim() || 'scholilink';
const LOCAL_DEMO_MODE = ['1', 'true', 'yes', 'on']
  .includes((process.env.LOCAL_DEMO_MODE ?? '').trim().toLowerCase());
const FIRESTORE_EMULATOR_HOST = (process.env.FIRESTORE_EMULATOR_HOST ?? '').trim();

if (LOCAL_DEMO_MODE && !FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    'LOCAL_DEMO_MODE is enabled but FIRESTORE_EMULATOR_HOST is not set. ' +
    'Refusing to start to prevent accidental production Firestore access.',
  );
}

function demoChatReply(prompt: string): string {
  const trimmed = prompt.trim();
  if (!trimmed) return 'Demo mode: γράψε μια ερώτηση για να ξεκινήσουμε.';
  return `Demo mode: έλαβα την ερώτησή σου "${trimmed.slice(0, 120)}". Δίνω σταθερή τοπική απάντηση χωρίς εξωτερικό AI.`;
}

function extractTextFromGenerateResult(result: GenerateContentResult): string {
  const response = result.response;
  try {
    const t = response.text();
    if (t && t.trim()) return t;
  } catch {
    // text() throws when there are no text parts (e.g. blocked / empty candidates)
  }
  const feedback = response.promptFeedback;
  if (feedback?.blockReason) {
    throw new HttpsError(
      'failed-precondition',
      `Model response blocked (${String(feedback.blockReason)}).`,
    );
  }
  const first = response.candidates?.[0];
  const finish = first?.finishReason;
  console.error('Gemini empty text; finishReason=', finish, 'candidates=', response.candidates?.length ?? 0);
  // Do not use code "internal" — callable clients often hide the message and only show "internal".
  throw new HttpsError(
    'failed-precondition',
    `No text in model response (finish: ${String(finish ?? 'none')}). Check model ${GEMINI_MODEL} and Cloud Run logs.`,
  );
}

function mimeTypeFromBase64Image(b64: string): string {
  try {
    const buf = Buffer.from(b64, 'base64');
    if (buf.length < 12) return 'image/jpeg';
    if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
    if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'image/png';
    if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return 'image/gif';
    if (buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  } catch {
    return 'image/jpeg';
  }
}

function parseJsonObject<T>(raw: string, fallback: T): T {
  try {
    return JSON.parse(raw) as T;
  } catch {
    const cleaned = raw
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim();
    try {
      return JSON.parse(cleaned) as T;
    } catch {
      return fallback;
    }
  }
}

function clampGrade(v: unknown): number | null {
  const n = typeof v === 'string' ? Number(v.replace(',', '.')) : Number(v);
  if (!Number.isFinite(n)) return null;
  if (n < 0 || n > 20) return null;
  return Math.round(n * 100) / 100;
}

function firstNonEmptyString(...vals: unknown[]): string {
  for (const v of vals) {
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

function sanitizeHomeworkOcrResult(raw: string): HomeworkOcrResult {
  const parsed = parseJsonObject<Record<string, unknown>>(raw, {});
  const nested = parsed.result && typeof parsed.result === 'object' ?
    (parsed.result as Record<string, unknown>) :
    undefined;
  const content = firstNonEmptyString(
    parsed.content,
    parsed.description,
    parsed.text,
    parsed.homeworkDescription,
    nested?.content,
    nested?.description,
    nested?.text,
  );
  const subjectRaw = typeof parsed.subject === 'string' ? parsed.subject.trim() : '';
  const typeRaw = typeof parsed.homeworkType === 'string' ? parsed.homeworkType.trim() : 'daily';
  const dueRaw = parsed.dueDateOffset;
  const dueOffset = Number.isInteger(dueRaw) ? Number(dueRaw) : null;
  const warnings = Array.isArray(parsed.warnings) ?
    parsed.warnings.filter((w): w is string => typeof w === 'string') :
    [];

  return {
    subject: subjectRaw || null,
    homeworkType: typeRaw === 'project' || typeRaw === 'other' ? typeRaw : 'daily',
    dueDateOffset: dueOffset,
    content,
    warnings,
  };
}

function foldGreek(s: string): string {
  let out = s.toLowerCase().trim();
  const reps: Record<string, string> = {
    'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ϊ': 'ι', 'ΐ': 'ι',
    'ό': 'ο', 'ύ': 'υ', 'ϋ': 'υ', 'ΰ': 'υ', 'ώ': 'ω',
  };
  for (const [k, v] of Object.entries(reps)) {
    out = out.split(k).join(v);
  }
  out = out.replace(/^[-.*•]+\s*/u, '');
  return out.replace(/[^a-z0-9α-ω\s]/gu, ' ').replace(/\s+/g, ' ').trim();
}

function matchBestSubjectTs(extracted: string, availableSubjects: string[]): string | null {
  const t = extracted.trim();
  if (!t || !availableSubjects.length) return null;
  const exact = availableSubjects.find((s) => s === t);
  if (exact) return exact;
  const target = foldGreek(t);
  let best: string | null = null;
  let bestScore = -1;
  for (const subject of availableSubjects) {
    const s = foldGreek(subject);
    let score = 0;
    if (s === target) score += 100;
    if (s.includes(target) || target.includes(s)) score += 50;
    const targetTokens = new Set(target.split(' ').filter(Boolean));
    const subjectTokens = new Set(s.split(' ').filter(Boolean));
    for (const tok of targetTokens) {
      if (subjectTokens.has(tok)) score += 10;
    }
    if (score > bestScore) {
      bestScore = score;
      best = subject;
    }
  }
  if (bestScore < 8) return null;
  return best;
}

/** Maps OCR / model term strings to the exact labels stored in Firestore. */
function canonicalTermGreek(raw: string): string | null {
  const t = raw.trim();
  if (!t) return null;
  const n = foldGreek(t);
  if (n.includes('τελικ') || t.includes('Τελικ')) {
    return 'Τελικές Εξετάσεις';
  }
  const hasTetra = n.includes('τετρα');
  if (hasTetra) {
    if (n.includes('β') && (n.startsWith('β') || t.includes('Β ') || t.includes('Β\''))) {
      return '2ο Τετράμηνο';
    }
    if (n.includes('α') && (n.startsWith('α') || t.includes('Α ') || t.includes('Α\'') || t.includes('Α '))) {
      return '1ο Τετράμηνο';
    }
    if (n.includes('1') || t.includes('1ο')) return '1ο Τετράμηνο';
    if (n.includes('2') && !n.includes('12')) return '2ο Τετράμηνο';
    return '1ο Τετράμηνο';
  }
  if (t.includes('1ο') && t.includes('Τετ')) return '1ο Τετράμηνο';
  if (t.includes('2ο') && t.includes('Τετ')) return '2ο Τετράμηνο';
  if (t === '1ο Τετράμηνο' || t === '2ο Τετράμηνο' || t === 'Τελικές Εξετάσεις') return t;
  return null;
}

function sanitizeTermGradesOcrResult(raw: string, availableSubjects: string[]): TermGradesOcrResult {
  const parsed = parseJsonObject<Record<string, unknown>>(raw, {});
  let rawItems = Array.isArray(parsed.items) ? parsed.items : [];
  if (!rawItems.length && Array.isArray(parsed.grades)) {
    rawItems = parsed.grades;
  }
  const items: TermGradeItem[] = [];
  for (const item of rawItems) {
    if (!item || typeof item !== 'object') continue;
    const i = item as Record<string, unknown>;
    const subjectRaw = typeof i.subjectName === 'string' ? i.subjectName.trim() : '';
    const termRaw = typeof i.term === 'string' ? i.term.trim() : '';
    const grade = clampGrade(i.grade);
    if (!subjectRaw || !termRaw || grade == null) continue;
    const subjectName = matchBestSubjectTs(subjectRaw, availableSubjects);
    const term = canonicalTermGreek(termRaw);
    if (!subjectName || !term) continue;
    items.push({subjectName, term, grade});
  }

  const unmatchedSubjects = Array.isArray(parsed.unmatchedSubjects) ?
    parsed.unmatchedSubjects.filter((s): s is string => typeof s === 'string') :
    [];
  const warnings = Array.isArray(parsed.warnings) ?
    parsed.warnings.filter((s): s is string => typeof s === 'string') :
    [];

  return {items, unmatchedSubjects, warnings};
}

function buildHomeworkOcrPrompt(prompt: string, availableSubjects: string[]): string {
  return [
    'You are an OCR assistant for Greek student homework.',
    'Extract visible exercise text and produce a concise homework description in Greek.',
    'The app only needs the description field to be filled reliably.',
    'Return ONLY valid JSON with this exact schema:',
    '{',
    '  "subject": null,',
    '  "homeworkType": "daily",',
    '  "dueDateOffset": null,',
    '  "content": "clean Greek homework description",',
    '  "warnings": ["optional warning strings"]',
    '}',
    'If text is partially unreadable, still return the best possible content summary.',
    'Do NOT return markdown.',
    `availableSubjects: [${availableSubjects.map((s) => `"${s}"`).join(', ')}]`,
    `userHint: ${prompt || 'Ανάλυσε την εικόνα και συμπλήρωσε περιγραφή εργασίας.'}`,
  ].join('\n');
}

function buildTermGradesOcrPrompt(prompt: string, availableSubjects: string[]): string {
  return [
    'You are an OCR assistant for Greek school report cards in tabular format.',
    'Read report image(s), identify subjects and term grades.',
    'Important table hints:',
    '- Left column usually has subject names (Μάθημα).',
    '- Grade columns can appear as "Α Τετράμηνο", "Β Τετράμηνο", and possibly other averages.',
    '- "Α Τετράμηνο" means first term; "Β Τετράμηνο" means second term.',
    '- Ignore teacher names and signature columns.',
    '- Ignore summary rows like Μ.Ο., απουσίες, δικαιολογημένες.',
    '- Prefer the student grade column over class average columns.',
    'For each item, set "term" to exactly one of: "1ο Τετράμηνο", "2ο Τετράμηνο", "Τελικές Εξετάσεις" based on which column the grade came from.',
    'For "subjectName", copy the subject text from the report as accurately as possible (the server will match it to the student profile list).',
    'Return ONLY valid JSON with this exact schema:',
    '{',
    '  "items": [',
    '    { "subjectName": "string", "term": "1ο Τετράμηνο | 2ο Τετράμηνο | Τελικές Εξετάσεις", "grade": 0-20 }',
    '  ],',
    '  "unmatchedSubjects": ["subjects found but uncertain"],',
    '  "warnings": ["optional warning strings"]',
    '}',
    'Use decimal numbers for grades (example: 14.5).',
    'If only A-term grades are visible, return items with term "1ο Τετράμηνο".',
    'Do NOT hallucinate missing grades.',
    `availableSubjects: [${availableSubjects.map((s) => `"${s}"`).join(', ')}]`,
    `userHint: ${prompt || 'Ανάλυσε τον έλεγχο προόδου και εξήγαγε βαθμούς.'}`,
  ].join('\n');
}

const PLAN_LIMITS = {
  free: 25,
  pro: 500,
};

/** Only `'pro'` activates the higher quota; any other stored value behaves as `'free'` (tamper/obfuscation tolerant). */
function normalizedSubscriptionPlan(raw: unknown): 'free' | 'pro' {
  const s = `${raw ?? ''}`.trim().toLowerCase();
  return s === 'pro' ? 'pro' : 'free';
}

const SMART_NOTES_SPARK_COST: Record<string, number> = {
  'short:basic': 1,
  'medium:standard': 2,
  'long:inDepth': 3,
};

type AiMode = 'chat' | 'smart_notes' | 'homework_ocr' | 'term_grades_ocr';

const OCR_SPARK_COST: Record<AiMode, number> = {
  chat: 1,
  smart_notes: 1,
  homework_ocr: 1,
  term_grades_ocr: 2,
};

type HomeworkOcrResult = {
  subject: string | null;
  homeworkType: 'daily' | 'project' | 'other';
  dueDateOffset: number | null;
  content: string;
  warnings: string[];
};

type TermGradeItem = {
  subjectName: string;
  term: string;
  grade: number;
};

type TermGradesOcrResult = {
  items: TermGradeItem[];
  unmatchedSubjects: string[];
  warnings: string[];
};

type GeneratedQuizQuestion = {
  questionText: string;
  type: 'multipleChoice' | 'trueFalse' | 'fillBlank' | 'development';
  options: string[];
  correctAnswer: string;
  topicTag: string;
  explanation: string;
};

function sanitizeGeneratedQuizQuestions(raw: string): GeneratedQuizQuestion[] {
  const parsed = parseJsonObject<unknown>(raw, []);
  if (!Array.isArray(parsed)) {
    throw new HttpsError('failed-precondition', 'AI did not return a valid JSON array of questions.');
  }
  const out: GeneratedQuizQuestion[] = [];
  for (const item of parsed) {
    if (!item || typeof item !== 'object') continue;
    const i = item as Record<string, unknown>;
    const questionText = firstNonEmptyString(i.questionText);
    const typeRaw = firstNonEmptyString(i.type);
    const correctAnswer = firstNonEmptyString(i.correctAnswer);
    const topicTag = firstNonEmptyString(i.topicTag);
    const explanation = firstNonEmptyString(i.explanation);
    const options = Array.isArray(i.options) ?
      i.options.filter((v): v is string => typeof v === 'string').map((v) => v.trim()).filter(Boolean) :
      [];
    const allowed = ['multipleChoice', 'trueFalse', 'fillBlank', 'development'];
    if (!questionText || !allowed.includes(typeRaw) || !correctAnswer || !topicTag) continue;
    if (typeRaw === 'multipleChoice' && options.length < 2) continue;
    out.push({
      questionText,
      type: typeRaw as GeneratedQuizQuestion['type'],
      options,
      correctAnswer,
      topicTag,
      explanation,
    });
  }
  return out;
}

function buildExamQuizPrompt(input: {
  topics: string[];
  questionType: string[];
  count: number;
  difficulty: string;
  subjectName: string;
  language: string;
  syllabusText: string;
  scannedContext: string;
  webContext: string[];
}): string {
  const lang = input.language === 'el' ? 'Greek' : 'English';
  return [
    `You are an exam quiz generator for ${input.subjectName}.`,
    `Output language must be ${lang}.`,
    'Return ONLY a strict JSON array (no markdown, no comments).',
    'Each item must follow this exact schema:',
    '{"questionText":"string","type":"multipleChoice|trueFalse|fillBlank|development","options":["string"],"correctAnswer":"string","topicTag":"string","explanation":"string"}',
    `topics: [${input.topics.map((t) => `"${t}"`).join(', ')}]`,
    `allowedTypes: [${input.questionType.map((t) => `"${t}"`).join(', ')}]`,
    `questionCount: ${input.count}`,
    `difficulty: ${input.difficulty}`,
    `userSyllabusText: ${input.syllabusText || '(none provided)'}`,
    `scannedBookContext: ${input.scannedContext || '(none scanned)'}`,
    `webAugmentationFacts: ${JSON.stringify(input.webContext)}`,
    'Generate questions strictly from userSyllabusText + scannedBookContext + webAugmentationFacts.',
    'Do not use unrelated outside knowledge.',
    'For trueFalse questions, correctAnswer must be exactly "Σωστό" or "Λάθος" when language is Greek.',
    'For fillBlank and development, options must be an empty array.',
  ].join('\n');
}

/**
 * IANA timezone for daily Spark reset (calendar day boundary). Override via `SPARK_RESET_TIMEZONE`.
 * Same for all users so device timezone cannot be used to reset early.
 */
const SPARK_RESET_TIMEZONE = process.env.SPARK_RESET_TIMEZONE?.trim() || 'Europe/Athens';

/** `YYYY-MM-DD` in [timeZone] for [d] (instant in UTC). */
function formatYmdInTimezone(d: Date, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
}

/**
 * First instant >= `now` when the calendar date in `timeZone` advances (daily quota boundary).
 */
function getNextSparkResetUtc(now: Date, timeZone: string): Date {
  const todayYmd = formatYmdInTimezone(now, timeZone);
  let lo = now.getTime();
  let hi = now.getTime() + 48 * 60 * 60 * 1000;
  let guard = 0;
  while (formatYmdInTimezone(new Date(hi), timeZone) === todayYmd && guard++ < 10) {
    hi += 24 * 60 * 60 * 1000;
  }
  if (formatYmdInTimezone(new Date(lo), timeZone) !== todayYmd) {
    return new Date(lo);
  }
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (formatYmdInTimezone(new Date(mid), timeZone) === todayYmd) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return new Date(lo);
}

function isNewSparkPeriod(
  lastRefresh: Date,
  now: Date,
  timeZone: string,
): boolean {
  return formatYmdInTimezone(lastRefresh, timeZone) !== formatYmdInTimezone(now, timeZone);
}

/**
 * Validates and refreshes user sparks if a new calendar day has started in `SPARK_RESET_TIMEZONE`.
 * Returns the latest user data.
 */
async function getOrRefreshUserSparks(uid: string, transaction: admin.firestore.Transaction) {
  const userRef = db.collection('users').doc(uid);
  const userDoc = await transaction.get(userRef);

  if (!userDoc.exists) {
    throw new HttpsError('not-found', 'User profile not found.');
  }

  const userData = userDoc.data()!;
  const subscriptionType = normalizedSubscriptionPlan(userData.subscriptionType);
  const lastRefresh = userData.lastSparksRefresh ?
    (userData.lastSparksRefresh as admin.firestore.Timestamp).toDate() :
    new Date(0);

  const now = new Date();
  const tz = SPARK_RESET_TIMEZONE;
  if (isNewSparkPeriod(lastRefresh, now, tz)) {
    const limit = PLAN_LIMITS[subscriptionType];
    transaction.update(userRef, {
      aiSparks: limit,
      lastSparksRefresh: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {...userData, aiSparks: limit};
  }

  return userData;
}

async function consumeSparksOrThrow(uid: string, sparkCost: number): Promise<{remainingSparks: number}> {
  return db.runTransaction(async (transaction) => {
    const user = await getOrRefreshUserSparks(uid, transaction);
    const currentSparks = user.aiSparks ?? 0;
    if (currentSparks < sparkCost) {
      throw new HttpsError('resource-exhausted', 'Daily spark limit reached.');
    }
    const remaining = currentSparks - sparkCost;
    transaction.update(db.collection('users').doc(uid), {
      aiSparks: remaining,
    });
    return {remainingSparks: remaining};
  });
}

type PenaltyTypeName = 'profanity' | 'cyberbullying' | 'reported';

async function applySafetyPenaltyForUid(uid: string, penaltyType: PenaltyTypeName): Promise<void> {
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(userRef);
    if (!snap.exists) return;

    const data = snap.data()!;
    let score = (data.safetyScore as number) ?? 100;
    let offenses = (data.offenseCount as number) ?? 0;
    let reports = (data.reportsCount as number) ?? 0;

    switch (penaltyType) {
      case 'profanity':
        score -= 10;
        offenses += 1;
        break;
      case 'cyberbullying':
        score -= 30;
        offenses += 1;
        break;
      case 'reported':
        reports += 1;
        if (reports % 3 === 0) {
          score -= 5;
        }
        break;
      default:
        break;
    }
    if (score < 0) score = 0;

    const updates: Record<string, unknown> = {
      safetyScore: score,
      offenseCount: offenses,
      reportsCount: reports,
    };

    if (score < 50 || offenses >= 3) {
      const banUntil = new Date(Date.now() + 24 * 60 * 60 * 1000);
      updates.isBannedUntil = admin.firestore.Timestamp.fromDate(banUntil);
    }

    transaction.update(userRef, updates);
  });
}

const CHAT_MAX_PROMPT_CHARS = 32000;
const CHAT_MAX_HISTORY_ITEMS = 40;
const CHAT_MAX_IMAGES = 4;
const CHAT_MAX_IMAGE_B64_CHARS = 6_000_000;

async function recursiveDeleteDocument(ref: admin.firestore.DocumentReference): Promise<void> {
  const cols = await ref.listCollections();
  for (const col of cols) {
    const qs = await col.get();
    for (const doc of qs.docs) {
      await recursiveDeleteDocument(doc.ref);
    }
  }
  await ref.delete();
}

async function deleteUserFirestoreRoot(uid: string): Promise<void> {
  const ref = db.collection('users').doc(uid);
  const cols = await ref.listCollections();
  for (const col of cols) {
    const qs = await col.get();
    for (const doc of qs.docs) {
      await recursiveDeleteDocument(doc.ref);
    }
  }
  await ref.delete();
  try {
    await db.collection('user_public').doc(uid).delete();
  } catch {
    // ignore
  }
}

async function assertClassroomAdmin(classroomId: string, uid: string): Promise<Record<string, unknown>> {
  const snap = await db.collection('classrooms').doc(classroomId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Classroom not found.');
  }
  const data = snap.data()!;
  const adminIds = (data.adminIds as string[]) ?? [];
  if (!adminIds.includes(uid)) {
    throw new HttpsError('permission-denied', 'Only classroom admins can perform this action.');
  }
  return data as Record<string, unknown>;
}

function computeAgeFromBirthDate(birthDate: Date): number {
  const now = new Date();
  let age = now.getFullYear() - birthDate.getFullYear();
  const m = now.getMonth() - birthDate.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

/** Blocks AI callables for under-15 users without verified parental consent. */
async function assertAiAllowed(uid: string): Promise<void> {
  const snap = await db.collection('users').doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError('failed-precondition', 'User profile not found.');
  }
  const data = snap.data()!;
  const birthTs = data.birthDate as admin.firestore.Timestamp | undefined;
  if (birthTs) {
    const age = computeAgeFromBirthDate(birthTs.toDate());
    if (age < 15 && data.hasParentalConsent !== true) {
      throw new HttpsError(
        'permission-denied',
        'Parental consent is required for AI features.',
      );
    }
    return;
  }
  if (data.hasParentalConsent === false) {
    throw new HttpsError(
      'permission-denied',
      'Parental consent is required for AI features.',
    );
  }
}

function sanitizeCurrentClass(raw: unknown): string {
  const value = typeof raw === 'string' ? raw.trim() : '';
  if (!value || value.length > 120) {
    throw new HttpsError('invalid-argument', 'Invalid currentClass.');
  }
  return value;
}

async function moderateMessageText(
  text: string,
  authorUid: string,
): Promise<{flagged: boolean; moderationConfigured: boolean; localDemoMode?: boolean}> {
  const trimmed = text.trim();
  if (!trimmed) {
    return {flagged: false, moderationConfigured: true};
  }
  if (trimmed.length > 4000) {
    return {flagged: true, moderationConfigured: true};
  }

  if (LOCAL_DEMO_MODE) {
    const lowered = trimmed.toLowerCase();
    const flagged = lowered.includes('hate') || lowered.includes('bully');
    if (flagged) {
      await applySafetyPenaltyForUid(authorUid, 'cyberbullying');
    }
    return {flagged, moderationConfigured: false, localDemoMode: true};
  }

  const apiKey = resolveGoogleAiApiKey();
  if (!apiKey) {
    logger.error('moderateMessageText: GOOGLE_AI_API_KEY missing — blocking unchecked content.');
    throw new HttpsError(
      'failed-precondition',
      'Moderation is not configured. Message cannot be delivered.',
    );
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: GEMINI_MODEL,
    generationConfig: {responseMimeType: 'application/json'},
  });

  const moderationPrompt = [
    'You are a moderation assistant for a Greek high-school student messaging app.',
    'Analyze the message for cyberbullying, extreme aggression, or hateful behavior.',
    'Return ONLY valid JSON: {"isBullying": boolean, "confidence": number, "reason": string}',
    'Only mark isBullying true if confidence > 0.8.',
    `Message: ${JSON.stringify(trimmed)}`,
  ].join('\n');

  let flagged = false;
  try {
    const result = await model.generateContent(moderationPrompt);
    const responseText = extractTextFromGenerateResult(result);
    const parsed = parseJsonObject<Record<string, unknown>>(responseText, {});
    flagged = parsed.isBullying === true && Number(parsed.confidence ?? 0) > 0.8;
  } catch (e) {
    logger.error('moderateMessageText model error', e);
    throw new HttpsError(
      'unavailable',
      'Moderation service temporarily unavailable.',
    );
  }

  if (flagged) {
    await applySafetyPenaltyForUid(authorUid, 'cyberbullying');
  }
  return {flagged, moderationConfigured: true};
}

/** Rebuild direct-chat list preview from the latest message (or clear if empty). */
async function refreshDirectChatPreview(chatId: string): Promise<void> {
  const chatRef = db.collection('direct_chats').doc(chatId);
  const latestSnap = await chatRef
    .collection('messages')
    .orderBy('timestamp', 'desc')
    .limit(1)
    .get();

  if (latestSnap.empty) {
    await chatRef.update({
      lastMessageText: '',
      lastMessageSenderId: admin.firestore.FieldValue.delete(),
      lastMessageTime: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return;
  }

  const data = latestSnap.docs[0].data();
  let lastText = String(data.text ?? '').trim();
  if (!lastText) {
    if (data.voiceUrl) {
      lastText = '🎤 Voice message';
    } else if (Array.isArray(data.imageUrls) && data.imageUrls.length > 0) {
      lastText = '📷 Photo';
    }
  }

  await chatRef.update({
    lastMessageText: lastText,
    lastMessageSenderId: String(data.senderId ?? ''),
    lastMessageTime: data.timestamp ?? admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Ensures `user_public/{uid}` exists from the private `users/{uid}` profile. */
async function syncUserPublicFromPrivate(uid: string): Promise<void> {
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) return;
  const d = userSnap.data() ?? {};
  await db.collection('user_public').doc(uid).set({
    uid,
    fullName: (d.fullName as string) ?? '',
    currentClass: (d.currentClass as string) ?? 'A-Lykeio-General',
    profilePictureUrl: d.profilePictureUrl ?? null,
    bio: (d.bio as string) ?? '',
    achievements: (d.achievements as string[]) ?? [],
    showBio: d.showBio !== false,
    showAchievements: d.showAchievements !== false,
    shareGrades: !!d.shareGrades,
    preferredLanguage: (d.preferredLanguage as string) ?? 'el',
    schoolRole: (d.schoolRole as string) ?? 'student',
    isProfileComplete: !!d.isProfileComplete,
  }, {merge: true});
}

async function deleteUserStorageFiles(uid: string): Promise<void> {
  const bucket = admin.storage().bucket();
  const prefixes = [
    `profile_pictures/${uid}/`,
    `homework_images/${uid}/`,
    `homework_voice/${uid}/`,
    `ai_uploads/${uid}/`,
    `chat_images/${uid}/`,
    `chat_voice/${uid}/`,
    `direct_chat_images/${uid}/`,
    `direct_chat_voice/${uid}/`,
    `classroom_images/${uid}/`,
  ];
  for (const prefix of prefixes) {
    try {
      await bucket.deleteFiles({prefix});
    } catch (e) {
      logger.warn('deleteUserStorageFiles prefix failed', {prefix, uid, e});
    }
  }
}

async function deleteUserDataCompletely(uid: string): Promise<void> {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() ?? {};

  const classroomIds = Array.isArray(userData.classroomIds) ?
    userData.classroomIds.filter((v): v is string => typeof v === 'string') :
    [];
  for (const classroomId of classroomIds) {
    try {
      await db.collection('classrooms').doc(classroomId).update({
        members: admin.firestore.FieldValue.arrayRemove(uid),
        adminIds: admin.firestore.FieldValue.arrayRemove(uid),
      });
    } catch {
      // ignore missing classrooms
    }
  }

  const peerUids = new Set<string>();
  for (const friendUid of (userData.friends as string[] | undefined) ?? []) {
    peerUids.add(friendUid);
  }
  for (const sentUid of (userData.friendRequestsSent as string[] | undefined) ?? []) {
    peerUids.add(sentUid);
  }
  for (const recvUid of (userData.friendRequestsReceived as string[] | undefined) ?? []) {
    peerUids.add(recvUid);
  }
  for (const peerUid of peerUids) {
    try {
      await db.collection('users').doc(peerUid).update({
        friends: admin.firestore.FieldValue.arrayRemove(uid),
        friendRequestsSent: admin.firestore.FieldValue.arrayRemove(uid),
        friendRequestsReceived: admin.firestore.FieldValue.arrayRemove(uid),
      });
    } catch {
      // ignore
    }
  }

  const chatsSnap = await db.collection('direct_chats')
    .where('participants', 'array-contains', uid)
    .get();
  for (const chatDoc of chatsSnap.docs) {
    const msgsSnap = await chatDoc.ref.collection('messages')
      .where('senderId', '==', uid)
      .get();
    for (const msgDoc of msgsSnap.docs) {
      await msgDoc.ref.delete();
    }
  }

  await deleteUserStorageFiles(uid);
  await deleteUserFirestoreRoot(uid);

  // Delete server-only data not covered by deleteUserFirestoreRoot.
  try {
    await db.collection('user_private').doc(uid).delete();
  } catch { /* ignore */ }

  // Delete ExamIQ attempts and readiness scores in batches.
  for (const collectionName of ['quiz_attempts', 'readiness_scores'] as const) {
    try {
      const snap = await db.collection(collectionName).where('userId', '==', uid).get();
      if (!snap.empty) {
        const batch = db.batch();
        for (const doc of snap.docs) {
          batch.delete(doc.ref);
        }
        await batch.commit();
      }
    } catch (e) {
      logger.warn(`deleteUserDataCompletely: failed to delete ${collectionName}`, {uid, e});
    }
  }

  // Delete reports filed by this user.
  try {
    const reportsSnap = await db.collection('reports').where('reporterId', '==', uid).get();
    if (!reportsSnap.empty) {
      const batch = db.batch();
      for (const doc of reportsSnap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }
  } catch (e) {
    logger.warn('deleteUserDataCompletely: failed to delete reports', {uid, e});
  }
}

/**
 * Primary Secure AI Chat Function
 * Handles usage limits, automated daily refreshes, and model interaction.
 */
export const chatWithAi = onCall(async (request) => {
  // One outer try/catch so nothing (e.g. TypeError from bad request.data) becomes an uncaught 500/"internal".
  try {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in.');
    }

    if (!LOCAL_DEMO_MODE) {
      await assertAiAllowed(request.auth.uid);
    }

    // Never destructure `undefined` — that throws TypeError *outside* any inner try and surfaces as internal.
    const data = (request.data ?? {}) as {
      prompt?: string;
      history?: unknown;
      isJson?: boolean;
      mode?: string;
      length?: string;
      depth?: string;
      images?: unknown;
      availableSubjects?: unknown;
    };
    const prompt = data.prompt;
    const history = data.history;
    let isJson = !!data.isJson;
    let mode: AiMode = 'chat';
    if (data.mode === 'smart_notes') mode = 'smart_notes';
    if (data.mode === 'homework_ocr') mode = 'homework_ocr';
    if (data.mode === 'term_grades_ocr') mode = 'term_grades_ocr';
    const length = data.length ?? 'short';
    const depth = data.depth ?? 'basic';
    const userApiKey = sanitizeUserApiKey((data as Record<string, unknown>).userApiKey);
    let imageBase64 = Array.isArray(data.images) ?
      data.images.filter((v): v is string => typeof v === 'string') :
      [];
    if (imageBase64.length > CHAT_MAX_IMAGES) {
      imageBase64 = imageBase64.slice(0, CHAT_MAX_IMAGES);
    }
    imageBase64 = imageBase64
      .map((b) => (b.length > CHAT_MAX_IMAGE_B64_CHARS ? b.slice(0, CHAT_MAX_IMAGE_B64_CHARS) : b));
    const availableSubjects = Array.isArray(data.availableSubjects) ?
      data.availableSubjects.filter((v): v is string => typeof v === 'string').map((v) => v.trim()).filter(Boolean) :
      [];
    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Prompt is required.');
    }
    const promptTrimmed =
      prompt.length > CHAT_MAX_PROMPT_CHARS ? prompt.slice(0, CHAT_MAX_PROMPT_CHARS) : prompt;
    if ((mode === 'homework_ocr' || mode === 'term_grades_ocr') && imageBase64.length === 0) {
      throw new HttpsError('invalid-argument', 'At least one image is required for OCR mode.');
    }
    if (mode === 'homework_ocr' || mode === 'term_grades_ocr') {
      isJson = true;
    }

    if (LOCAL_DEMO_MODE) {
      if (mode === 'homework_ocr') {
        return {
          data: {
            subject: availableSubjects[0] ?? null,
            homeworkType: 'daily',
            dueDateOffset: 1,
            content: 'Δείγμα εργασίας από local demo mode.',
            warnings: ['LOCAL_DEMO_MODE: mock OCR response'],
          },
          remainingSparks: 999,
          sparkCost: 0,
          nextRefreshAt: getNextSparkResetUtc(new Date(), SPARK_RESET_TIMEZONE).toISOString(),
          sparkTimezone: SPARK_RESET_TIMEZONE,
        };
      }
      if (mode === 'term_grades_ocr') {
        const subject = availableSubjects.length > 0 ? availableSubjects[0] : 'Μαθηματικά';
        return {
          data: {
            items: [{subjectName: subject, term: '1ο Τετράμηνο', grade: 16}],
            unmatchedSubjects: [],
            warnings: ['LOCAL_DEMO_MODE: mock OCR response'],
          },
          remainingSparks: 999,
          sparkCost: 0,
          nextRefreshAt: getNextSparkResetUtc(new Date(), SPARK_RESET_TIMEZONE).toISOString(),
          sparkTimezone: SPARK_RESET_TIMEZONE,
        };
      }
      return {
        text: demoChatReply(promptTrimmed),
        remainingSparks: 999,
        sparkCost: 0,
        nextRefreshAt: getNextSparkResetUtc(new Date(), SPARK_RESET_TIMEZONE).toISOString(),
        sparkTimezone: SPARK_RESET_TIMEZONE,
      };
    }

    const uid = request.auth.uid;
    const tz = SPARK_RESET_TIMEZONE;
    const nextResetIso = getNextSparkResetUtc(new Date(), tz).toISOString();

    // 1. Validate / Refresh Sparks in a transaction
    const sparkCost = mode === 'smart_notes' ?
      (SMART_NOTES_SPARK_COST[`${length}:${depth}`] ?? 1) :
      (OCR_SPARK_COST[mode] ?? 1);
    const sparkTx = userApiKey ?
      {remainingSparks: 9999, sparkCost: 0} :
      await db.runTransaction(async (transaction) => {
        const user = await getOrRefreshUserSparks(uid, transaction);
        const currentSparks = user.aiSparks ?? 0;

        if (currentSparks < sparkCost) {
          throw new HttpsError('resource-exhausted', 'Daily spark limit reached.', {
            nextRefreshAt: nextResetIso,
            sparkTimezone: tz,
          });
        }

        const newBalance = currentSparks - sparkCost;
        transaction.update(db.collection('users').doc(uid), {
          aiSparks: newBalance,
        });
        return {remainingSparks: newBalance, sparkCost};
      });

    // 2. Call Gemini
    const apiKey = userApiKey || resolveGoogleAiApiKey();
    if (!apiKey) {
      console.error('chatWithAi: missing GOOGLE_AI_API_KEY (env) or google.ai_api_key (functions config)');
      throw new HttpsError(
        'failed-precondition',
        'AI service is not configured (server API key).',
      );
    }
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: GEMINI_MODEL,
      generationConfig: isJson ? {responseMimeType: 'application/json'} : undefined,
    });

    const historyArr = Array.isArray(history) ? (history as Array<Record<string, unknown>>).slice(-CHAT_MAX_HISTORY_ITEMS) : [];

    const effectivePrompt = mode === 'homework_ocr' ?
      buildHomeworkOcrPrompt(promptTrimmed, availableSubjects) :
      mode === 'term_grades_ocr' ?
        buildTermGradesOcrPrompt(promptTrimmed, availableSubjects) :
        promptTrimmed;
    const userParts: Array<Record<string, unknown>> = [{text: effectivePrompt}];
    for (const b64 of imageBase64) {
      userParts.push({
        inlineData: {
          mimeType: mimeTypeFromBase64Image(b64),
          data: b64,
        },
      });
    }
    const contents = [
      ...historyArr,
      {role: 'user', parts: userParts},
    ];
    const result = await model.generateContent({contents: contents as never});
    const responseText = extractTextFromGenerateResult(result);

    if (mode === 'homework_ocr') {
      const parsed = sanitizeHomeworkOcrResult(responseText);
      if (!parsed.content) {
        throw new HttpsError('failed-precondition', 'Could not extract homework description from image.');
      }
      return {
        data: parsed,
        remainingSparks: sparkTx.remainingSparks,
        sparkCost: sparkTx.sparkCost,
        nextRefreshAt: getNextSparkResetUtc(new Date(), tz).toISOString(),
        sparkTimezone: tz,
      };
    }

    if (mode === 'term_grades_ocr') {
      const parsed = sanitizeTermGradesOcrResult(responseText, availableSubjects);
      return {
        data: parsed,
        remainingSparks: sparkTx.remainingSparks,
        sparkCost: sparkTx.sparkCost,
        nextRefreshAt: getNextSparkResetUtc(new Date(), tz).toISOString(),
        sparkTimezone: tz,
      };
    }

    return {
      text: responseText,
      remainingSparks: sparkTx.remainingSparks,
      sparkCost: sparkTx.sparkCost,
      nextRefreshAt: getNextSparkResetUtc(new Date(), tz).toISOString(),
      sparkTimezone: tz,
    };
  } catch (error: unknown) {
    console.error('AI Function Error:', error);
    if (error instanceof HttpsError) {
      // Callable clients often drop the real message when code is "internal".
      if (error.code === 'internal') {
        const m =
          error.message?.trim() && error.message !== 'internal' ?
            error.message :
            'Unspecified error; check Cloud Run logs for chatWithAi.';
        throw new HttpsError('failed-precondition', `AI: ${m}`);
      }
      throw error;
    }
    const message = error instanceof Error ? error.message : 'AI interaction failed.';
    if (message.includes('API key') || message.includes('API_KEY')) {
      throw new HttpsError('failed-precondition', 'Invalid or rejected AI API key (check GOOGLE_AI_API_KEY).');
    }
    if (message.includes('404') || message.toLowerCase().includes('not found')) {
      throw new HttpsError(
        'failed-precondition',
        `Model not available (${GEMINI_MODEL}). Set env GEMINI_MODEL to a valid id or enable the model for this key.`,
      );
    }
    throwVisibleAiFailure('AI error', error);
  }
});

export const generateExamQuiz = onCall(
  async (request) => {
    const payloadPreview = (() => {
      const d = (request.data ?? {}) as Record<string, unknown>;
      const imgs = Array.isArray(d.base64Images) ? d.base64Images.length : 0;
      return {
        ...d,
        base64Images: `[${imgs} images omitted]`,
      };
    })();
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be signed in.');
      }
      const uid = request.auth.uid;
      if (!LOCAL_DEMO_MODE) {
        await assertAiAllowed(uid);
      }
      const data = (request.data ?? {}) as {
        topics?: unknown;
        questionType?: unknown;
        count?: unknown;
        difficulty?: unknown;
        subjectName?: unknown;
        language?: unknown;
        syllabusText?: unknown;
        base64Images?: unknown;
        userApiKey?: unknown;
      };
      const userApiKey = sanitizeUserApiKey(data.userApiKey);
      const topics = Array.isArray(data.topics) ?
        data.topics.filter((v): v is string => typeof v === 'string' && v.trim().length > 0) :
        [];
      const questionType = Array.isArray(data.questionType) ?
        data.questionType.filter((v): v is string => typeof v === 'string' && v.trim().length > 0) :
        [];
      const count = Number(data.count ?? 10);
      const difficulty = firstNonEmptyString(data.difficulty) || 'μεσαίο';
      const subjectName = firstNonEmptyString(data.subjectName);
      const language = firstNonEmptyString(data.language) || 'el';
      const syllabusText = firstNonEmptyString(data.syllabusText);
      const base64Images = Array.isArray(data.base64Images) ?
        data.base64Images
          .filter((v): v is string => typeof v === 'string' && v.trim().length > 0)
          .slice(0, 6)
          .map((v) => (v.length > CHAT_MAX_IMAGE_B64_CHARS ? v.slice(0, CHAT_MAX_IMAGE_B64_CHARS) : v)) :
        [];
      if (!subjectName || questionType.length === 0) {
        throw new HttpsError('invalid-argument', 'subjectName and questionType are required.');
      }
      if (topics.length === 0 && !syllabusText && base64Images.length === 0) {
        throw new HttpsError('invalid-argument', 'Provide at least topics, syllabusText, or scanned images.');
      }
      if (!Number.isFinite(count) || count < 1 || count > 30) {
        throw new HttpsError('invalid-argument', 'count must be between 1 and 30.');
      }

      if (LOCAL_DEMO_MODE) {
        const questions: GeneratedQuizQuestion[] = Array.from({length: count}).map((_, idx) => ({
          questionText: `Demo ερώτηση ${idx + 1} για ${subjectName}`,
          type: questionType.includes('multipleChoice') ? 'multipleChoice' : 'development',
          options: questionType.includes('multipleChoice') ? ['A', 'B', 'C', 'D'] : [],
          correctAnswer: questionType.includes('multipleChoice') ? 'A' : 'Ενδεικτική απάντηση',
          topicTag: topics[idx % topics.length] ?? subjectName,
          explanation: 'LOCAL_DEMO_MODE deterministic quiz item',
        }));
        const docRef = db.collection('exam_quizzes').doc();
        await docRef.set({
          quizId: docRef.id,
          examReference: subjectName.toLowerCase().replace(/\s+/g, '_'),
          topics,
          questionType: questionType[0],
          questionTypes: questionType,
          difficulty,
          generatedQuestions: questions,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: uid,
          subjectName,
          language,
          syllabusText,
          scannedContext: 'LOCAL_DEMO_MODE',
          webContext: [],
        });
        const snap = await docRef.get();
        return {quizId: docRef.id, quiz: snap.data()};
      }

      if (!userApiKey) {
        await consumeSparksOrThrow(uid, 2);
      }

      const apiKey = userApiKey || resolveGoogleAiApiKey();
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'AI service is not configured (GOOGLE_AI_API_KEY).');
      }
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: GEMINI_MODEL,
        generationConfig: {responseMimeType: 'application/json'},
      });
      const tavilyApiKey = resolveTavilyApiKey();
      const contextPromptParts: Array<Record<string, unknown>> = [
        {
          text: [
            `Μάθημα: ${subjectName}`,
            `Θέματα: ${topics.join(', ') || '(κανένα)'}`,
            `Ύλη που έδωσε ο μαθητής: ${syllabusText || '(δεν δόθηκε)'}`,
            'Ανάγνωσε τις εικόνες βιβλίου/σημειώσεων και εξήγαγε κρίσιμο context για εξεταστικό τεστ.',
            'Επέστρεψε συνοπτικό plain text context στα ελληνικά.',
          ].join('\n'),
        },
      ];
      for (const b64 of base64Images) {
        contextPromptParts.push({
          inlineData: {
            mimeType: mimeTypeFromBase64Image(b64),
            data: b64,
          },
        });
      }
      const contextResult = await model.generateContent({
        contents: [{role: 'user', parts: contextPromptParts}] as never,
      });
      const scannedContext = extractTextFromGenerateResult(contextResult);

      const webQuery = [subjectName, ...topics, syllabusText, scannedContext]
        .join(' ')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 500);
      const webContext = await runWebContextSearch(webQuery, tavilyApiKey);

      const quizPrompt = buildExamQuizPrompt({
        topics,
        questionType,
        count,
        difficulty,
        subjectName,
        language,
        syllabusText,
        scannedContext,
        webContext,
      });
      const quizResult = await model.generateContent(quizPrompt);
      const text = extractTextFromGenerateResult(quizResult);
      const questions = sanitizeGeneratedQuizQuestions(text).slice(0, count);
      if (questions.length === 0) {
        throw new HttpsError('failed-precondition', 'AI returned no valid questions.');
      }
      const docRef = db.collection('exam_quizzes').doc();
      await docRef.set({
        quizId: docRef.id,
        examReference: subjectName.toLowerCase().replace(/\s+/g, '_'),
        topics,
        questionType: questionType[0],
        questionTypes: questionType,
        difficulty,
        generatedQuestions: questions,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: uid,
        subjectName,
        language,
        syllabusText,
        scannedContext,
        webContext,
      });
      const snap = await docRef.get();
      return {
        quizId: docRef.id,
        quiz: snap.data(),
      };
    } catch (error: unknown) {
      logger.error('generateExamQuiz failed', {
        payload: payloadPreview,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : '',
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        'failed-precondition',
        `generateExamQuiz failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

export const scoreOpenQuizAttempt = onCall(
  async (request) => {
    const payloadPreview = (() => {
      const d = (request.data ?? {}) as Record<string, unknown>;
      return {...d, answers: '[answers omitted for logs]'};
    })();
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'User must be signed in.');
      }
      const uid = request.auth.uid;
      if (!LOCAL_DEMO_MODE) {
        await assertAiAllowed(uid);
      }
      const data = (request.data ?? {}) as {
        quizId?: unknown;
        openQuestions?: unknown;
        answers?: unknown;
        language?: unknown;
        attemptId?: unknown;
        userApiKey?: unknown;
      };
      const userApiKey = sanitizeUserApiKey(data.userApiKey);
      const quizId = firstNonEmptyString(data.quizId);
      const attemptId = firstNonEmptyString(data.attemptId);
      const openQuestions = Array.isArray(data.openQuestions) ?
        data.openQuestions.filter((q): q is Record<string, unknown> => !!q && typeof q === 'object') :
        [];
      const answers = data.answers && typeof data.answers === 'object' ?
        (data.answers as Record<string, unknown>) :
        {};
      const language = firstNonEmptyString(data.language) || 'el';
      if (!quizId || openQuestions.length === 0) {
        throw new HttpsError('invalid-argument', 'quizId and openQuestions are required.');
      }

      if (LOCAL_DEMO_MODE) {
        const questionScores = openQuestions.map((_, index) => ({
          index,
          score: 0.75,
          explanation: 'LOCAL_DEMO_MODE deterministic grading',
        }));
        const sourceContext = {
          subjectName: 'LOCAL_DEMO_MODE',
          topics: [],
          syllabusText: '',
          scannedContext: '',
          webContext: [],
        };
        await db.collection('quiz_open_attempt_scores').add({
          quizId,
          attemptId: attemptId || null,
          userId: uid,
          sourceContext,
          questionScores,
          scoredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (attemptId) {
          const attemptSnap = await db.collection('quiz_attempts').doc(attemptId).get();
          if (!attemptSnap.exists || attemptSnap.data()?.userId !== uid) {
            throw new HttpsError('permission-denied', 'Quiz attempt not found or access denied.');
          }
          await db.collection('quiz_attempts').doc(attemptId).set({
            openEvaluation: {
              questionScores,
              sourceContext,
              scoredAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          }, {merge: true});
        }
        return {quizId, questionScores, sourceContext};
      }

      if (!userApiKey) {
        await consumeSparksOrThrow(uid, 1);
      }

      const quizSnap = await db.collection('exam_quizzes').doc(quizId).get();
      const quizData = quizSnap.data() ?? {};
      const sourceContext = {
        subjectName: firstNonEmptyString(quizData.subjectName),
        topics: Array.isArray(quizData.topics) ? quizData.topics : [],
        syllabusText: firstNonEmptyString(quizData.syllabusText),
        scannedContext: firstNonEmptyString(quizData.scannedContext),
        webContext: Array.isArray(quizData.webContext) ? quizData.webContext : [],
      };

      const apiKey = userApiKey || resolveGoogleAiApiKey();
      if (!apiKey) {
        throw new HttpsError('failed-precondition', 'AI service is not configured (GOOGLE_AI_API_KEY).');
      }
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: GEMINI_MODEL,
        generationConfig: {responseMimeType: 'application/json'},
      });
      const prompt = [
        'Evaluate each open answer against the exact study material context.',
        `Language: ${language === 'el' ? 'Greek' : 'English'}.`,
        'Return ONLY valid JSON in this exact schema:',
        '{"questionScores":[{"index":0,"score":0.0,"explanation":"string"}]}',
        `studyContext: ${JSON.stringify(sourceContext)}`,
        `questions: ${JSON.stringify(openQuestions)}`,
        `answersByIndex: ${JSON.stringify(answers)}`,
      ].join('\n');
      const scoreResult = await model.generateContent(prompt);
      const text = extractTextFromGenerateResult(scoreResult);
      const parsed = parseJsonObject<Record<string, unknown>>(text, {});
      const rowsRaw = Array.isArray(parsed.questionScores) ? parsed.questionScores : [];
      const questionScores = rowsRaw
        .filter((row): row is Record<string, unknown> => !!row && typeof row === 'object')
        .map((row) => ({
          index: Number(row.index ?? -1),
          score: Math.max(0, Math.min(1, Number(row.score ?? 0))),
          explanation: firstNonEmptyString(row.explanation),
        }))
        .filter((row) => Number.isInteger(row.index));

      const evalDoc = {
        quizId,
        attemptId: attemptId || null,
        userId: uid,
        sourceContext,
        questionScores,
        scoredAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await db.collection('quiz_open_attempt_scores').add(evalDoc);
      if (attemptId) {
        const attemptSnap = await db.collection('quiz_attempts').doc(attemptId).get();
        if (!attemptSnap.exists || attemptSnap.data()?.userId !== uid) {
          throw new HttpsError('permission-denied', 'Quiz attempt not found or access denied.');
        }
        await db.collection('quiz_attempts').doc(attemptId).set({
          openEvaluation: {
            questionScores,
            sourceContext,
            scoredAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        }, {merge: true});
      }
      return {quizId, questionScores, sourceContext};
    } catch (error: unknown) {
      logger.error('scoreOpenQuizAttempt failed', {
        payload: payloadPreview,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : '',
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError(
        'failed-precondition',
        `scoreOpenQuizAttempt failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  },
);

/**
 * Applies safety moderation fields on the user document (server-side only).
 * Clients cannot write safetyScore / bans directly (see Firestore rules).
 *
 * ARCHITECTURE NOTE (portfolio context):
 * This callable applies the penalty to request.auth.uid — the *calling* user.
 * The intended flow is: client calls moderateStudentMessage → server detects a
 * violation → client calls applySafetyPenalty to record it server-side.
 *
 * Limitation: a client can skip calling this function after sending a bad message,
 * bypassing moderation recording. A production-grade system would move the penalty
 * application *inside* moderateStudentMessage (or a Firestore onCreate trigger),
 * removing the client's choice entirely. This design is intentional here to
 * demonstrate the server-authoritative pattern while keeping the client API simple
 * for a portfolio/showcase context.
 */
export const applySafetyPenalty = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const {penaltyType} = request.data as {penaltyType?: string};
  if (!penaltyType || !['profanity', 'cyberbullying', 'reported'].includes(penaltyType)) {
    throw new HttpsError('invalid-argument', 'Invalid penaltyType.');
  }
  await applySafetyPenaltyForUid(uid, penaltyType as PenaltyTypeName);
});

/**
 * Server-side moderation for chat/DM text (replaces client-side Vertex calls).
 */
export const moderateStudentMessage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const textRaw = (request.data as {text?: unknown})?.text;
  const text = typeof textRaw === 'string' ? textRaw.trim() : '';
  if (!text) {
    return {flagged: false};
  }
  if (text.length > 4000) {
    throw new HttpsError('invalid-argument', 'Message too long for moderation.');
  }

  const result = await moderateMessageText(text, request.auth.uid);
  return result;
});

/** Deletes the caller's Firestore user subtree + public profile (before Auth account delete). */
export const deleteOwnUserFirestoreData = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  await deleteUserDataCompletely(request.auth.uid);
  return {ok: true};
});

/** Stable doc id for a two-user chat (matches client [DirectMessageService.directChatDocId]). */
function directChatDocId(user1Id: string, user2Id: string): string {
  const sorted = [user1Id, user2Id].sort();
  return `${sorted[0]}__${sorted[1]}`;
}

function directChatActivityRank(data: Record<string, unknown>): number {
  const lastMessage = data.lastMessageTime as admin.firestore.Timestamp | undefined;
  if (lastMessage) return lastMessage.toMillis();
  const updated = data.updatedAt as admin.firestore.Timestamp | undefined;
  if (updated) return updated.toMillis();
  const created = data.createdAt as admin.firestore.Timestamp | undefined;
  return created?.toMillis() ?? 0;
}

async function assertCallerFriendsWith(otherUid: string, callerUid: string): Promise<void> {
  const meSnap = await db.collection('users').doc(callerUid).get();
  if (!meSnap.exists) {
    throw new HttpsError('not-found', 'User profile not found.');
  }
  const friends = (meSnap.data()?.friends as string[] | undefined) ?? [];
  if (!friends.includes(otherUid)) {
    throw new HttpsError('permission-denied', 'You are not friends with this user.');
  }
}

/** Cross-user friend request (Firestore rules no longer allow client writes to other users). */
export const friendSendRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const fromUid = request.auth.uid;
  const toUid = typeof (request.data as {toUid?: unknown})?.toUid === 'string' ?
    String((request.data as {toUid: string}).toUid).trim() :
    '';
  if (!toUid || toUid === fromUid) {
    throw new HttpsError('invalid-argument', 'Invalid toUid.');
  }
  const [fromSnap, toSnap] = await Promise.all([
    db.collection('users').doc(fromUid).get(),
    db.collection('users').doc(toUid).get(),
  ]);
  if (!fromSnap.exists || !toSnap.exists) {
    throw new HttpsError('not-found', 'User not found.');
  }
  const fromData = fromSnap.data() ?? {};
  const friends = (fromData.friends as string[] | undefined) ?? [];
  const sent = (fromData.friendRequestsSent as string[] | undefined) ?? [];
  const received = (fromData.friendRequestsReceived as string[] | undefined) ?? [];
  if (friends.includes(toUid)) {
    throw new HttpsError('already-exists', 'Already friends.');
  }
  if (sent.includes(toUid)) {
    throw new HttpsError('already-exists', 'Request already sent.');
  }
  if (received.includes(toUid)) {
    throw new HttpsError(
      'failed-precondition',
      'This user already sent you a request. Accept or decline it first.',
    );
  }
  const fromBlocked = (fromData.blockedUsers as string[] | undefined) ?? [];
  const toBlocked = (toSnap.data()?.blockedUsers as string[] | undefined) ?? [];
  if (fromBlocked.includes(toUid) || toBlocked.includes(fromUid)) {
    throw new HttpsError('permission-denied', 'Cannot send friend request to this user.');
  }
  await db.runTransaction(async (tx) => {
    tx.update(db.collection('users').doc(fromUid), {
      friendRequestsSent: admin.firestore.FieldValue.arrayUnion(toUid),
    });
    tx.update(db.collection('users').doc(toUid), {
      friendRequestsReceived: admin.firestore.FieldValue.arrayUnion(fromUid),
    });
  });

  const toData = toSnap.data() ?? {};
  const toLang = userLang(toData);
  const senderName = firstName(String(fromData.fullName ?? ''), toLang);
  await sendPushToUser({
    uid: toUid,
    title: toLang === 'el' ? 'Νέο αίτημα φιλίας' : 'New friend request',
    body: toLang === 'el' ?
      `${senderName} σου έστειλε αίτημα φιλίας.` :
      `${senderName} sent you a friend request.`,
    data: {
      type: 'friend_request',
      senderId: fromUid,
    },
  });

  return {ok: true};
});

export const friendAcceptRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const currentUid = request.auth.uid;
  const fromUid = typeof (request.data as {fromUid?: unknown})?.fromUid === 'string' ?
    String((request.data as {fromUid: string}).fromUid).trim() :
    '';
  if (!fromUid || fromUid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid fromUid.');
  }
  await db.runTransaction(async (tx) => {
    const meDoc = await tx.get(db.collection('users').doc(currentUid));
    const received = (meDoc.data()?.friendRequestsReceived as string[] | undefined) ?? [];
    if (!received.includes(fromUid)) {
      throw new HttpsError('failed-precondition', 'No pending request from this user.');
    }
    tx.update(db.collection('users').doc(currentUid), {
      friends: admin.firestore.FieldValue.arrayUnion(fromUid),
      friendRequestsReceived: admin.firestore.FieldValue.arrayRemove(fromUid),
    });
    tx.update(db.collection('users').doc(fromUid), {
      friends: admin.firestore.FieldValue.arrayUnion(currentUid),
      friendRequestsSent: admin.firestore.FieldValue.arrayRemove(currentUid),
    });
  });
  await syncUserPublicFromPrivate(currentUid);
  await syncUserPublicFromPrivate(fromUid);
  return {ok: true};
});

export const friendDeclineRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const currentUid = request.auth.uid;
  const fromUid = typeof (request.data as {fromUid?: unknown})?.fromUid === 'string' ?
    String((request.data as {fromUid: string}).fromUid).trim() :
    '';
  if (!fromUid || fromUid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid fromUid.');
  }
  const meSnap = await db.collection('users').doc(currentUid).get();
  const received = (meSnap.data()?.friendRequestsReceived as string[] | undefined) ?? [];
  if (!received.includes(fromUid)) {
    throw new HttpsError('failed-precondition', 'No pending request from this user.');
  }
  await db.runTransaction(async (tx) => {
    tx.update(db.collection('users').doc(currentUid), {
      friendRequestsReceived: admin.firestore.FieldValue.arrayRemove(fromUid),
    });
    tx.update(db.collection('users').doc(fromUid), {
      friendRequestsSent: admin.firestore.FieldValue.arrayRemove(currentUid),
    });
  });
  return {ok: true};
});

/** Sender withdraws a pending friend request they previously sent. */
export const friendCancelRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const currentUid = request.auth.uid;
  const toUid = typeof (request.data as {toUid?: unknown})?.toUid === 'string' ?
    String((request.data as {toUid: string}).toUid).trim() :
    '';
  if (!toUid || toUid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid toUid.');
  }
  const meSnap = await db.collection('users').doc(currentUid).get();
  const sent = (meSnap.data()?.friendRequestsSent as string[] | undefined) ?? [];
  if (!sent.includes(toUid)) {
    throw new HttpsError('failed-precondition', 'No pending request to cancel.');
  }
  await db.runTransaction(async (tx) => {
    tx.update(db.collection('users').doc(currentUid), {
      friendRequestsSent: admin.firestore.FieldValue.arrayRemove(toUid),
    });
    tx.update(db.collection('users').doc(toUid), {
      friendRequestsReceived: admin.firestore.FieldValue.arrayRemove(currentUid),
    });
  });
  return {ok: true};
});

/**
 * Returns an existing direct-chat id or creates one (Admin SDK).
 * Repairs orphan deterministic docs the client cannot read under security rules.
 */
export const directChatGetOrCreate = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const currentUid = request.auth.uid;
  const otherUid = typeof (request.data as {otherUid?: unknown})?.otherUid === 'string' ?
    String((request.data as {otherUid: string}).otherUid).trim() :
    '';
  if (!otherUid || otherUid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid otherUid.');
  }
  await assertCallerFriendsWith(otherUid, currentUid);

  const existingChats = await db.collection('direct_chats')
    .where('participants', 'array-contains', currentUid)
    .get();

  let bestId: string | null = null;
  let bestRank = -1;
  for (const doc of existingChats.docs) {
    const data = doc.data();
    const participants = (data.participants as string[] | undefined) ?? [];
    if (!participants.includes(otherUid) || participants.length !== 2) continue;
    const rank = directChatActivityRank(data);
    if (rank > bestRank) {
      bestRank = rank;
      bestId = doc.id;
    }
  }
  if (bestId) {
    return {chatId: bestId};
  }

  const chatId = directChatDocId(currentUid, otherUid);
  const chatRef = db.collection('direct_chats').doc(chatId);
  const participants = [currentUid, otherUid];

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(chatRef);
    const now = admin.firestore.FieldValue.serverTimestamp();
    if (snap.exists) {
      const data = snap.data() ?? {};
      const existing = (data.participants as string[] | undefined) ?? [];
      const valid =
        existing.length === 2 &&
        existing.includes(currentUid) &&
        existing.includes(otherUid);
      if (!valid) {
        tx.set(chatRef, {
          participants,
          updatedAt: now,
          ...(!('createdAt' in data) ? {createdAt: now} : {}),
        }, {merge: true});
      }
      return;
    }
    tx.set(chatRef, {
      participants,
      createdAt: now,
      updatedAt: now,
      lastMessageText: '',
      lastMessageSenderId: '',
      unreadCounts: {},
    });
  });

  return {chatId};
});

/** Backfills missing `user_public` docs for friend list display (server reads private profiles). */
export const resolveFriendProfiles = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const raw = (request.data as {friendUids?: unknown})?.friendUids;
  const friendUids = Array.isArray(raw) ?
    raw.filter((id): id is string => typeof id === 'string' && id.trim().length > 0).slice(0, 30) :
    [];
  if (friendUids.length === 0) {
    return {profiles: []};
  }

  const me = request.auth.uid;
  const mySnap = await db.collection('users').doc(me).get();
  const myFriends = (mySnap.data()?.friends as string[] | undefined) ?? [];
  const allowed = new Set(myFriends);

  const profiles: Record<string, unknown>[] = [];
  for (const uid of friendUids) {
    if (!allowed.has(uid)) continue;
    await syncUserPublicFromPrivate(uid);
    const pub = await db.collection('user_public').doc(uid).get();
    if (pub.exists) {
      profiles.push({uid, ...pub.data()});
    }
  }
  return {profiles};
});

export const friendRemove = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const currentUid = request.auth.uid;
  const friendUid = typeof (request.data as {friendUid?: unknown})?.friendUid === 'string' ?
    String((request.data as {friendUid: string}).friendUid).trim() :
    '';
  if (!friendUid || friendUid === currentUid) {
    throw new HttpsError('invalid-argument', 'Invalid friendUid.');
  }
  await db.runTransaction(async (tx) => {
    tx.update(db.collection('users').doc(currentUid), {
      friends: admin.firestore.FieldValue.arrayRemove(friendUid),
    });
    tx.update(db.collection('users').doc(friendUid), {
      friends: admin.firestore.FieldValue.arrayRemove(currentUid),
    });
  });
  return {ok: true};
});

/** Admin removes a member's classroomId and membership (client can no longer write other users). */
export const classroomRemoveMemberAdmin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const classroomId = typeof (request.data as {classroomId?: unknown})?.classroomId === 'string' ?
    String((request.data as {classroomId: string}).classroomId).trim() :
    '';
  const targetUserId = typeof (request.data as {targetUserId?: unknown})?.targetUserId === 'string' ?
    String((request.data as {targetUserId: string}).targetUserId).trim() :
    '';
  if (!classroomId || !targetUserId) {
    throw new HttpsError('invalid-argument', 'classroomId and targetUserId are required.');
  }
  const data = await assertClassroomAdmin(classroomId, uid);
  const members = (data.members as string[]) ?? [];
  if (!members.includes(targetUserId)) {
    throw new HttpsError('failed-precondition', 'Target is not a member.');
  }
  await db.runTransaction(async (tx) => {
    const cref = db.collection('classrooms').doc(classroomId);
    tx.update(cref, {
      members: admin.firestore.FieldValue.arrayRemove(targetUserId),
      adminIds: admin.firestore.FieldValue.arrayRemove(targetUserId),
    });
    tx.update(db.collection('users').doc(targetUserId), {
      classroomIds: admin.firestore.FieldValue.arrayRemove(classroomId),
    });
  });
  return {ok: true};
});

/** Admin deletes classroom doc and strips classroomId from all members. */
export const classroomDeleteWithCleanup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const classroomId = typeof (request.data as {classroomId?: unknown})?.classroomId === 'string' ?
    String((request.data as {classroomId: string}).classroomId).trim() :
    '';
  if (!classroomId) {
    throw new HttpsError('invalid-argument', 'classroomId is required.');
  }
  const snap = await db.collection('classrooms').doc(classroomId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Classroom not found.');
  }
  const data = snap.data()!;
  const adminIds = (data.adminIds as string[]) ?? [];
  if (!adminIds.includes(uid)) {
    throw new HttpsError('permission-denied', 'Only classroom admins can delete a classroom.');
  }
  const members = (data.members as string[]) ?? [];
  let batch = db.batch();
  let n = 0;
  for (const m of members) {
    batch.update(db.collection('users').doc(m), {
      classroomIds: admin.firestore.FieldValue.arrayRemove(classroomId),
    });
    n++;
    if (n >= 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
    }
  }
  batch.delete(db.collection('classrooms').doc(classroomId));
  await batch.commit();
  return {ok: true};
});

/**
 * Trusted onboarding: sets birthDate / hasParentalConsent (15+) and academic fields
 * (clients cannot write these directly — see Firestore rules).
 */
export const completeStudentOnboarding = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const data = (request.data ?? {}) as {
    currentClass?: unknown;
    subjects?: unknown;
    hasTutoring?: unknown;
    tutoringSubjects?: unknown;
    birthDateMillis?: unknown;
  };
  const currentClass = typeof data.currentClass === 'string' ? data.currentClass.trim() : '';
  if (!currentClass) {
    throw new HttpsError('invalid-argument', 'currentClass is required.');
  }
  const birthMs = typeof data.birthDateMillis === 'number' ? data.birthDateMillis :
    typeof data.birthDateMillis === 'string' ? Number(data.birthDateMillis) : NaN;
  if (!Number.isFinite(birthMs)) {
    throw new HttpsError('invalid-argument', 'birthDateMillis is required.');
  }
  const birthDate = new Date(birthMs);
  const subjects = Array.isArray(data.subjects) ?
    data.subjects.filter((s): s is string => typeof s === 'string') :
    [];
  const hasTutoring = !!data.hasTutoring;
  const tutoringSubjects = Array.isArray(data.tutoringSubjects) ?
    data.tutoringSubjects.filter((s): s is string => typeof s === 'string') :
    [];

  const now = new Date();
  let age = now.getFullYear() - birthDate.getFullYear();
  const m = now.getMonth() - birthDate.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < birthDate.getDate())) {
    age--;
  }
  const hasParentalConsent = age >= 15;

  const userRef = db.collection('users').doc(uid);
  await userRef.set({
    currentClass,
    subjects,
    hasTutoring,
    tutoringSubjects,
    isProfileComplete: true,
    birthDate: admin.firestore.Timestamp.fromDate(birthDate),
    hasParentalConsent,
  }, {merge: true});

  const snap = await userRef.get();
  const d = snap.data() ?? {};
  await db.collection('user_public').doc(uid).set({
    uid,
    fullName: (d.fullName as string) ?? '',
    currentClass,
    profilePictureUrl: d.profilePictureUrl ?? null,
    bio: (d.bio as string) ?? '',
    achievements: (d.achievements as string[]) ?? [],
    showBio: d.showBio !== false,
    showAchievements: d.showAchievements !== false,
    shareGrades: !!d.shareGrades,
    preferredLanguage: (d.preferredLanguage as string) ?? 'el',
    schoolRole: (d.schoolRole as string) ?? 'student',
    isProfileComplete: true,
  }, {merge: true});

  return {ok: true, hasParentalConsent};
});

/** Join a classroom using a valid invite code (rules block client-side member self-join). */
export const classroomJoinWithInviteCode = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const inviteCodeRaw = (request.data as {inviteCode?: unknown})?.inviteCode;
  const inviteCode = typeof inviteCodeRaw === 'string' ? inviteCodeRaw.trim() : '';
  if (!inviteCode || inviteCode.length > 32) {
    throw new HttpsError('invalid-argument', 'Invalid invite code.');
  }

  // Rate limit: max 10 join attempts per 60 seconds per uid.
  const rateLimitRef = db.collection('user_private').doc(uid);
  await db.runTransaction(async (tx) => {
    const rateLimitSnap = await tx.get(rateLimitRef);
    const now = Date.now();
    const existing = (rateLimitSnap.data()?.classroomJoinAttempts as number[] | undefined) ?? [];
    const recent = existing.filter((ts) => now - ts < 60_000);
    if (recent.length >= 10) {
      throw new HttpsError('resource-exhausted', 'Too many join attempts. Please wait a minute before trying again.');
    }
    tx.set(rateLimitRef, {classroomJoinAttempts: [...recent, now]}, {merge: true});
  });

  const query = await db.collection('classrooms')
    .where('inviteCode', '==', inviteCode)
    .limit(1)
    .get();
  if (query.empty) {
    throw new HttpsError('not-found', 'Classroom not found.');
  }

  const doc = query.docs[0];
  const classroomId = doc.id;
  const data = doc.data();
  const members = (data.members as string[]) ?? [];

  if (!members.includes(uid)) {
    await doc.ref.update({
      members: admin.firestore.FieldValue.arrayUnion(uid),
    });
  }
  await db.collection('users').doc(uid).update({
    classroomIds: admin.firestore.FieldValue.arrayUnion(classroomId),
  });

  return {
    ok: true,
    classroomId,
    name: (data.name as string) ?? '',
    description: (data.description as string) ?? '',
    inviteCode: (data.inviteCode as string) ?? inviteCode,
    adminIds: (data.adminIds as string[]) ?? [],
    members: members.includes(uid) ? members : [...members, uid],
  };
});

/** Updates the student's grade band / currentClass (blocked from direct client writes). */
export const updateStudentCurrentClass = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  const currentClass = sanitizeCurrentClass(
    (request.data as {currentClass?: unknown})?.currentClass,
  );

  const userRef = db.collection('users').doc(uid);
  await userRef.set({currentClass}, {merge: true});

  const snap = await userRef.get();
  const d = snap.data() ?? {};
  await db.collection('user_public').doc(uid).set({
    uid,
    currentClass,
    fullName: (d.fullName as string) ?? '',
    profilePictureUrl: d.profilePictureUrl ?? null,
    bio: (d.bio as string) ?? '',
    achievements: (d.achievements as string[]) ?? [],
    showBio: d.showBio !== false,
    showAchievements: d.showAchievements !== false,
    shareGrades: !!d.shareGrades,
    preferredLanguage: (d.preferredLanguage as string) ?? 'el',
    schoolRole: (d.schoolRole as string) ?? 'student',
    isProfileComplete: d.isProfileComplete !== false,
  }, {merge: true});

  const postsSnap = await db.collection('homework_posts')
    .where('authorId', '==', uid)
    .get();
  const batch = db.batch();
  for (const postDoc of postsSnap.docs) {
    batch.update(postDoc.ref, {classId: currentClass});
  }
  if (!postsSnap.empty) {
    await batch.commit();
  }

  return {ok: true, currentClass};
});

function generateConsentToken(): string {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const bytes = randomBytes(32);
  let out = '';
  for (let i = 0; i < 32; i++) {
    out += chars[bytes[i]! % chars.length];
  }
  return out;
}

function resolveParentConsentEmailJsSecrets(): {
  serviceId: string;
  templateId: string;
  publicKey: string;
  privateKey: string;
} {
  return {
    serviceId:
      emailJsServiceId.value().trim() || process.env.EMAILJS_SERVICE_ID?.trim() || '',
    templateId:
      emailJsTemplateId.value().trim() || process.env.EMAILJS_TEMPLATE_ID?.trim() || '',
    publicKey:
      emailJsPublicKey.value().trim() || process.env.EMAILJS_PUBLIC_KEY?.trim() || '',
    privateKey:
      emailJsPrivateKey.value().trim() || process.env.EMAILJS_PRIVATE_KEY?.trim() || '',
  };
}

/**
 * Sends the consent email via EmailJS (shared by [sendParentalConsentEmail] and
 * [requestParentalConsent]).
 */
async function postEmailJsParentalConsentEmail(params: {
  parentEmail: string;
  studentName: string;
  token: string;
  uid: string;
  lang: string;
  secrets: ReturnType<typeof resolveParentConsentEmailJsSecrets>;
}): Promise<void> {
  const {parentEmail, studentName, token, uid, lang, secrets} = params;
  const baseUrl = resolveParentConsentBaseUrl();
  if (!baseUrl) {
    throw new HttpsError(
      'failed-precondition',
      'PARENT_CONSENT_BASE_URL is not configured on the server.',
    );
  }
  const encodedName = encodeURIComponent(studentName);
  const approvalLink = `${baseUrl}?uid=${encodeURIComponent(uid)}&token=${encodeURIComponent(token)}&name=${encodedName}`;
  const appDeepLink = `${APP_DEEP_LINK_SCHEME}://consent?uid=${encodeURIComponent(uid)}&token=${encodeURIComponent(token)}&name=${encodedName}`;

  const templateParams: Record<string, string> = {
    parent_email: parentEmail,
    student_name: studentName,
    consent_link: approvalLink,
    consent_app_link: appDeepLink,
    language: lang ?? 'el',
  };

  const res = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      service_id: secrets.serviceId,
      template_id: secrets.templateId,
      user_id: secrets.publicKey,
      accessToken: secrets.privateKey,
      template_params: templateParams,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error('EmailJS error', res.status, body.slice(0, 500));
    throw new HttpsError('failed-precondition', 'Could not send consent email. Try again later.');
  }
}

const PRO_ACTIVATION_CODE_TTL_MS = 15 * 60 * 1000;
const PRO_ACTIVATION_SEND_COOLDOWN_MS = 60 * 1000;
const PRO_ACTIVATION_MAX_ATTEMPTS = 8;

function normalizeAccountEmail(email: string): string {
  return email.trim().toLowerCase();
}

function resolveProActivationEmailJsSecrets(): {
  serviceId: string;
  templateId: string;
  publicKey: string;
  privateKey: string;
} {
  return {
    serviceId:
      proActivationEmailJsServiceId.value().trim() ||
      process.env.PRO_ACTIVATION_EMAILJS_SERVICE_ID?.trim() ||
      '',
    templateId:
      proActivationEmailJsTemplateId.value().trim() ||
      process.env.PRO_ACTIVATION_EMAILJS_TEMPLATE_ID?.trim() ||
      '',
    publicKey:
      proActivationEmailJsPublicKey.value().trim() ||
      process.env.PRO_ACTIVATION_EMAILJS_PUBLIC_KEY?.trim() ||
      '',
    privateKey:
      proActivationEmailJsPrivateKey.value().trim() ||
      process.env.PRO_ACTIVATION_EMAILJS_PRIVATE_KEY?.trim() ||
      '',
  };
}

/** Production requires Firebase Secret Manager; emulator / LOCAL_DEMO_MODE allows a deterministic pepper. */
function resolveProActivationCodePepper(): string {
  const fromSecret =
    proActivationCodePepper.value().trim() ||
    process.env.PRO_ACTIVATION_CODE_PEPPER?.trim() ||
    '';
  if (fromSecret.length > 0) return fromSecret;
  if (LOCAL_DEMO_MODE) return 'LOCAL_DEMO_PRO_ACTIVATION_CODE_PEPPER';
  return '';
}

function sanitizeActivationCodeDigits(raw: string): string {
  return raw.replace(/\D/g, '').slice(0, 8);
}

function hashProActivationCode(
  uid: string,
  normalizedEmail: string,
  plainCodeDigits: string,
  pepper: string,
): string {
  return createHash('sha256')
    .update(pepper, 'utf8')
    .update('|')
    .update(uid)
    .update('|')
    .update(normalizedEmail)
    .update('|')
    .update(plainCodeDigits)
    .digest('hex');
}

function timingSafeEqualHex(leftHex: string, rightHex: string): boolean {
  try {
    const a = Buffer.from(leftHex, 'hex');
    const b = Buffer.from(rightHex, 'hex');
    if (a.length !== b.length || a.length !== 32) return false;
    return timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

async function postEmailJsProActivationEmail(params: {
  toEmail: string;
  activationCode: string;
  secrets: ReturnType<typeof resolveProActivationEmailJsSecrets>;
}): Promise<void> {
  const {toEmail, activationCode, secrets} = params;
  const templateParams: Record<string, string> = {
    /** EmailJS template should map `to_email` to recipient and `activation_code` to the body text. */
    to_email: toEmail,
    activation_code: activationCode,
    app_name: 'ScholiLink',
  };

  const res = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
      service_id: secrets.serviceId,
      template_id: secrets.templateId,
      user_id: secrets.publicKey,
      accessToken: secrets.privateKey,
      template_params: templateParams,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error('EmailJS pro activation error', res.status, body.slice(0, 500));
    throw new HttpsError(
      'failed-precondition',
      'Could not send activation email. Try again later.',
    );
  }
}

function proActivationClearsPayload(): Record<string, admin.firestore.FieldValue> {
  return {
    proActivationCodeHash: admin.firestore.FieldValue.delete(),
    proActivationExpiresAt: admin.firestore.FieldValue.delete(),
    proActivationEmailNorm: admin.firestore.FieldValue.delete(),
    proActivationAttempts: admin.firestore.FieldValue.delete(),
    proActivationLastSentAt: admin.firestore.FieldValue.delete(),
  };
}

/**
 * Sends a one-time numeric code via EmailJS. Code hash is stored server-side under `user_private/{uid}`.
 */
export const sendProActivationCode = onCall(
  {
    secrets: [
      proActivationEmailJsServiceId,
      proActivationEmailJsTemplateId,
      proActivationEmailJsPublicKey,
      proActivationEmailJsPrivateKey,
      proActivationCodePepper,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in.');
    }
    const uid = request.auth.uid;

    const tokenEmailRaw = request.auth.token.email;
    const tokenEmailNorm = typeof tokenEmailRaw === 'string' ? normalizeAccountEmail(tokenEmailRaw) : '';
    if (!tokenEmailNorm || !tokenEmailNorm.includes('@')) {
      throw new HttpsError(
        'failed-precondition',
        'ScholiLink Pro activation requires an account with an email address. Sign in again with Email or Google.',
      );
    }

    const pepper = resolveProActivationCodePepper();
    if (!pepper) {
      throw new HttpsError(
        'failed-precondition',
        'Pro activation is not configured (missing PRO_ACTIVATION_CODE_PEPPER).',
      );
    }

    const {email} = (request.data ?? {}) as {email?: unknown};
    const requestedNorm =
      typeof email === 'string' ? normalizeAccountEmail(email) : '';
    if (!requestedNorm.includes('@')) {
      throw new HttpsError('invalid-argument', 'Enter your account email.');
    }
    if (requestedNorm !== tokenEmailNorm) {
      throw new HttpsError(
        'permission-denied',
        'This email must match the address on your logged-in Firebase account.',
      );
    }

    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'User profile not found.');
    }

    const subType = `${(userSnap.data()?.subscriptionType as string | undefined)?.toLowerCase() ?? 'free'}`;
    if (subType === 'pro') {
      return {ok: true, alreadyPro: true};
    }

    const privRef = db.collection('user_private').doc(uid);
    const privSnap = await privRef.get();
    const pdata = privSnap.data() ?? {};
    const lastSent = pdata.proActivationLastSentAt as admin.firestore.Timestamp | undefined;
    if (lastSent) {
      const elapsed = Date.now() - lastSent.toMillis();
      if (elapsed >= 0 && elapsed < PRO_ACTIVATION_SEND_COOLDOWN_MS) {
        throw new HttpsError(
          'resource-exhausted',
          'Please wait a minute before requesting another activation code.',
        );
      }
    }

    const plainCode = `${randomInt(0, 1_000_000)}`.padStart(6, '0');
    const codeHash = hashProActivationCode(uid, tokenEmailNorm, plainCode, pepper);

    await privRef.set(
      {
        proActivationCodeHash: codeHash,
        proActivationExpiresAt: admin.firestore.Timestamp.fromMillis(
          Date.now() + PRO_ACTIVATION_CODE_TTL_MS,
        ),
        proActivationEmailNorm: tokenEmailNorm,
        proActivationAttempts: 0,
      },
      {merge: true},
    );

    try {
      if (!LOCAL_DEMO_MODE) {
        const secrets = resolveProActivationEmailJsSecrets();
        if (
          !secrets.serviceId ||
          !secrets.templateId ||
          !secrets.publicKey ||
          !secrets.privateKey
        ) {
          logger.error('sendProActivationCode: missing EmailJS secrets/env', {
            hasServiceId: !!secrets.serviceId,
            hasTemplateId: !!secrets.templateId,
            hasPublicKey: !!secrets.publicKey,
            hasPrivateKey: !!secrets.privateKey,
          });
          throw new HttpsError(
            'failed-precondition',
            'Activation email service is not configured on the server (EmailJS secrets).',
          );
        }

        await postEmailJsProActivationEmail({
          toEmail: requestedNorm,
          activationCode: plainCode,
          secrets,
        });
      } else {
        logger.warn('LOCAL_DEMO_MODE: skipping activation email send.', {uid});
      }

      await privRef.set(
        {
          proActivationLastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    } catch (e: unknown) {
      await privRef.set(proActivationClearsPayload(), {merge: true});
      if (e instanceof HttpsError) throw e;
      logger.error('sendProActivationCode: activation email pipeline failed', {
        uid,
        err: e instanceof Error ? e.message : String(e),
      });
      throw new HttpsError(
        'failed-precondition',
        'Could not send activation email. Try again later.',
      );
    }

    return {ok: true, localDemoMode: LOCAL_DEMO_MODE};
  },
);

/**
 * Validates the OTP and upgrades `subscriptionType` to `pro`. Client cannot write quota fields directly.
 */
export const verifyProActivationAndUnlock = onCall(
  {secrets: [proActivationCodePepper]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in.');
    }
    const uid = request.auth.uid;

    const tokenEmailRaw = request.auth.token.email;
    const tokenEmailNorm = typeof tokenEmailRaw === 'string' ? normalizeAccountEmail(tokenEmailRaw) : '';
    if (!tokenEmailNorm || !tokenEmailNorm.includes('@')) {
      throw new HttpsError(
        'failed-precondition',
        'ScholiLink Pro activation requires an account with an email address.',
      );
    }

    const pepper = resolveProActivationCodePepper();
    if (!pepper) {
      throw new HttpsError(
        'failed-precondition',
        'Pro activation is not configured (missing PRO_ACTIVATION_CODE_PEPPER).',
      );
    }

    const {code} = (request.data ?? {}) as {code?: unknown};
    const digits = sanitizeActivationCodeDigits(`${code ?? ''}`);
    if (!/^\d{6}$/.test(digits)) {
      throw new HttpsError('invalid-argument', 'Enter the 6-digit code from your email.');
    }

    const preSnap = await db.collection('users').doc(uid).get();
    if (!preSnap.exists) {
      throw new HttpsError('not-found', 'User profile not found.');
    }

    const existingPlan =
      `${(preSnap.data()?.subscriptionType as string | undefined)?.toLowerCase() ?? 'free'}`;
    if (existingPlan === 'pro') {
      await db.collection('user_private').doc(uid).set(proActivationClearsPayload(), {merge: true});
      return {ok: true, alreadyPro: true};
    }

    try {
      await db.runTransaction(async (transaction) => {
        const refreshed = await getOrRefreshUserSparks(uid, transaction);

        const subEarly = `${(refreshed.subscriptionType as string | undefined)?.toLowerCase() ?? 'free'}`;
        const privRef = db.collection('user_private').doc(uid);

        const clearPending = (): void => {
          transaction.set(privRef, proActivationClearsPayload(), {merge: true});
        };

        if (subEarly === 'pro') {
          clearPending();
          return;
        }

        const privSnap = await transaction.get(privRef);
        const pdata = privSnap.data() ?? {};
        const storedHash = pdata.proActivationCodeHash as string | undefined;
        const expiresAt = pdata.proActivationExpiresAt as admin.firestore.Timestamp | undefined;
        const pendingEmailNorm = pdata.proActivationEmailNorm as string | undefined;
        const attempts = typeof pdata.proActivationAttempts === 'number' ? pdata.proActivationAttempts : 0;

        if (!storedHash || !expiresAt) {
          clearPending();
          throw new HttpsError(
            'failed-precondition',
            'No pending activation code. Request a new one from ScholiLink Pro.',
          );
        }

        const normPending = normalizeAccountEmail(pendingEmailNorm ?? '');
        if (normPending !== tokenEmailNorm) {
          clearPending();
          throw new HttpsError('permission-denied', 'Activation session does not match this account.');
        }

        const nowMs = Date.now();
        if (expiresAt.toMillis() < nowMs) {
          clearPending();
          throw new HttpsError('deadline-exceeded', 'That code expired. Request a new activation email.');
        }

        const expectedHash = hashProActivationCode(uid, tokenEmailNorm, digits, pepper);
        const okCompare = timingSafeEqualHex(expectedHash, storedHash);
        if (!okCompare) {
          const nextAttempts = attempts + 1;
          if (nextAttempts >= PRO_ACTIVATION_MAX_ATTEMPTS) {
            clearPending();
          } else {
            transaction.update(privRef, {
              proActivationAttempts: nextAttempts,
            });
          }
          throw new HttpsError('permission-denied', 'Incorrect activation code.');
        }

        clearPending();

        const currentSparks = refreshed.aiSparks ?? 0;
        const userRef = db.collection('users').doc(uid);
        transaction.update(userRef, {
          subscriptionType: 'pro',
          aiSparks: Math.max(currentSparks, PLAN_LIMITS.pro),
        });
      });
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      logger.error('verifyProActivationAndUnlock failed', {
        uid,
        err: e instanceof Error ? e.message : String(e),
      });
      throw new HttpsError('internal', 'Could not activate Pro.');
    }

    return {ok: true};
  },
);

/**
 * Confirms parental consent using the secure token from the email link.
 * Callable without Firebase Auth (parent may not have an account).
 */
export const verifyParentalConsent = onCall(async (request) => {
  const {uid, token} = (request.data ?? {}) as {uid?: unknown; token?: unknown};
  const uidStr = typeof uid === 'string' ? uid.trim() : '';
  const tokenStr = typeof token === 'string' ? token.trim() : '';
  if (!uidStr || !tokenStr) {
    throw new HttpsError('invalid-argument', 'uid and token are required.');
  }

  const attemptsRef = db.collection('consent_verify_attempts').doc(uidStr);
  const attemptsSnap = await attemptsRef.get();
  const attemptCount = (attemptsSnap.data()?.count as number | undefined) ?? 0;
  if (attemptCount >= 25) {
    throw new HttpsError('resource-exhausted', 'Too many verification attempts. Try again later.');
  }
  await attemptsRef.set({
    count: attemptCount + 1,
    lastAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  const userRef = db.collection('users').doc(uidStr);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'User not found.');
  }

  const data = snap.data()!;
  const stored = data.consentToken as string | undefined;
  // Use timing-safe comparison — this endpoint is unauthenticated (parents click an email link).
  // Plain !== leaks info via response-time side-channels on high-value tokens.
  const tokenMatch = !!stored &&
    stored.length === tokenStr.length &&
    timingSafeEqual(Buffer.from(stored, 'utf8'), Buffer.from(tokenStr, 'utf8'));
  if (!tokenMatch) {
    throw new HttpsError('permission-denied', 'Invalid or expired consent link.');
  }

  const expiresAt = data.consentTokenExpiresAt as admin.firestore.Timestamp | undefined;
  if (expiresAt && expiresAt.toDate() < new Date()) {
    throw new HttpsError('deadline-exceeded', 'Consent link has expired. Please request a new one.');
  }

  await userRef.update({
    hasParentalConsent: true,
    consentVerificationStatus: 'approved',
    consentToken: `verified_${tokenStr}`,
  });

  await attemptsRef.delete();

  return {ok: true};
});

/**
 * Generates a consent token, updates the student profile, and emails the parent.
 * Preferred entry point for the Flutter app (replaces client-side token generation).
 */
export const requestParentalConsent = onCall(
  {
    secrets: [emailJsServiceId, emailJsTemplateId, emailJsPublicKey, emailJsPrivateKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in.');
    }
    const uid = request.auth.uid;
    const {parentEmail, lang} = (request.data ?? {}) as {
      parentEmail?: string;
      lang?: string;
    };
    const parentEmailTrim = (parentEmail ?? '').trim();
    if (!parentEmailTrim || !parentEmailTrim.includes('@')) {
      throw new HttpsError('invalid-argument', 'Valid parent email is required.');
    }

    const token = generateConsentToken();

    await db.collection('users').doc(uid).update({
      parentEmail: parentEmailTrim,
      consentVerificationStatus: 'pending',
      consentToken: token,
      consentTokenExpiresAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
      hasParentalConsent: false,
    });

    const userDoc = await db.collection('users').doc(uid).get();
    const fullName = ((userDoc.data()?.fullName as string) ?? '').trim();
    const studentName = fullName || 'Student';

    if (!LOCAL_DEMO_MODE) {
      const secrets = resolveParentConsentEmailJsSecrets();
      if (!secrets.serviceId || !secrets.templateId || !secrets.publicKey || !secrets.privateKey) {
        console.error('requestParentalConsent: missing EmailJS secrets/env', {
          hasServiceId: !!secrets.serviceId,
          hasTemplateId: !!secrets.templateId,
          hasPublicKey: !!secrets.publicKey,
          hasPrivateKey: !!secrets.privateKey,
        });
        throw new HttpsError(
          'failed-precondition',
          'Email service is not configured on the server (EmailJS env).',
        );
      }
      await postEmailJsParentalConsentEmail({
        parentEmail: parentEmailTrim,
        studentName,
        token,
        uid,
        lang: lang ?? 'el',
        secrets,
      });
    }

    return {ok: true, localDemoMode: LOCAL_DEMO_MODE};
  },
);

/**
 * Clears the parental-consent fields for the calling user.
 * Must use Admin SDK because Firestore rules block client writes to these fields.
 */
export const resetParentalConsent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'User must be signed in.');
  }
  const uid = request.auth.uid;
  await db.collection('users').doc(uid).update({
    parentEmail: admin.firestore.FieldValue.delete(),
    consentVerificationStatus: admin.firestore.FieldValue.delete(),
    consentToken: admin.firestore.FieldValue.delete(),
    hasParentalConsent: admin.firestore.FieldValue.delete(),
  });
  return {ok: true};
});

/**
 * Sends parental consent email via EmailJS. Values must be in **Secret Manager** and
 * listed in `secrets` below so each deploy wires them into this function (reliable on
 * Cloud Run gen 2). Setting only “environment variables” in the Firebase Console often
 * does not survive the next `firebase deploy`, or applies to a different service.
 *
 * Setup (once per project) — secret **names** (not EmailJS dashboard names):
 *   firebase functions:secrets:set PARENT_CONSENT_EMAILJS_SERVICE_ID
 *   firebase functions:secrets:set PARENT_CONSENT_EMAILJS_TEMPLATE_ID
 *   firebase functions:secrets:set PARENT_CONSENT_EMAILJS_PUBLIC_KEY
 *   firebase functions:secrets:set PARENT_CONSENT_EMAILJS_PRIVATE_KEY
 *   firebase deploy --only functions
 *
 * Paste the same values you use in EmailJS (service id, template id, public key, private key).
 * Older secrets named `EMAILJS_*` are optional to delete in GCP; they are not used by this code.
 *
 * Handler falls back to `process.env.EMAILJS_*` when new secret values are empty (emulator).
 */
export const sendParentalConsentEmail = onCall(
  {
    secrets: [emailJsServiceId, emailJsTemplateId, emailJsPublicKey, emailJsPrivateKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be signed in.');
    }
    const {parentEmail, studentName, token, uid, lang} = request.data as {
      parentEmail?: string;
      studentName?: string;
      token?: string;
      uid?: string;
      lang?: string;
    };
    const parentEmailTrim = (parentEmail ?? '').trim();
    const studentNameSafe = (studentName ?? '').trim() || 'Student';
    const tokenTrim = (token ?? '').trim();
    if (!parentEmailTrim || !tokenTrim || !uid || uid !== request.auth.uid) {
      throw new HttpsError(
        'invalid-argument',
        'Missing or invalid consent email fields (need parent email, token, and matching uid).',
      );
    }

    // Verify the provided token matches the one stored in Firestore.
    // Prevents sending emails with arbitrary/stale tokens and stops abuse of this endpoint.
    const userDocForToken = await db.collection('users').doc(uid).get();
    if (!userDocForToken.exists) {
      throw new HttpsError('not-found', 'User not found.');
    }
    const storedConsentToken = userDocForToken.data()?.consentToken as string | undefined;
    if (!storedConsentToken || storedConsentToken !== tokenTrim || storedConsentToken.startsWith('verified_')) {
      throw new HttpsError('permission-denied', 'Token does not match the stored consent token or has already been used.');
    }

    if (!LOCAL_DEMO_MODE) {
      const secrets = resolveParentConsentEmailJsSecrets();
      if (!secrets.serviceId || !secrets.templateId || !secrets.publicKey || !secrets.privateKey) {
        console.error('sendParentalConsentEmail: missing EmailJS secrets/env', {
          hasServiceId: !!secrets.serviceId,
          hasTemplateId: !!secrets.templateId,
          hasPublicKey: !!secrets.publicKey,
          hasPrivateKey: !!secrets.privateKey,
        });
        throw new HttpsError(
          'failed-precondition',
          'Email service is not configured on the server (EmailJS env).',
        );
      }

      await postEmailJsParentalConsentEmail({
        parentEmail: parentEmailTrim,
        studentName: studentNameSafe,
        token: tokenTrim,
        uid,
        lang: lang ?? 'el',
        secrets,
      });
    }

    return {ok: true, localDemoMode: LOCAL_DEMO_MODE};
  },
);

/** Applies the same daily refresh rules as [chatWithAi] without deducting a Spark. */
export const getSparkStatus = onCall(async (request) => {
  const tz = SPARK_RESET_TIMEZONE;
  const nextRefreshAt = getNextSparkResetUtc(new Date(), tz).toISOString();

  if (!request.auth) {
    return {
      sparks: 0,
      plan: 'free',
      nextRefreshAt,
      sparkTimezone: tz,
    };
  }

  const uid = request.auth.uid;

  await db.runTransaction(async (transaction) => {
    await getOrRefreshUserSparks(uid, transaction);
  });

  const userDoc = await db.collection('users').doc(uid).get();
  const data = userDoc.data();
  return {
    sparks: data?.aiSparks ?? 0,
    plan: normalizedSubscriptionPlan(data?.subscriptionType),
    nextRefreshAt,
    sparkTimezone: tz,
  };
});

type NotificationPrefKey =
  | 'notifyMessages'
  | 'notifyHomeworkOverdue'
  | 'notifyExamPrepOverdue'
  | 'notifyDailyDigest'
  | 'notifyInactivity'
  | 'notifyClassUpdates';

function notificationsEnabled(
  userData: Record<string, unknown>,
  key: NotificationPrefKey,
): boolean {
  const raw = userData[key];
  if (typeof raw === 'boolean') return raw;
  return true;
}

type AppLang = 'el' | 'en';

function userLang(userData: Record<string, unknown>): AppLang {
  return String(userData.preferredLanguage ?? 'el') === 'en' ? 'en' : 'el';
}

function firstName(fullName: string, lang: AppLang): string {
  const trimmed = fullName.trim();
  if (!trimmed) return lang === 'el' ? 'Χρήστης' : 'User';
  return trimmed.split(/\s+/)[0] ?? trimmed;
}

function truncateNotificationText(text: string, maxLen: number): string {
  const trimmed = text.trim();
  if (trimmed.length <= maxLen) return trimmed;
  return `${trimmed.slice(0, maxLen - 1).trimEnd()}…`;
}

function localNowFromOffset(offsetMinutes: number): Date {
  const utcNowMs = Date.now();
  return new Date(utcNowMs + offsetMinutes * 60_000);
}

function ymdKey(d: Date): string {
  const y = d.getUTCFullYear();
  const m = `${d.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${d.getUTCDate()}`.padStart(2, '0');
  return `${y}-${m}-${day}`;
}

async function getUserTokens(uid: string): Promise<string[]> {
  const snap = await db.collection('users').doc(uid).collection('device_tokens').get();
  return snap.docs.map((d) => String(d.id)).filter((v) => v.length > 0);
}

async function pruneInvalidTokens(uid: string, invalidTokens: string[]): Promise<void> {
  if (invalidTokens.length === 0) return;
  const batch = db.batch();
  for (const token of invalidTokens) {
    batch.delete(db.collection('users').doc(uid).collection('device_tokens').doc(token));
  }
  await batch.commit();
}

async function sendPushToUser(input: {
  uid: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  const tokens = await getUserTokens(input.uid);
  if (tokens.length === 0) return;
  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: input.title,
      body: input.body,
    },
    data: {
      recipientUid: input.uid,
      ...(input.data ?? {}),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'scholilink_high_priority',
      },
    },
  });
  const invalidTokens: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code ?? '';
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        invalidTokens.push(tokens[i] ?? '');
      }
    }
  });
  await pruneInvalidTokens(input.uid, invalidTokens.filter(Boolean));
}

async function shouldSendOncePerDay(uid: string, type: string, itemId: string, dayKey: string): Promise<boolean> {
  const id = `${uid}_${type}_${itemId}_${dayKey}`;
  const ref = db.collection('notification_ledger').doc(id);
  const snap = await ref.get();
  if (snap.exists) return false;
  await ref.set({
    uid,
    type,
    itemId,
    dayKey,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return true;
}

/** One physical device token may only belong to one user at a time. */
export const enforceUniqueDeviceToken = onDocumentCreated(
  'users/{userId}/device_tokens/{tokenId}',
  async (event) => {
    const {userId, tokenId} = event.params;
    if (!tokenId) return;

    const duplicates = await db.collectionGroup('device_tokens')
      .where('token', '==', tokenId)
      .get();

    const batch = db.batch();
    let deletes = 0;
    for (const doc of duplicates.docs) {
      const ownerUid = doc.ref.parent.parent?.id;
      if (ownerUid && ownerUid !== userId) {
        batch.delete(doc.ref);
        deletes++;
      }
    }
    if (deletes > 0) {
      await batch.commit();
    }
  },
);

export const moderateClassroomMessageOnCreate = onDocumentCreated(
  'classrooms/{classroomId}/messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data || !event.data) return;
    const text = String(data.text ?? '').trim();
    const authorId = String(data.authorId ?? '');
    if (!text || !authorId) return;
    try {
      const {flagged} = await moderateMessageText(text, authorId);
      if (flagged) {
        await event.data.ref.delete();
      }
    } catch (e) {
      // Keep the message when moderation is misconfigured or temporarily unavailable.
      logger.error('moderateClassroomMessageOnCreate — moderation skipped', e);
    }
  },
);

export const notifyDirectMessage = onDocumentCreated(
  'direct_chats/{chatId}/messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data || !event.data) return;
    const chatId = event.params.chatId;
    const senderId = String(data.senderId ?? '');
    if (!senderId) return;
    const text = String(data.text ?? '').trim();
    if (text) {
      try {
        const {flagged} = await moderateMessageText(text, senderId);
        if (flagged) {
          await event.data.ref.delete();
          await refreshDirectChatPreview(chatId);
          return;
        }
      } catch (e) {
        // Do not delete messages when the AI key is missing/invalid or the model is down.
        logger.error('notifyDirectMessage moderation skipped — keeping message', e);
      }
    }
    const chatSnap = await db.collection('direct_chats').doc(chatId).get();
    if (!chatSnap.exists) return;
    const chat = chatSnap.data() ?? {};
    const participants = Array.isArray(chat.participants) ? chat.participants as unknown[] : [];

    // Server-authoritative unread increment (avoids client race + moderation leaks).
    for (const participant of participants) {
      const uid = String(participant ?? '');
      if (!uid || uid === senderId) continue;
      await db.collection('direct_chats').doc(chatId).update({
        [`unreadCounts.${uid}`]: admin.firestore.FieldValue.increment(1),
      });
    }

    const senderSnap = await db.collection('users').doc(senderId).get();
    const senderData = senderSnap.data() ?? {};
    for (const participant of participants) {
      const uid = String(participant ?? '');
      if (!uid || uid === senderId) continue;
      const userSnap = await db.collection('users').doc(uid).get();
      const userData = userSnap.data() ?? {};
      if (!notificationsEnabled(userData, 'notifyMessages')) continue;
      const lang = userLang(userData);
      const senderName = firstName(String(senderData.fullName ?? ''), lang);
      let body: string;
      if (text) {
        body = `${senderName}: ${truncateNotificationText(text, 80)}`;
      } else if (data.voiceUrl) {
        body = lang === 'el' ?
          `${senderName}: Ηχητικό μήνυμα` :
          `${senderName}: Voice message`;
      } else {
        body = lang === 'el' ?
          `${senderName}: Φωτογραφία` :
          `${senderName}: Photo`;
      }
      await sendPushToUser({
        uid,
        title: lang === 'el' ? 'Νέο μήνυμα' : 'New message',
        body,
        data: {
          type: 'direct_message',
          chatId,
          senderId,
        },
      });
    }
  },
);

export const notifyClassroomHomeworkPost = onDocumentCreated(
  'classrooms/{classroomId}/homework_feed/{postId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const classroomId = event.params.classroomId;
    const authorId = String(data.authorId ?? '');
    const rawContent = String(data.content ?? '').trim();
    const classroom = await db.collection('classrooms').doc(classroomId).get();
    if (!classroom.exists) return;
    const classroomData = classroom.data() ?? {};
    const classroomLabel = String(
      classroomData.name ?? classroomData.subject ?? classroomId,
    ).trim();
    const members = Array.isArray(classroomData.members) ? classroomData.members as unknown[] : [];
    for (const member of members) {
      const uid = String(member ?? '');
      if (!uid || uid === authorId) continue;
      const userSnap = await db.collection('users').doc(uid).get();
      const userData = userSnap.data() ?? {};
      if (!notificationsEnabled(userData, 'notifyClassUpdates')) continue;
      const lang = userLang(userData);
      const preview = truncateNotificationText(
        rawContent || (lang === 'el' ? 'Νέα εργασία' : 'New homework'),
        80,
      );
      const body = classroomLabel.length > 0 ?
        `${truncateNotificationText(classroomLabel, 40)}: ${preview}` :
        preview;
      await sendPushToUser({
        uid,
        title: lang === 'el' ? 'Νέα ανάρτηση στην τάξη' : 'New class post',
        body,
        data: {
          type: 'classroom_homework',
          classroomId,
        },
      });
    }
  },
);

/** Applies a safety penalty to the reported user when a message report is filed. */
export const applyReportPenaltyOnCreate = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const reportedUserId = String(data.reportedUserId ?? '').trim();
    if (!reportedUserId) return;
    try {
      await applySafetyPenaltyForUid(reportedUserId, 'reported');
    } catch (e) {
      logger.error('applyReportPenaltyOnCreate failed', e);
    }
  },
);

export const nightlyReminderSweep = onSchedule('every 30 minutes', async () => {
  const users = await db.collection('users').get();
  for (const userDoc of users.docs) {
    const uid = userDoc.id;
    const userData = userDoc.data() as Record<string, unknown>;
    const offsetMinutesRaw = Number(userData.timezoneOffsetMinutes ?? 120);
    const offsetMinutes = Number.isFinite(offsetMinutesRaw) ? offsetMinutesRaw : 120;
    const localNow = localNowFromOffset(offsetMinutes);
    const localHour = localNow.getUTCHours();
    const localMinute = localNow.getUTCMinutes();
    if (localHour !== 21 || localMinute < 25 || localMinute > 35) continue;
    const todayKey = ymdKey(localNow);
    const tomorrow = new Date(Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate() + 1));
    const tomorrowKey = ymdKey(tomorrow);

    if (notificationsEnabled(userData, 'notifyHomeworkOverdue')) {
      const hwSnap = await db.collection('users').doc(uid).collection('personal_homework').get();
      const completedSnap = await db.collection('users').doc(uid).collection('completed_homework').get();
      const completed = new Set(completedSnap.docs.map((d) => d.id));
      for (const hw of hwSnap.docs) {
        const hwd = hw.data();
        const dueDateMs = Number(hwd.dueDate ?? NaN);
        if (!Number.isFinite(dueDateMs)) continue;
        const dueLocal = new Date(dueDateMs + offsetMinutes * 60_000);
        if (ymdKey(dueLocal) !== tomorrowKey) continue;
        if (completed.has(hw.id) || hwd.isCompleted === true) continue;
        const canSend = await shouldSendOncePerDay(uid, 'homework_overdue', hw.id, todayKey);
        if (!canSend) continue;
        const lang = userLang(userData);
        await sendPushToUser({
          uid,
          title: lang === 'el' ? 'Υπενθύμιση εργασίας' : 'Homework reminder',
          body: lang === 'el' ?
            'Δεν έχει σημειωθεί ολοκλήρωση για εργασία που λήγει αύριο.' :
            'Homework due tomorrow is not marked complete yet.',
          data: {type: 'homework_overdue', homeworkId: hw.id},
        });
      }
    }

    const currentClass = String(userData.currentClass ?? '').trim();
    if (currentClass && notificationsEnabled(userData, 'notifyExamPrepOverdue')) {
      const examSnap = await db.collection('exams').where('classId', '==', currentClass).get();
      for (const exam of examSnap.docs) {
        const examDate = exam.data().date as admin.firestore.Timestamp | undefined;
        if (!examDate) continue;
        const examDateObj = examDate.toDate();
        const examDayKey = ymdKey(new Date(Date.UTC(
          examDateObj.getUTCFullYear(),
          examDateObj.getUTCMonth(),
          examDateObj.getUTCDate(),
        )));
        if (examDayKey !== tomorrowKey) continue;
        const subject = String(exam.data().subject ?? '').trim();
        if (!subject) continue;
        const attempts = await db
          .collection('quiz_attempts')
          .where('userId', '==', uid)
          .where('subjectName', '==', subject)
          .limit(1)
          .get();
        if (!attempts.empty) continue;
        const canSend = await shouldSendOncePerDay(uid, 'exam_prep_overdue', exam.id, todayKey);
        if (!canSend) continue;
        const lang = userLang(userData);
        await sendPushToUser({
          uid,
          title: lang === 'el' ? 'Υπενθύμιση προετοιμασίας' : 'Exam prep reminder',
          body: lang === 'el' ?
            `Δεν έχει ολοκληρωθεί test προετοιμασίας για ${subject}.` :
            `Exam prep quiz for ${subject} is not completed yet.`,
          data: {type: 'exam_prep_overdue', examId: exam.id},
        });
      }
    }

    if (notificationsEnabled(userData, 'notifyDailyDigest')) {
      const canSend = await shouldSendOncePerDay(uid, 'daily_digest', 'next_day', todayKey);
      if (canSend) {
        const lang = userLang(userData);
        await sendPushToUser({
          uid,
          title: lang === 'el' ? 'Αυριανό πρόγραμμα' : 'Tomorrow\'s schedule',
          body: lang === 'el' ?
            'Έλεγξε εργασίες και εξετάσεις που λήγουν/γίνονται αύριο.' :
            'Review homework and exams due or scheduled for tomorrow.',
          data: {type: 'daily_digest'},
        });
      }
    }

    if (notificationsEnabled(userData, 'notifyInactivity')) {
      const attempts = await db
        .collection('quiz_attempts')
        .where('userId', '==', uid)
        .orderBy('timestamp', 'desc')
        .limit(1)
        .get();
      const latest = attempts.docs.length > 0 ? attempts.docs[0].data() : undefined;
      const latestTs = latest?.timestamp as admin.firestore.Timestamp | undefined;
      if (latestTs) {
        const days = Math.floor((Date.now() - latestTs.toDate().getTime()) / (24 * 60 * 60 * 1000));
        if (days >= 3) {
          const canSend = await shouldSendOncePerDay(uid, 'inactivity', `d${days}`, todayKey);
          if (canSend) {
            const lang = userLang(userData);
            await sendPushToUser({
              uid,
              title: lang === 'el' ? 'Μικρή υπενθύμιση μελέτης' : 'Study reminder',
              body: lang === 'el' ?
                'Έχουν περάσει μερικές μέρες χωρίς δραστηριότητα. Κάνε ένα μικρό βήμα σήμερα.' :
                'It has been a few days since your last activity. Take a small step today.',
              data: {type: 'inactivity'},
            });
          }
        }
      }
    }
  }
});
