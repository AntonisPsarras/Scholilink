// ignore_for_file: deprecated_member_use
import 'dart:async';

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
import '../../../core/prompts/ai_prompts.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/data/auth_repository.dart';
import '../data/ai_chat_repository.dart';
import '../domain/ai_chat_models.dart';

// Provide a way to track the active session ID
final activeChatSessionIdProvider = StateProvider<String?>((ref) => null);

/// Typing flag isolated from [chatProvider] so UI can rebuild the indicator
/// without reconstructing chrome (sidebar, header, composer).
final chatIsTypingProvider = StateProvider<bool>((ref) => false);

class ChatNotifier extends StateNotifier<List<AIChatMessage>> {
  final Ref _ref;
  final AppUser? _user;
  final AIChatRepository _repository;
  String? _sessionId;
  bool isTyping = false;

  ChatNotifier({
    required Ref ref,
    required AppUser? user,
    required AIChatRepository repository,
    String? sessionId,
  }) : _ref = ref,
       _user = user,
       _repository = repository,
       _sessionId = sessionId,
       super([]) {
    _loadHistory();
  }

  String? get currentSessionId => _sessionId;

  Future<void> loadSession(String? sessionId) async {
    _sessionId = sessionId;
    state = []; // Clear current state while loading
    _setTyping(false);
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final user = _user;
    final sessionId = _sessionId;
    if (user != null && sessionId != null) {
      final savedMessages = await _repository.getMessages(user.uid, sessionId);
      state = savedMessages;
    }
  }

  // Used when starting a fresh chat without a session yet
  void clearChat() {
    _sessionId = null;
    state = [];
    _setTyping(false);
  }

  void _setTyping(bool value) {
    isTyping = value;
    _ref.read(chatIsTypingProvider.notifier).state = value;
  }

  void _dropEmptyStreamingBot(String botId) {
    if (!mounted) return;
    state = [
      for (final m in state)
        if (m.id != botId || m.text.isNotEmpty) m,
    ];
  }

  // Maximum characters accepted per message. Prevents resource-exhaustion via
  // oversized payloads that consume Spark quota and Cloud Function billing.
  static const int _maxPromptLength = 4000;

  Future<String?> sendMessage(
    String text, {
    required void Function(String) onSessionCreated,
    List<Map<String, dynamic>> attachments = const [],
    List<Uint8List> images = const [],
  }) async {
    final trimmed = text.trim();
    if (_user == null) return null;
    if (trimmed.isEmpty && images.isEmpty) return null;

    if (trimmed.length > _maxPromptLength) {
      final lang = _user.preferredLanguage;
      final msg = lang == 'el'
          ? 'Το μήνυμά σου είναι πολύ μεγάλο (μέγιστο $_maxPromptLength χαρακτήρες).'
          : 'Your message is too long (max $_maxPromptLength characters).';
      if (mounted) {
        state = [
          ...state,
          AIChatMessage(
            id: 'error-len-${DateTime.now().millisecondsSinceEpoch}',
            text: msg,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        ];
      }
      return null;
    }

    final effectivePrompt = trimmed.isNotEmpty
        ? trimmed
        : 'Ανάλυσε τις εικόνες που έστειλα.';

    final tempMessage = AIChatMessage(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      text: trimmed,
      isUser: true,
      createdAt: DateTime.now(),
      attachments: attachments,
    );

    if (mounted) {
      state = [...state, tempMessage];
      _setTyping(true);
    }

    final streamId = 'stream-${DateTime.now().millisecondsSinceEpoch}';
    final botId = 'bot-$streamId';
    StreamSubscription<String>? streamSub;

    try {
      String sessionId = _sessionId ?? '';

      if (sessionId.isEmpty) {
        final newSession = await _repository.createSession(
          _user.uid,
          effectivePrompt.length > 30
              ? '${effectivePrompt.substring(0, 27)}...'
              : effectivePrompt,
        );
        sessionId = newSession.id;
        _sessionId = sessionId;
        onSessionCreated(sessionId);
      }

      await _repository.addMessage(
        _user.uid,
        sessionId,
        effectivePrompt,
        true,
        attachments: attachments,
      );

      final userName = _user.fullName.isNotEmpty ? _user.fullName : 'Μαθητής';
      final userClass = _user.currentClass ?? 'Γενική Λυκείου';
      final systemUser = AIPrompts.socraticTutorProfile(userName, userClass);

      final turns = <Map<String, dynamic>>[
        for (final msg in state.where((m) => !m.id.startsWith('temp-')))
          {'text': msg.text, 'isUser': msg.isUser, 'images': const <String>[]},
      ];

      final history = await runAiIsolate(buildStudyBuddyCallableHistory, {
        'systemUser': systemUser,
        'turns': turns,
        'maxTurns': aiCallableMaxHistoryTurns,
      });

      if (mounted) {
        state = [
          ...state,
          AIChatMessage(
            id: botId,
            text: '',
            isUser: false,
            createdAt: DateTime.now(),
          ),
        ];
        streamSub = watchAiStreamChunk(_user.uid, streamId).listen((partial) {
          if (!mounted || partial.isEmpty) return;
          _setTyping(false);
          state = [
            for (final m in state)
              if (m.id == botId)
                AIChatMessage(
                  id: botId,
                  text: partial,
                  isUser: false,
                  createdAt: m.createdAt,
                )
              else
                m,
          ];
        });
      }

      Config.debugLogAiEnvSnapshot('Chat');
      final envErr = Config.firebaseEnvErrorForAiIfAny();
      if (envErr != null) {
        debugPrint('[AI Chat] Not calling Cloud Function: $envErr');
        if (mounted) {
          state = [
            ...state,
            AIChatMessage(
              id: 'error',
              text: envErr,
              isUser: false,
              createdAt: DateTime.now(),
            ),
          ];
        }
        return null;
      }

      await refreshAuthTokenForCallable();
      if (kDebugMode) {
        debugPrint(
          '[AI Chat] pre-call uid=${FirebaseAuth.instance.currentUser?.uid ?? "(null)"}',
        );
      }
      final callable = chatWithAiCallable();
      final userApiKey = await _ref
          .read(aiKeyStoreProvider)
          .readGeminiApiKeyIfEligible(_user.subscriptionType);

      final base64Images = await runAiIsolate(encodeImagesToBase64, images);

      final response = await callable.call({
        'prompt': effectivePrompt,
        'history': history,
        'isJson': false,
        'mode': 'chat',
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

      if (responseText != null) {
        await _repository.addMessage(_user.uid, sessionId, responseText, false);

        if (mounted) {
          final hasBotPlaceholder = state.any((m) => m.id == botId);
          if (hasBotPlaceholder) {
            state = [
              for (final m in state)
                if (m.id == botId)
                  AIChatMessage(
                    id: botId,
                    text: responseText,
                    isUser: false,
                    createdAt: m.createdAt,
                  )
                else
                  m,
            ];
          } else {
            state = [
              ...state,
              AIChatMessage(
                id: botId,
                text: responseText,
                isUser: false,
                createdAt: DateTime.now(),
              ),
            ];
          }
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
          : 'Oops, unable to reach ScholiLink AI right now.';
      if (e.code == 'resource-exhausted') {
        errorMsg = sparkLimitUserMessage(
          preferredLanguage: _user.preferredLanguage,
          nextResetUtc: nextReset,
          subscriptionType: _user.subscriptionType,
        );
      } else if (e.code == 'not-found') {
        errorMsg =
            'User profile not found in database. Try signing out and back in.';
      } else if (e.code == 'unauthenticated') {
        errorMsg = 'You must be signed in to use AI chat.';
      } else if (e.code == 'internal') {
        errorMsg = callableInternalErrorUserMessage();
      }
      debugPrint(
        'AI Chat Error: code=${e.code} message=${e.message} details=${e.details}',
      );
      if (mounted) {
        _dropEmptyStreamingBot(botId);
        state = [
          ...state,
          AIChatMessage(
            id: 'error',
            text: errorMsg,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        ];
      }
      return null;
    } catch (e) {
      String errorMsg = 'Oops, unable to reach ScholiLink AI right now.';
      if (e.toString().contains('resource-exhausted')) {
        errorMsg = sparkLimitUserMessage(
          preferredLanguage: _user.preferredLanguage,
          nextResetUtc: _ref.read(sparkNextResetUtcProvider),
          subscriptionType: _user.subscriptionType,
        );
      }

      if (mounted) {
        _dropEmptyStreamingBot(botId);
        state = [
          ...state,
          AIChatMessage(
            id: 'error',
            text: errorMsg,
            isUser: false,
            createdAt: DateTime.now(),
          ),
        ];
      }
      debugPrint('AI Chat Error: $e');
      return null;
    } finally {
      await streamSub?.cancel();
      try {
        await aiStreamChunkDocRef(_user.uid, streamId).delete();
      } catch (_) {}
      if (mounted) {
        _setTyping(false);
      }
    }
  }
}

// All sessions for the current user
final chatSessionsProvider = StreamProvider.autoDispose<List<AIChatSession>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(aiChatRepositoryProvider).watchSessions(user.uid);
});

// The chat provider is now a singleton that reacts to session changes
final chatProvider = StateNotifierProvider<ChatNotifier, List<AIChatMessage>>((
  ref,
) {
  final user = ref.read(authStateProvider).value;
  final repository = ref.read(aiChatRepositoryProvider);
  final initialSessionId = ref.read(activeChatSessionIdProvider);

  final notifier = ChatNotifier(
    ref: ref,
    user: user,
    repository: repository,
    sessionId: initialSessionId,
  );

  // Listen for external session changes (e.g. from the Drawer)
  ref.listen(activeChatSessionIdProvider, (prev, next) {
    if (next != notifier.currentSessionId) {
      if (next == null) {
        notifier.clearChat();
      } else {
        notifier.loadSession(next);
      }
    }
  });

  return notifier;
});
