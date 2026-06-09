import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase_functions_helpers.dart';
import '../../../core/ai_key_store.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../../auth/data/auth_repository.dart';

String _contentFromPayload(Map<Object?, Object?> p) {
  for (final key in ['content', 'description', 'text', 'homeworkDescription']) {
    final v = p[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  final nested = p['result'];
  if (nested is Map) {
    final r = Map<Object?, Object?>.from(nested);
    for (final key in ['content', 'description', 'text']) {
      final v = r[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  }
  return '';
}

String? _subjectFromPayload(Map<Object?, Object?> p) {
  final v = p['subject'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

class HomeworkOcrResult {
  final String content;
  final String? subject;
  final String homeworkType;
  final int? dueDateOffset;
  final List<String> warnings;

  const HomeworkOcrResult({
    required this.content,
    required this.subject,
    required this.homeworkType,
    required this.dueDateOffset,
    required this.warnings,
  });
}

class HomeworkOcrState {
  final bool isProcessingOcr;
  final String? error;
  final HomeworkOcrResult? result;

  const HomeworkOcrState({
    this.isProcessingOcr = false,
    this.error,
    this.result,
  });

  HomeworkOcrState copyWith({
    bool? isProcessingOcr,
    String? error,
    HomeworkOcrResult? result,
  }) {
    return HomeworkOcrState(
      isProcessingOcr: isProcessingOcr ?? this.isProcessingOcr,
      error: error,
      result: result ?? this.result,
    );
  }
}

class HomeworkOcrController extends StateNotifier<HomeworkOcrState> {
  HomeworkOcrController(this._ref) : super(const HomeworkOcrState());

  final Ref _ref;

  static const Duration _callTimeout = Duration(seconds: 30);

  void reset() {
    state = const HomeworkOcrState();
  }

  String _timeoutMessage() {
    final lang =
        _ref.read(authStateProvider).valueOrNull?.preferredLanguage ?? 'el';
    return lang == 'el'
        ? 'Η επεξεργασία πήρε πολύ χρόνο. Δοκίμασε ξανά.'
        : 'Processing took too long. Please try again.';
  }

  void _applyCallableMetadata(Map<Object?, Object?> data) {
    final next = nextRefreshFromCallableData(data);
    if (next != null) {
      _ref.read(sparkNextResetUtcProvider.notifier).state = next;
    }
  }

  Future<HomeworkOcrResult?> scanImage({
    required Uint8List imageBytes,
    required List<String> availableSubjects,
    required String userHint,
  }) async {
    state = const HomeworkOcrState(isProcessingOcr: true, error: null);
    try {
      await refreshAuthTokenForCallable();
      final userApiKey = await _ref.read(aiKeyStoreProvider).readGeminiApiKey();
      final callable = chatWithAiCallable();
      final response = await callable
          .call({
            'mode': 'homework_ocr',
            'prompt': userHint,
            'isJson': true,
            'images': [base64Encode(imageBytes)],
            'availableSubjects': availableSubjects,
            'history': const <Map<String, dynamic>>[],
            if (userApiKey != null) 'userApiKey': userApiKey,
          })
          .timeout(_callTimeout);
      final data = response.data is Map
          ? Map<Object?, Object?>.from(response.data as Map)
          : const <Object?, Object?>{};
      _applyCallableMetadata(data);

      final payload = data['data'] is Map
          ? Map<Object?, Object?>.from(data['data'] as Map)
          : const <Object?, Object?>{};

      final content = _contentFromPayload(payload);
      final result = HomeworkOcrResult(
        content: content,
        subject: _subjectFromPayload(payload),
        homeworkType: (payload['homeworkType'] as String? ?? 'daily').trim(),
        dueDateOffset: (payload['dueDateOffset'] as num?)?.toInt(),
        warnings: (payload['warnings'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
      );
      if (result.content.isEmpty) {
        state = const HomeworkOcrState(
          isProcessingOcr: false,
          error: 'Δεν εντοπίστηκε καθαρή περιγραφή στην εικόνα.',
        );
        return null;
      }
      state = HomeworkOcrState(isProcessingOcr: false, result: result);
      return result;
    } on TimeoutException {
      final msg = _timeoutMessage();
      state = HomeworkOcrState(isProcessingOcr: false, error: msg);
      return null;
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
          '[homework_ocr] FirebaseFunctionsException code=${e.code} message=${e.message} details=${e.details}',
        );
      }
      state = HomeworkOcrState(isProcessingOcr: false, error: msg);
      return null;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[homework_ocr] error=$e\n$st');
      }
      state = HomeworkOcrState(
        isProcessingOcr: false,
        error: 'Something went wrong. Try again.',
      );
      return null;
    }
  }
}

final homeworkOcrControllerProvider =
    StateNotifierProvider<HomeworkOcrController, HomeworkOcrState>(
      (ref) => HomeworkOcrController(ref),
    );
