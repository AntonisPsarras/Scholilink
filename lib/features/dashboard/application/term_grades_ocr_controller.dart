import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_functions_helpers.dart';
import '../../../core/ai_key_store.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../utils/subject_name_matcher.dart';

class OcrGradeRow {
  final String subjectName;
  final String term;
  final double grade;

  const OcrGradeRow({
    required this.subjectName,
    required this.term,
    required this.grade,
  });
}

class TermGradesOcrState {
  final bool isLoading;
  final String? error;
  final List<OcrGradeRow> rows;
  final List<String> warnings;

  const TermGradesOcrState({
    this.isLoading = false,
    this.error,
    this.rows = const [],
    this.warnings = const [],
  });
}

/// Maps server canonical Greek term strings to the labels used in Firestore/UI.
String? mapTermForFirestore(String termFromServer, bool isGreek) {
  final t = termFromServer.trim();
  if (t == '1ο Τετράμηνο' || t == '1st Term') {
    return isGreek ? '1ο Τετράμηνο' : '1st Term';
  }
  if (t == '2ο Τετράμηνο' || t == '2nd Term') {
    return isGreek ? '2ο Τετράμηνο' : '2nd Term';
  }
  if (t == 'Τελικές Εξετάσεις' || t == 'Final Exams') {
    return isGreek ? 'Τελικές Εξετάσεις' : 'Final Exams';
  }
  return normalizeTermLabel(termFromServer, isGreek);
}

String? resolveSubject(String raw, List<String> availableSubjects) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (availableSubjects.contains(s)) return s;
  return matchBestSubject(s, availableSubjects);
}

class TermGradesOcrController extends StateNotifier<TermGradesOcrState> {
  TermGradesOcrController(this._ref) : super(const TermGradesOcrState());

  final Ref _ref;

  void _applyCallableMetadata(Map<Object?, Object?> data) {
    final next = nextRefreshFromCallableData(data);
    if (next != null) {
      _ref.read(sparkNextResetUtcProvider.notifier).state = next;
    }
  }

  Future<List<OcrGradeRow>> scanReport({
    required Uint8List imageBytes,
    required List<String> availableSubjects,
    required bool isGreek,
  }) async {
    state = const TermGradesOcrState(isLoading: true, error: null);
    try {
      await refreshAuthTokenForCallable();
      final userApiKey = await _ref.read(aiKeyStoreProvider).readGeminiApiKey();
      final response = await chatWithAiCallable().call({
        'mode': 'term_grades_ocr',
        'prompt': isGreek
            ? 'Ανάλυσε τον βαθμολογικό έλεγχο και βγάλε μαθήματα/βαθμούς.'
            : 'Parse this report card and extract subject grades.',
        'isJson': true,
        'images': [base64Encode(imageBytes)],
        'availableSubjects': availableSubjects,
        'history': const <Map<String, dynamic>>[],
        if (userApiKey != null) 'userApiKey': userApiKey,
      });
      final data = response.data is Map
          ? Map<Object?, Object?>.from(response.data as Map)
          : const <Object?, Object?>{};
      _applyCallableMetadata(data);

      final payload = data['data'] is Map
          ? Map<Object?, Object?>.from(data['data'] as Map)
          : const <Object?, Object?>{};
      final rawItems = payload['items'] as List<dynamic>? ?? const [];
      final rows = <OcrGradeRow>[];
      final seen = <String>{};
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = Map<Object?, Object?>.from(item);
        final subjectRaw = (map['subjectName'] as String? ?? '').trim();
        final termRaw = (map['term'] as String? ?? '').trim();
        final gradeNum = (map['grade'] as num?)?.toDouble();
        if (subjectRaw.isEmpty || termRaw.isEmpty || gradeNum == null) {
          continue;
        }
        if (gradeNum < 0 || gradeNum > 20) continue;
        final matchedSubject = resolveSubject(subjectRaw, availableSubjects);
        final normalizedTerm = mapTermForFirestore(termRaw, isGreek);
        if (matchedSubject == null || normalizedTerm == null) continue;
        final key = '$matchedSubject|$normalizedTerm';
        if (seen.contains(key)) continue;
        seen.add(key);
        rows.add(
          OcrGradeRow(
            subjectName: matchedSubject,
            term: normalizedTerm,
            grade: gradeNum,
          ),
        );
      }
      final warnings = (payload['warnings'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      state = TermGradesOcrState(
        isLoading: false,
        rows: rows,
        warnings: warnings,
      );
      return rows;
    } on FirebaseFunctionsException catch (e) {
      final nextReset = nextRefreshFromFunctionsDetails(e.details);
      if (nextReset != null) {
        _ref.read(sparkNextResetUtcProvider.notifier).state = nextReset;
      }
      var msg = (e.message != null && e.message!.trim().isNotEmpty)
          ? e.message!.trim()
          : e.code;
      if (e.code == 'internal') {
        msg = callableInternalErrorUserMessage();
      }
      if (kDebugMode) {
        debugPrint(
          '[term_grades_ocr] FirebaseFunctionsException code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      state = TermGradesOcrState(isLoading: false, error: msg);
      return const [];
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[term_grades_ocr] error=$e\n$st');
      }
      state = TermGradesOcrState(
        isLoading: false,
        error: kDebugMode ? e.toString() : 'Something went wrong. Try again.',
      );
      return const [];
    }
  }
}

final termGradesOcrControllerProvider =
    StateNotifierProvider<TermGradesOcrController, TermGradesOcrState>(
      (ref) => TermGradesOcrController(ref),
    );
