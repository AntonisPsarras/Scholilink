import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/config.dart';
import '../../../core/firebase_functions_helpers.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../../../core/ai_background_work.dart';
import '../../../core/ai_key_store.dart';
import '../../auth/data/auth_repository.dart';
import '../data/smart_notes_repository.dart';
import '../domain/smart_notes_models.dart';

final activeNoteSessionIdProvider = StateProvider<String?>((ref) => null);

class SmartNotesState {
  final List<SmartNoteInteraction> interactions;
  final bool isLoading;
  final String? error;

  SmartNotesState({
    this.interactions = const [],
    this.isLoading = false,
    this.error,
  });

  SmartNotesState copyWith({
    List<SmartNoteInteraction>? interactions,
    bool? isLoading,
    String? error,
  }) {
    return SmartNotesState(
      interactions: interactions ?? this.interactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SmartNotesNotifier extends StateNotifier<SmartNotesState> {
  final Ref _ref;
  final SmartNotesRepository _repository;
  final String? _userId;
  final String? _preferredLanguage;
  final String? _subscriptionType;
  String? _sessionId;

  SmartNotesNotifier({
    required Ref ref,
    required SmartNotesRepository repository,
    required String? userId,
    String? sessionId,
    String? preferredLanguage,
    String? subscriptionType,
  }) : _ref = ref,
       _repository = repository,
       _userId = userId,
       _preferredLanguage = preferredLanguage,
       _subscriptionType = subscriptionType,
       _sessionId = sessionId,
       super(SmartNotesState()) {
    _init();
  }

  String? get currentSessionId => _sessionId;

  Future<void> loadSession(String? sessionId) async {
    _sessionId = sessionId;
    state = SmartNotesState(isLoading: true);
    await _init();
  }

  void clearSession() {
    _sessionId = null;
    state = SmartNotesState();
    _init();
  }

  Future<void> _init() async {
    final userId = _userId;
    final sessionId = _sessionId;
    if (userId == null || sessionId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final interactions = await _repository.getInteractions(userId, sessionId);
      state = state.copyWith(interactions: interactions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Maximum characters accepted per prompt. Prevents resource-exhaustion via
  // oversized payloads that consume Spark quota and Cloud Function billing.
  static const int _maxPromptLength = 4000;

  Future<String?> processPrompt(
    String prompt, {
    List<Uint8List>? images,
    List<Map<String, dynamic>> attachments = const [],
    String lengthOption = 'short',
    String depthOption = 'basic',
    required void Function(String) onSessionCreated,
  }) async {
    if (_userId == null) return null;
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty && (images == null || images.isEmpty)) {
      return null;
    }

    if (trimmedPrompt.length > _maxPromptLength) {
      final msg = _preferredLanguage == 'el'
          ? 'Το κείμενό σου είναι πολύ μεγάλο (μέγιστο $_maxPromptLength χαρακτήρες).'
          : 'Your prompt is too long (max $_maxPromptLength characters).';
      if (mounted) {
        state = state.copyWith(isLoading: false, error: msg);
      }
      return null;
    }

    final effectivePrompt = trimmedPrompt.isNotEmpty
        ? trimmedPrompt
        : 'Δημιούργησε σημειώσεις από τις εικόνες που έστειλα.';

    if (mounted) {
      state = state.copyWith(isLoading: true, error: null);
    }

    final streamId = 'stream-${DateTime.now().millisecondsSinceEpoch}';

    try {
      String sessionId = _sessionId ?? '';
      if (sessionId.isEmpty) {
        final newSession = await _repository.createSession(
          _userId,
          effectivePrompt.length > 30
              ? '${effectivePrompt.substring(0, 27)}...'
              : effectivePrompt,
        );
        sessionId = newSession.id;
        _sessionId = sessionId; // Update internally
        onSessionCreated(sessionId); // Notify UI
      }

      final historyItems = <Map<String, dynamic>>[
        for (final inter in state.interactions)
          {
            'prompt': inter.prompt,
            'cardTitles': inter.cards.map((c) => c.title).toList(),
          },
      ];

      final history = await runAiIsolate(buildSmartNotesCallableHistory, {
        'items': historyItems,
        'maxTurns': aiCallableMaxHistoryTurns,
      });

      Config.debugLogAiEnvSnapshot('SmartNotes');
      final envErr = Config.firebaseEnvErrorForAiIfAny();
      if (envErr != null) {
        debugPrint('[AI SmartNotes] Not calling Cloud Function: $envErr');
        if (mounted) {
          state = state.copyWith(isLoading: false, error: envErr);
        }
        return null;
      }

      await refreshAuthTokenForCallable();
      if (kDebugMode) {
        debugPrint(
          '[AI SmartNotes] pre-call uid=${FirebaseAuth.instance.currentUser?.uid ?? "(null)"}',
        );
      }
      final callable = chatWithAiCallable();
      final userApiKey = await _ref
          .read(aiKeyStoreProvider)
          .readGeminiApiKeyIfEligible(_subscriptionType);

      final base64Images = await runAiIsolate(
        encodeImagesToBase64,
        images ?? <Uint8List>[],
      );

      final response = await callable.call({
        'prompt': effectivePrompt,
        'history': history,
        'isJson': true,
        'mode': 'smart_notes',
        'length': lengthOption,
        'depth': depthOption,
        'images': base64Images,
        'streamId': streamId,
        if (userApiKey != null) 'userApiKey': userApiKey,
      });

      final dataMap = response.data is Map
          ? Map<Object?, Object?>.from(response.data as Map)
          : null;
      final nextFromOk = nextRefreshFromCallableData(dataMap);
      if (nextFromOk != null) {
        _ref.read(sparkNextResetUtcProvider.notifier).state = nextFromOk;
      }

      final responseText = dataMap?['text'] as String?;
      final sparkCost = (dataMap?['sparkCost'] as num?)?.toInt() ?? 1;
      if (responseText != null) {
        final cardMaps = await runAiIsolate(
          decodeSmartNotesAiResponseJson,
          responseText,
        );
        var newCards = cardMaps.map(SmartNoteCard.fromMap).toList();
        if (lengthOption == 'long' && newCards.length > 1) {
          final first = newCards.first;
          final mergedContent = newCards
              .map((c) => c.content.trim())
              .where((c) => c.isNotEmpty)
              .join('\n\n');
          final mergedBullets = <String>[
            for (final c in newCards) ...c.bulletPoints,
          ];
          newCards = [
            SmartNoteCard(
              title: first.title,
              content: mergedContent.isNotEmpty ? mergedContent : first.content,
              bulletPoints: mergedBullets,
            ),
          ];
        }

        await _repository.addInteraction(
          _userId,
          sessionId,
          effectivePrompt,
          newCards,
          attachments: attachments,
          lengthOption: lengthOption,
          depthOption: depthOption,
          sparkCostUsed: sparkCost,
        );

        final newInteraction = SmartNoteInteraction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          prompt: effectivePrompt,
          cards: newCards,
          createdAt: DateTime.now(),
          attachments: attachments,
          lengthOption: lengthOption,
          depthOption: depthOption,
          sparkCostUsed: sparkCost,
        );

        if (mounted) {
          state = state.copyWith(
            interactions: [...state.interactions, newInteraction],
            isLoading: false,
          );
        }
        return sessionId;
      }
      return sessionId;
    } on FirebaseFunctionsException catch (e) {
      final nextReset = nextRefreshFromFunctionsDetails(e.details);
      if (nextReset != null) {
        _ref.read(sparkNextResetUtcProvider.notifier).state = nextReset;
      }
      final rawMessage = e.message;
      String errorMsg = (rawMessage != null && rawMessage.trim().isNotEmpty)
          ? rawMessage.trim()
          : 'Σφάλμα AI.';
      if (e.code == 'resource-exhausted') {
        errorMsg = sparkLimitUserMessage(
          preferredLanguage: _preferredLanguage,
          nextResetUtc: nextReset,
          subscriptionType: _subscriptionType,
        );
      } else if (e.code == 'internal') {
        errorMsg = callableInternalErrorUserMessage();
      }
      debugPrint(
        'Smart notes AI: code=${e.code} message=${e.message} details=${e.details}',
      );
      if (mounted) {
        state = state.copyWith(isLoading: false, error: errorMsg);
      }
      return null;
    } catch (e) {
      // Do not expose raw exception details to the UI — they can leak internal
      // Firestore paths, function names, or partial credential strings.
      debugPrint('Smart notes AI (unexpected): $e');
      String errorMsg = _preferredLanguage == 'el'
          ? 'Κάτι πήγε στραβά. Παρακαλώ δοκίμασε ξανά.'
          : 'Something went wrong. Please try again.';
      if (e.toString().contains('resource-exhausted')) {
        errorMsg = sparkLimitUserMessage(
          preferredLanguage: _preferredLanguage,
          nextResetUtc: _ref.read(sparkNextResetUtcProvider),
          subscriptionType: _subscriptionType,
        );
      }
      if (mounted) {
        state = state.copyWith(isLoading: false, error: errorMsg);
      }
      return null;
    } finally {
      try {
        await aiStreamChunkDocRef(_userId, streamId).delete();
      } catch (_) {}
    }
  }
}

final smartNotesSessionsProvider =
    StreamProvider.autoDispose<List<SmartNoteSession>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value([]);
      return ref.watch(smartNotesRepositoryProvider).watchSessions(user.uid);
    });

final smartNotesProvider =
    StateNotifierProvider<SmartNotesNotifier, SmartNotesState>((ref) {
      final repository = ref.read(smartNotesRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final initialSessionId = ref.read(activeNoteSessionIdProvider);

      final notifier = SmartNotesNotifier(
        ref: ref,
        repository: repository,
        userId: user?.uid,
        sessionId: initialSessionId,
        preferredLanguage: user?.preferredLanguage,
        subscriptionType: user?.subscriptionType,
      );

      // Listen for external session changes
      ref.listen(activeNoteSessionIdProvider, (prev, next) {
        if (next != notifier.currentSessionId) {
          if (next == null) {
            notifier.clearSession();
          } else {
            notifier.loadSession(next);
          }
        }
      });

      return notifier;
    });
