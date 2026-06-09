const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

/**
 * Resolve Firebase project id for the Admin SDK so Auth/Firestore emulator
 * namespaces match the Flutter client (assets/.env FIREBASE_PROJECT_ID).
 * Priority: shell FIREBASE_PROJECT_ID → assets/.env → GCLOUD_PROJECT → demo default.
 */
function readProjectIdFromAssetsEnv() {
  const envPath = path.join(__dirname, '../../assets/.env');
  try {
    const raw = fs.readFileSync(envPath, 'utf8');
    for (const line of raw.split(/\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq === -1) continue;
      const key = trimmed.slice(0, eq).trim();
      if (key !== 'FIREBASE_PROJECT_ID') continue;
      const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
      if (val && !val.startsWith('YOUR_')) return val;
    }
  } catch {
    // missing or unreadable assets/.env
  }
  return null;
}

const projectId =
  (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PROJECT_ID.trim()) ||
  readProjectIdFromAssetsEnv() ||
  (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT.trim()) ||
  'student-dashboard-greece';
const host = process.env.FIREBASE_EMULATOR_HOST || '127.0.0.1';

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || `${host}:8080`;
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || `${host}:9099`;

if (!admin.apps.length) {
  admin.initializeApp({projectId});
}

const db = admin.firestore();
const auth = admin.auth();

const now = Date.now();
const tomorrow = now + 24 * 60 * 60 * 1000;

const demoUsers = [
  {
    uid: 'demo-student-1',
    email: 'student@example.com',
    password: 'Passw0rd!',
    fullName: 'Demo Student',
    currentClass: 'A-Lykeio-General',
  },
  {
    uid: 'demo-student-2',
    email: 'teammate@example.com',
    password: 'Passw0rd!',
    fullName: 'Teammate Student',
    currentClass: 'A-Lykeio-General',
  },
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function upsertAuthUser(user, attempt = 0) {
  try {
    try {
      await auth.getUser(user.uid);
      await auth.updateUser(user.uid, {
        email: user.email,
        password: user.password,
        displayName: user.fullName,
      });
    } catch {
      await auth.createUser({
        uid: user.uid,
        email: user.email,
        password: user.password,
        displayName: user.fullName,
      });
    }
  } catch (err) {
    const msg = String(err && err.message ? err.message : err);
    const code = String(
      (err && err.code) ||
        (err && err.errorInfo && err.errorInfo.code) ||
        '',
    );
    const transient =
      /ECONNREFUSED|ENOTFOUND|socket hang up|UNAVAILABLE|503|deadline|network-error/i.test(
        msg,
      ) ||
      code === 'app/network-error';
    if (transient && attempt < 30) {
      await sleep(2000);
      return upsertAuthUser(user, attempt + 1);
    }
    throw err;
  }
}

async function seedUserDocs(user) {
  const userDoc = {
    uid: user.uid,
    email: user.email,
    fullName: user.fullName,
    schoolRole: 'student',
    currentClass: user.currentClass,
    absences: 4,
    aiSparks: 25,
    subscriptionType: 'free',
    isProfileComplete: true,
    hasParentalConsent: true,
    preferredLanguage: 'el',
    classroomIds: ['demo-classroom-1'],
    friends: demoUsers.filter((u) => u.uid !== user.uid).map((u) => u.uid),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('users').doc(user.uid).set(userDoc, {merge: true});
  await db.collection('user_public').doc(user.uid).set({
    uid: user.uid,
    fullName: user.fullName,
    currentClass: user.currentClass,
    profilePictureUrl: null,
    bio: 'Local demo profile',
    achievements: ['Demo Seeded'],
    showBio: true,
    showAchievements: true,
    shareGrades: true,
    preferredLanguage: 'el',
    schoolRole: 'student',
    isProfileComplete: true,
  }, {merge: true});
}

async function seedClassroom() {
  await db.collection('classrooms').doc('demo-classroom-1').set({
    classroomId: 'demo-classroom-1',
    name: 'Demo Classroom',
    classId: 'A-Lykeio-General',
    inviteCode: 'DEMO123',
    adminIds: ['demo-student-1'],
    members: demoUsers.map((u) => u.uid),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function seedLearningData() {
  await db.collection('homework_posts').doc('demo-homework-1').set({
    authorId: 'demo-student-1',
    classId: 'A-Lykeio-General',
    subject: 'Μαθηματικά',
    content: 'Λύσε τις ασκήσεις 1-5 από το κεφάλαιο 2.',
    dueDate: tomorrow,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await db.collection('deadlines').doc('demo-deadline-1').set({
    authorUid: 'demo-student-1',
    classId: 'A-Lykeio-General',
    title: 'Παρουσίαση Ιστορίας',
    description: 'Ομαδική εργασία για την Επανάσταση του 1821.',
    dueDate: tomorrow,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await db.collection('exams').doc('demo-exam-1').set({
    classId: 'A-Lykeio-General',
    subject: 'Φυσική',
    authorUid: 'demo-student-1',
    date: admin.firestore.Timestamp.fromMillis(tomorrow),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function run() {
  console.log(`Seeding emulators with projectId=${projectId}`);
  // Auth emulator often accepts TCP slightly before Admin SDK calls succeed.
  await sleep(3000);
  for (const user of demoUsers) {
    await upsertAuthUser(user);
    await seedUserDocs(user);
  }
  await seedClassroom();
  await seedLearningData();
  console.log('Local emulator seed completed.');
  console.log('Demo login: student@example.com / Passw0rd!');
}

run()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await admin.app().delete();
  });
