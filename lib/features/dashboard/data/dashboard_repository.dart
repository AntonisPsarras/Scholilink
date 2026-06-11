import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import 'personal_homework_merge.dart';
import '../domain/homework_post_model.dart';
import '../domain/exam_model.dart';
import '../domain/deadline_model.dart';
import '../domain/grade_model.dart';
import '../domain/exam_result_model.dart';

abstract class DashboardRepository {
  Future<List<HomeworkPost>> getHomeworkPosts(String classId);
  Future<List<HomeworkPost>> getPersonalHomework(String uid);
  Stream<List<HomeworkPost>> watchPersonalHomework(
    String uid,
    List<String> classroomIds,
  );
  Future<void> addPersonalHomework(String uid, HomeworkPost post);

  /// Creates a document under [personal_homework] with an auto-generated id (returns the id).
  Future<String> createPersonalHomeworkEntry(String uid, HomeworkPost post);
  Future<void> updatePersonalHomeworkEntry(String uid, HomeworkPost post);
  Future<void> deletePersonalHomework(String uid, String postId);

  /// Keeps `deadlines/hwcal_*` in sync for calendar: only [HomeworkPost.homeworkType] `project` with a due date.
  Future<void> syncPersonalHomeworkDeadline(
    String uid,
    String personalHomeworkDocId,
    HomeworkPost post,
  );
  Future<void> removePersonalHomeworkCalendarDeadline(
    String uid,
    String personalHomeworkDocId,
  );
  Future<void> verifyHomework(String postId, String userId);
  Future<void> flagHomework(String postId);
  Future<void> addHomework(HomeworkPost post);
  Future<void> updateHomework(HomeworkPost post);
  Future<void> deleteHomework(String postId);
  Future<List<Map<String, dynamic>>> getSchedule(String classId);
  Future<void> saveSchedule(
    String classId,
    List<Map<String, dynamic>> schedule,
  );
  // Temporary schedules
  Future<List<Map<String, dynamic>>> getActiveSchedule(String classId);
  Future<void> saveTemporarySchedule(
    String classId,
    List<Map<String, dynamic>> schedule,
    DateTime expiresAt,
    String label,
  );
  Future<List<Map<String, dynamic>>> getTemporarySchedules(String classId);
  Future<void> deleteTemporarySchedule(String classId, String scheduleId);
  // Next subject occurrence
  Future<DateTime?> getNextSubjectOccurrence(String classId, String subject);
  Future<List<Exam>> getExams(String classId);
  Future<void> addExam(Exam exam);
  Future<void> deleteExam(String examId);
  Stream<Map<DateTime, List<Map<String, dynamic>>>> watchCalendarEvents(
    String classId,
  );
  // Deadlines (Presentations & Projects)
  Future<List<Deadline>> getDeadlines(String classId);
  Future<void> addDeadline(Deadline deadline);
  Future<void> deleteDeadline(String deadlineId);
  // Grades
  Future<List<GradeRecord>> getGrades(String uid, {String? schoolYear});
  Future<void> addGrade(String uid, GradeRecord grade);
  Future<void> deleteGrade(String uid, String gradeId);
  // Exam Results
  Future<List<ExamResult>> getExamResults(String uid, {String? schoolYear});
  Future<List<String>> getExamResultYears(String uid);
  Future<void> addExamResult(String uid, ExamResult result);
  Future<void> deleteExamResult(String uid, String resultId);
  // Grades by year
  Future<List<String>> getGradeYears(String uid);
  // Homework Completion
  Future<void> toggleHomeworkCompletion(
    String uid,
    String postId,
    bool completed,
  );
  Future<Set<String>> getCompletedHomeworkIds(String uid);
  Stream<Set<String>> watchCompletedHomeworkIds(String uid);
  Future<void> moveToHistory(
    String uid,
    HomeworkPost post,
    String schoolYear, {
    required bool isCompleted,
  });
  Future<List<HomeworkPost>> getHomeworkHistory(String uid, String schoolYear);
  Future<List<HomeworkPost>> getHomeworkDueTomorrow(String classId);
}

/// Stable id for a [deadlines] doc derived from personal homework.
///
/// Includes [uid] because Firestore `.add()` ids are only unique per subcollection;
/// two users could otherwise share the same `personal_homework` doc id and collide
/// on the top-level `deadlines` collection (permission-denied on write).
String calendarDeadlineDocIdFromPersonalHomework(
  String uid,
  String personalHomeworkDocId,
) => 'hwcal_${uid}_$personalHomeworkDocId';

class FirestoreDashboardRepository implements DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<HomeworkPost>> getHomeworkPosts(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('homework_posts')
          .where('classId', isEqualTo: classId)
          .orderBy('dueDate')
          .limit(30)
          .get();

      return snapshot.docs
          .map((doc) => HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  @override
  Stream<List<HomeworkPost>> watchPersonalHomework(
    String uid,
    List<String> classroomIds,
  ) {
    // 1. Personal Homework Stream
    final personalStream = _firestore
        .collection('users')
        .doc(uid)
        .collection('personal_homework')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) =>
                    HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}),
              )
              .toList(),
        );

    // 2. Broadcasted Homework Streams from each classroom
    final classroomStreams = classroomIds.map((classId) {
      return _firestore
          .collection('classrooms')
          .doc(classId)
          .collection('messages')
          .where('type', isEqualTo: 'academic')
          .where('isBroadcasted', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .snapshots()
          .map(
            (snap) => snap.docs
                .where((doc) {
                  final data = doc.data();
                  final disapprovedBy = List<String>.from(
                    data['disapprovedBy'] ?? [],
                  );
                  final authorId = data['authorId'];
                  // Rules:
                  // - Only show if the user hasn't explicitly disapproved it
                  // - Don't show if the user is the author (to avoid duplicates with auto-added logic or if we want strict separation)
                  // - NOTE: Sender Exclusion: authorId != uid ensures it doesn't show up for the person who posted it
                  return !disapprovedBy.contains(uid) && authorId != uid;
                })
                .map((doc) => HomeworkPost.fromChatMessage(doc.data(), doc.id))
                .toList(),
          );
    }).toList();

    // Combine all streams - merge/dedupe/sort off the UI isolate when the
    // merged list is large enough to justify isolate overhead.
    const mergeIsolateThreshold = 24;
    return CombineLatestStream.list<List<HomeworkPost>>([
      personalStream,
      ...classroomStreams,
    ]).asyncMap((lists) async {
      final total = lists.fold<int>(0, (s, l) => s + l.length);
      if (total < mergeIsolateThreshold) {
        return mergeDedupeSortHomeworkPosts(lists);
      }
      final serialized = lists
          .map((list) => list.map((p) => p.toMap()).toList())
          .toList();
      final mergedMaps = await compute(
        mergeDedupeSortHomeworkPostMaps,
        serialized,
      );
      return mergedMaps.map(HomeworkPost.fromMap).toList();
    });
  }

  @override
  Future<List<HomeworkPost>> getPersonalHomework(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('personal_homework')
          .get();

      final posts = snapshot.docs
          .map((doc) => HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();

      // Sort by due date
      posts.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) {
          return b.timestamp.compareTo(a.timestamp);
        }
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      return posts;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> addPersonalHomework(String uid, HomeworkPost post) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('personal_homework')
        .doc(post.postId)
        .set(post.toMap());
  }

  @override
  Future<String> createPersonalHomeworkEntry(
    String uid,
    HomeworkPost post,
  ) async {
    final docRef = await _firestore
        .collection('users')
        .doc(uid)
        .collection('personal_homework')
        .add(post.toMap());
    return docRef.id;
  }

  @override
  Future<void> updatePersonalHomeworkEntry(
    String uid,
    HomeworkPost post,
  ) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('personal_homework')
        .doc(post.postId)
        .set(post.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deletePersonalHomework(String uid, String postId) async {
    // Remove calendar mirror while personal_homework/{postId} still exists (rules may
    // verify ownership via that doc).
    await removePersonalHomeworkCalendarDeadline(uid, postId);
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('personal_homework')
        .doc(postId)
        .delete();
  }

  /// Removes uid-scoped mirror docs and best-effort legacy `hwcal_{postId}` rows for this user.
  Future<void> _deleteHomeworkCalendarMirrorDocs(
    String uid,
    String personalHomeworkDocId,
  ) async {
    final ids = <String>{
      calendarDeadlineDocIdFromPersonalHomework(uid, personalHomeworkDocId),
      'hwcal_$personalHomeworkDocId',
    };
    for (final id in ids) {
      try {
        await _firestore.collection('deadlines').doc(id).delete();
      } on FirebaseException catch (e, st) {
        if (kDebugMode && e.code != 'permission-denied') {
          debugPrint(
            'delete homework calendar mirror ($id): ${e.code} ${e.message}\n$st',
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('delete homework calendar mirror ($id): $e\n$st');
        }
      }
    }
  }

  String _calendarTitleFromHomework(HomeworkPost post) {
    final raw = post.content.trim();
    if (raw.isEmpty) return post.subject;
    final line = raw.split(RegExp(r'\s*\n\s*')).first.trim();
    if (line.length > 80) return '${line.substring(0, 77)}...';
    return line;
  }

  @override
  Future<void> syncPersonalHomeworkDeadline(
    String uid,
    String personalHomeworkDocId,
    HomeworkPost post,
  ) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    final docRef = _firestore
        .collection('deadlines')
        .doc(
          calendarDeadlineDocIdFromPersonalHomework(
            ownerUid,
            personalHomeworkDocId,
          ),
        );

    try {
      if (post.homeworkType != 'project' || post.dueDate == null) {
        await _deleteHomeworkCalendarMirrorDocs(
          ownerUid,
          personalHomeworkDocId,
        );
        return;
      }

      final deadline = Deadline(
        id: docRef.id,
        title: _calendarTitleFromHomework(post),
        subject: post.subject,
        date: post.dueDate!,
        description: post.content,
        classId: post.classId,
        isPresentation: false,
      );

      await docRef.set({
        ...deadline.toMap(),
        'authorUid': ownerUid,
        'sourcePersonalHomeworkId': personalHomeworkDocId,
      });
      // Avoid duplicate calendar rows after upgrading from global `hwcal_{postId}` ids.
      try {
        await _firestore
            .collection('deadlines')
            .doc('hwcal_$personalHomeworkDocId')
            .delete();
      } on FirebaseException catch (e) {
        if (kDebugMode && e.code != 'permission-denied') {
          debugPrint('legacy calendar mirror cleanup: ${e.code} ${e.message}');
        }
      }
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'syncPersonalHomeworkDeadline skipped (${docRef.id}): ${e.code} ${e.message}\n$st',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'syncPersonalHomeworkDeadline skipped (${docRef.id}): $e\n$st',
        );
      }
    }
  }

  @override
  Future<void> removePersonalHomeworkCalendarDeadline(
    String uid,
    String personalHomeworkDocId,
  ) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
    await _deleteHomeworkCalendarMirrorDocs(ownerUid, personalHomeworkDocId);
  }

  @override
  Future<void> verifyHomework(String postId, String userId) async {
    final docRef = _firestore.collection('homework_posts').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final verifiedBy = List<String>.from(data['verifiedBy'] ?? []);

      if (verifiedBy.contains(userId)) return; // Already verified

      verifiedBy.add(userId);
      final isOfficial = verifiedBy.length >= 3;

      transaction.update(docRef, {
        'verifiedBy': verifiedBy,
        'verificationCount': verifiedBy.length,
        'isVerified': isOfficial,
        'isOfficial': isOfficial,
      });
    });
  }

  @override
  Future<void> flagHomework(String postId) async {
    await _firestore.collection('homework_posts').doc(postId).update({
      'flaggedFalse': FieldValue.increment(1),
      'verifiedBy': [],
      'verificationCount': 0,
      'isVerified': false,
      'isOfficial': false,
    });
  }

  @override
  Future<void> addHomework(HomeworkPost post) async {
    await _firestore.collection('homework_posts').add(post.toMap());
  }

  @override
  Future<void> updateHomework(HomeworkPost post) async {
    await _firestore
        .collection('homework_posts')
        .doc(post.postId)
        .update(post.toMap());
  }

  @override
  Future<void> deleteHomework(String postId) async {
    await _firestore.collection('homework_posts').doc(postId).delete();
  }

  String _getSafeDocId(String id) {
    return id.replaceAll('/', '_').replaceAll('\\', '_');
  }

  @override
  Future<List<Map<String, dynamic>>> getSchedule(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schedules')
          .doc(_getSafeDocId(classId))
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['days'] != null) {
          return List<Map<String, dynamic>>.from(data['days']);
        }
      }
      return [];
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<void> saveSchedule(
    String classId,
    List<Map<String, dynamic>> schedule,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('schedules').doc(_getSafeDocId(classId)).set({
      'days': schedule,
      'classId': classId,
      'lastUpdatedByUid': uid,
    }, SetOptions(merge: true));
  }

  // --- Temporary Schedules ---

  @override
  Future<List<Map<String, dynamic>>> getActiveSchedule(String classId) async {
    // Check for a valid (non-expired) temporary schedule first
    final now = DateTime.now();
    try {
      final tempSnap = await _firestore
          .collection('schedules')
          .doc(_getSafeDocId(classId))
          .collection('temporary_schedules')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt')
          .limit(1)
          .get();

      if (tempSnap.docs.isNotEmpty) {
        final data = tempSnap.docs.first.data();
        if (data['days'] != null) {
          return List<Map<String, dynamic>>.from(data['days']);
        }
      }
    } catch (_) {}

    // Fall back to permanent schedule
    return getSchedule(classId);
  }

  @override
  Future<void> saveTemporarySchedule(
    String classId,
    List<Map<String, dynamic>> schedule,
    DateTime expiresAt,
    String label,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('schedules')
        .doc(_getSafeDocId(classId))
        .collection('temporary_schedules')
        .add({
          'days': schedule,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
          'label': label,
          'createdByUid': uid,
        });
  }

  @override
  Future<List<Map<String, dynamic>>> getTemporarySchedules(
    String classId,
  ) async {
    try {
      final snap = await _firestore
          .collection('schedules')
          .doc(_getSafeDocId(classId))
          .collection('temporary_schedules')
          .orderBy('expiresAt')
          .get();
      return snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'label': data['label'] ?? '',
          'expiresAt': (data['expiresAt'] as Timestamp)
              .toDate()
              .millisecondsSinceEpoch,
          'days': data['days'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> deleteTemporarySchedule(
    String classId,
    String scheduleId,
  ) async {
    await _firestore
        .collection('schedules')
        .doc(_getSafeDocId(classId))
        .collection('temporary_schedules')
        .doc(scheduleId)
        .delete();
  }

  @override
  Future<DateTime?> getNextSubjectOccurrence(
    String classId,
    String subject,
  ) async {
    final schedule = await getActiveSchedule(classId);
    if (schedule.isEmpty) return null;

    final now = DateTime.now();
    // Map day names to weekday numbers (DateTime.monday = 1 ... DateTime.friday = 5)
    const dayMap = {
      'Monday': 1,
      'Tuesday': 2,
      'Wednesday': 3,
      'Thursday': 4,
      'Friday': 5,
    };

    // Collect all weekdays that have this subject
    final daysWithSubject = <int>[];
    for (final dayData in schedule) {
      final dayName = dayData['dayName'] as String?;
      final weekday = dayMap[dayName];
      if (weekday == null) continue;
      final classes = List<Map<String, dynamic>>.from(dayData['classes'] ?? []);
      for (final c in classes) {
        final classSubject = c['subject'] as String? ?? '';
        if (classSubject == subject ||
            classSubject.split(' & ').contains(subject)) {
          daysWithSubject.add(weekday);
          break;
        }
      }
    }

    if (daysWithSubject.isEmpty) return null;

    // Find the next occurrence starting from tomorrow
    for (int offset = 1; offset <= 7; offset++) {
      final candidate = now.add(Duration(days: offset));
      if (daysWithSubject.contains(candidate.weekday)) {
        return DateTime(candidate.year, candidate.month, candidate.day);
      }
    }

    return null;
  }

  @override
  Future<List<Exam>> getExams(String classId) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final snapshot = await _firestore
          .collection('exams')
          .where('classId', isEqualTo: classId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => Exam.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<void> addExam(Exam exam) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Cannot add exam: not signed in');
    }
    await _firestore.collection('exams').add({
      ...exam.toMap(),
      'authorUid': uid,
    });
  }

  @override
  Future<void> deleteExam(String examId) async {
    await _firestore.collection('exams').doc(examId).delete();
  }

  Map<DateTime, List<Map<String, dynamic>>> _examSnapshotToCalendarEvents(
    QuerySnapshot<Map<String, dynamic>> examSnap,
  ) {
    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final doc in examSnap.docs) {
      final exam = Exam.fromMap(doc.data(), doc.id);
      final key = DateTime(exam.date.year, exam.date.month, exam.date.day);
      events.putIfAbsent(key, () => []).add({
        'type': 'exam',
        'title': exam.subject,
        'description': exam.description,
        'id': doc.id,
      });
    }
    return events;
  }

  Map<DateTime, List<Map<String, dynamic>>> _deadlineSnapshotToCalendarEvents(
    QuerySnapshot<Map<String, dynamic>> deadlineSnap,
  ) {
    final events = <DateTime, List<Map<String, dynamic>>>{};
    for (final doc in deadlineSnap.docs) {
      final deadline = Deadline.fromMap(doc.data(), doc.id);
      final key = DateTime(
        deadline.date.year,
        deadline.date.month,
        deadline.date.day,
      );
      events.putIfAbsent(key, () => []).add({
        'type': deadline.isPresentation ? 'presentation' : 'project',
        'title': deadline.title,
        'description':
            '${deadline.subject}${deadline.description.isNotEmpty ? ' - ${deadline.description}' : ''}',
        'id': doc.id,
      });
    }
    return events;
  }

  Map<DateTime, List<Map<String, dynamic>>> _mergeCalendarEventMaps(
    Map<DateTime, List<Map<String, dynamic>>> exams,
    Map<DateTime, List<Map<String, dynamic>>> deadlines,
  ) {
    final merged = <DateTime, List<Map<String, dynamic>>>{
      for (final entry in exams.entries) entry.key: List.from(entry.value),
    };
    for (final entry in deadlines.entries) {
      merged.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
    return merged;
  }

  @override
  Stream<Map<DateTime, List<Map<String, dynamic>>>> watchCalendarEvents(
    String classId,
  ) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startTs = Timestamp.fromDate(startOfToday);

    final examStream = _firestore
        .collection('exams')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: startTs)
        .orderBy('date')
        .snapshots()
        .map(_examSnapshotToCalendarEvents);

    final deadlineStream = _firestore
        .collection('deadlines')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: startTs)
        .orderBy('date')
        .snapshots()
        .map(_deadlineSnapshotToCalendarEvents)
        .onErrorReturn(<DateTime, List<Map<String, dynamic>>>{});

    return Rx.combineLatest2(examStream, deadlineStream, _mergeCalendarEventMaps);
  }

  // --- Deadlines ---

  @override
  Future<List<Deadline>> getDeadlines(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('deadlines')
          .where('classId', isEqualTo: classId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 30)),
            ),
          )
          .orderBy('date')
          .get();
      return snapshot.docs
          .map((doc) => Deadline.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') return [];
      rethrow;
    }
  }

  @override
  Future<void> addDeadline(Deadline deadline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Cannot add deadline: not signed in');
    }
    await _firestore.collection('deadlines').add({
      ...deadline.toMap(),
      'authorUid': uid,
    });
  }

  @override
  Future<void> deleteDeadline(String deadlineId) async {
    await _firestore.collection('deadlines').doc(deadlineId).delete();
  }

  // --- Grades ---

  @override
  Future<List<GradeRecord>> getGrades(String uid, {String? schoolYear}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(uid)
          .collection('grades');

      if (schoolYear != null) {
        query = query.where('schoolYear', isEqualTo: schoolYear);
      }

      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => GradeRecord.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<void> addGrade(String uid, GradeRecord grade) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('grades')
        .add(grade.toMap());
  }

  @override
  Future<void> deleteGrade(String uid, String gradeId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('grades')
        .doc(gradeId)
        .delete();
  }

  // --- Exam Results ---

  @override
  Future<List<ExamResult>> getExamResults(
    String uid, {
    String? schoolYear,
  }) async {
    try {
      var query = _firestore
          .collection('users')
          .doc(uid)
          .collection('exam_results')
          .orderBy('date', descending: true);

      final snapshot = await query.get();
      final all = snapshot.docs
          .map((doc) => ExamResult.fromMap(doc.data(), doc.id))
          .toList();

      // Filter by schoolYear if provided
      if (schoolYear != null) {
        return all.where((r) => r.schoolYear == schoolYear).toList();
      }
      return all;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        return [];
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> getExamResultYears(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('exam_results')
          .get();
      final years = snapshot.docs
          .map((doc) => doc.data()['schoolYear'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a)); // Most recent first
      return years;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<String>> getGradeYears(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('grades')
          .get();
      final years = snapshot.docs
          .map((doc) => doc.data()['schoolYear'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      years.sort((a, b) => b.compareTo(a)); // Most recent first
      return years;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> addExamResult(String uid, ExamResult result) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('exam_results')
        .add(result.toMap());
  }

  @override
  Future<void> deleteExamResult(String uid, String resultId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('exam_results')
        .doc(resultId)
        .delete();
  }

  // --- Homework Completion ---

  @override
  Future<void> toggleHomeworkCompletion(
    String uid,
    String postId,
    bool completed,
  ) async {
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('completed_homework')
        .doc(postId);

    if (completed) {
      await ref.set({
        'completedAt': FieldValue.serverTimestamp(),
        'postId': postId,
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Future<Set<String>> getCompletedHomeworkIds(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('completed_homework')
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      return {};
    }
  }

  @override
  Stream<Set<String>> watchCompletedHomeworkIds(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('completed_homework')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<void> moveToHistory(
    String uid,
    HomeworkPost post,
    String schoolYear, {
    required bool isCompleted,
  }) async {
    final batch = _firestore.batch();

    final historyRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('homework_history')
        .doc(schoolYear)
        .collection('items')
        .doc(post.postId);

    final completedRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('completed_homework')
        .doc(post.postId);

    batch.set(historyRef, {
      ...post.toMap(),
      'completedAt': FieldValue.serverTimestamp(),
      'isCompleted': isCompleted,
    });

    batch.set(completedRef, {
      'completedAt': FieldValue.serverTimestamp(),
      'postId': post.postId,
      'isCompleted': isCompleted,
    });

    await batch.commit();
  }

  @override
  Future<List<HomeworkPost>> getHomeworkHistory(
    String uid,
    String schoolYear,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('homework_history')
          .doc(schoolYear)
          .collection('items')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<HomeworkPost>> getHomeworkDueTomorrow(String classId) async {
    final now = DateTime.now();
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
    final tomorrowEnd = DateTime(now.year, now.month, now.day + 2);

    try {
      final snapshot = await _firestore
          .collection('homework_posts')
          .where('classId', isEqualTo: classId)
          .where(
            'dueDate',
            isGreaterThanOrEqualTo: tomorrowStart.millisecondsSinceEpoch,
          )
          .where('dueDate', isLessThan: tomorrowEnd.millisecondsSinceEpoch)
          .get();
      return snapshot.docs
          .map((doc) => HomeworkPost.fromMap({...doc.data(), 'postId': doc.id}))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return FirestoreDashboardRepository();
});

final userExamResultsProvider = FutureProvider.autoDispose
    .family<List<ExamResult>, String>((ref, uid) async {
      return ref.read(dashboardRepositoryProvider).getExamResults(uid);
    });

final userGradesProvider = FutureProvider.autoDispose
    .family<List<GradeRecord>, String>((ref, uid) async {
      return ref.read(dashboardRepositoryProvider).getGrades(uid);
    });
