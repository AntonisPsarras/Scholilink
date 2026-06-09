import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import '../../../shared/web_audio_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/image_utils.dart';
import '../../../shared/storage_service.dart';
import '../../../shared/utils/firebase_error_handler.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../classroom/data/classroom_providers.dart';
import '../../classroom/data/friendship_service.dart';
import '../../dashboard/domain/classroom_model.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/chat_service.dart';
import '../data/chat_providers.dart';
import '../domain/chat_message_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import 'classroom_settings_screen.dart';
import 'create_poll_dialog.dart';
import 'voice_recorder_widget.dart';
import '../data/safety_service.dart';
import '../../../shared/widgets/user_profile_sheet.dart';
import 'widgets/poll_message_bubble.dart';
import 'widgets/chat_message_spacing.dart';
import 'widgets/chat_inline_image.dart';

class ClassroomChatScreen extends ConsumerStatefulWidget {
  final String classroomId;
  final String lang;

  const ClassroomChatScreen({
    super.key,
    required this.classroomId,
    required this.lang,
  });

  @override
  ConsumerState<ClassroomChatScreen> createState() =>
      _ClassroomChatScreenState();
}

class _ClassroomChatScreenState extends ConsumerState<ClassroomChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAcademicMode = false;
  String? _selectedSubject;
  final List<XFile> _pendingImages = [];
  bool _isSending = false;
  bool _showVoiceRecorder = false;
  String? _editingMessageId;
  String? _initialEditText;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final authState = ref.watch(authStateProvider);
    final classroomAsync = ref.watch(selectedClassroomProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final classroom = classroomAsync.valueOrNull;

        return AppTheme.globalGradient(
          child: Scaffold(
            backgroundColor: Colors.transparent, // Global gradient support
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: context.brand.darkText),
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: context.brand.darkText),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classroom?.name ?? s.classroom,
                    style: TextStyle(
                      color: context.brand.darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${classroom?.members.length ?? 0} ${s.members}',
                    style: TextStyle(
                      color: context.brand.neutralGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: context.brand.darkText.withValues(alpha: 0.8),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassroomSettingsScreen(
                        classroomId: widget.classroomId,
                        lang: widget.lang,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                // Messages list
                Expanded(
                  child: Column(
                    children: [
                      // Info bar for editing
                      if (_editingMessageId != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: context.brand.royalLavender.withValues(
                            alpha: 0.1,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit,
                                size: 16,
                                color: context.brand.royalLavender,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.editingMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.brand.royalLavender,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _editingMessageId = null;
                                    _textController.text =
                                        _initialEditText ?? '';
                                    _initialEditText = null;
                                    _textController.clear();
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: context.brand.royalLavender,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _ClassroomMessagesList(
                          classroomId: widget.classroomId,
                          lang: widget.lang,
                          scrollController: _scrollController,
                          user: user,
                          classroom: classroom,
                          onEditMessage: _startEditing,
                        ),
                      ),
                    ],
                  ),
                ),

                // Voice recorder overlay
                if (_showVoiceRecorder)
                  VoiceRecorderWidget(
                    onCancel: () => setState(() => _showVoiceRecorder = false),
                    onSend:
                        (
                          Uint8List bytes,
                          int durationMs,
                          List<double> amplitudes,
                        ) async {
                          setState(() => _showVoiceRecorder = false);
                          try {
                            const ext = kIsWeb ? 'wav' : 'm4a';
                            final voiceUrl = await ref
                                .read(chatServiceProvider)
                                .uploadVoiceBytes(
                                  bytes,
                                  ext: ext,
                                  ownerUid: user.uid,
                                  classroomId: widget.classroomId,
                                );
                            final msg = ChatMessage(
                              id: '',
                              classroomId: widget.classroomId,
                              authorId: user.uid,
                              authorName: user.fullName.isNotEmpty
                                  ? user.fullName
                                  : user.email,
                              authorAvatarUrl: user.profilePictureUrl,
                              type: MessageType.voiceMessage,
                              voiceUrl: voiceUrl,
                              voiceDurationMs: durationMs,
                              voiceAmplitudes: amplitudes,
                              timestamp: DateTime.now(),
                            );
                            await ref
                                .read(chatServiceProvider)
                                .sendMessage(widget.classroomId, msg);
                          } catch (e) {
                            if (!context.mounted) return;
                            CustomSnackBar.show(
                              context: context,
                              message: FirebaseErrorHandler.getMessage(
                                e,
                                widget.lang,
                              ),
                              type: SnackBarType.error,
                            );
                          }
                        },
                  ),

                // Composer bar
                if (!_showVoiceRecorder) _buildMessageInput(s, user),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildMessageInput(S s, dynamic user) {
    final isBanned = ref.read(safetyServiceProvider).isUserBanned(user);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GlassContainer(
      borderRadius:
          0, // It sits at the bottom, so no rounded corners are strictly necessary, or maybe just top.
      blur: 20,
      backgroundColor: dark
          ? context.brand.surfaceElevated.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.3),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle + subject selector
            if (_isAcademicMode)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? cs.surfaceContainerHigh.withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school,
                            size: 14,
                            color: dark ? cs.onSurface : context.brand.darkText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            s.academicMode,
                            style: TextStyle(
                              fontSize: 12,
                              color: dark
                                  ? cs.onSurface
                                  : context.brand.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSubject,
                            isExpanded: true,
                            hint: Text(
                              s.subjectHint,
                              style: TextStyle(
                                fontSize: 13,
                                color: dark
                                    ? cs.onSurfaceVariant
                                    : context.brand.darkText,
                              ),
                            ),
                            dropdownColor: cs.surface,
                            style: TextStyle(
                              fontSize: 13,
                              color: dark
                                  ? cs.onSurface
                                  : context.brand.darkText,
                            ),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: 20,
                              color: dark
                                  ? cs.onSurface
                                  : context.brand.darkText,
                            ),
                            items: (user.subjects as List<dynamic>)
                                .cast<String>()
                                .map((subject) {
                                  return DropdownMenuItem<String>(
                                    value: subject,
                                    child: Text(subject),
                                  );
                                })
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedSubject = val),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Pending images preview
            if (_pendingImages.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: _pendingImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: dark
                                ? cs.surfaceContainerHigh.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: kIsWeb
                              ? Builder(
                                  builder: (context) {
                                    final px =
                                        (70 *
                                                MediaQuery.devicePixelRatioOf(
                                                  context,
                                                ))
                                            .round();
                                    return CachedNetworkImage(
                                      imageUrl: _pendingImages[index].path,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      memCacheWidth: px,
                                      memCacheHeight: px,
                                      maxWidthDiskCache: px,
                                      maxHeightDiskCache: px,
                                      placeholder: (_, __) => Container(
                                        color: dark
                                            ? cs.surfaceContainerHigh
                                                  .withValues(alpha: 0.9)
                                            : Colors.white.withValues(
                                                alpha: 0.4,
                                              ),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        size: 32,
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(_pendingImages[index].path),
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                ),
                        ),
                        Positioned(
                          top: 0,
                          right: 8,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pendingImages.removeAt(index)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.brand.errorRed,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  // Mode toggle
                  if (!isBanned) ...[
                    IconButton(
                      icon: Icon(
                        _isAcademicMode
                            ? Icons.school
                            : Icons.chat_bubble_outline,
                        color: _isAcademicMode
                            ? context.brand.darkText
                            : context.brand.neutralGrey,
                        size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _isAcademicMode = !_isAcademicMode),
                      tooltip: _isAcademicMode
                          ? s.switchToSocial
                          : s.switchToAcademic,
                    ),
                    // Attach image
                    IconButton(
                      icon: Icon(
                        Icons.image_outlined,
                        color: context.brand.neutralGrey,
                        size: 22,
                      ),
                      onPressed: _pickImage,
                      tooltip: s.attachPhoto,
                    ),
                    // Voice
                    IconButton(
                      icon: Icon(
                        Icons.mic_none,
                        color: context.brand.neutralGrey,
                        size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _showVoiceRecorder = true),
                      tooltip: s.voiceMessage,
                    ),
                    // Poll
                    IconButton(
                      icon: Icon(
                        Icons.poll_outlined,
                        color: context.brand.neutralGrey,
                        size: 22,
                      ),
                      onPressed: () => _showCreatePollDialog(user),
                      tooltip: s.createPoll,
                    ),
                  ],
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !isBanned,
                      decoration: InputDecoration(
                        hintText: isBanned
                            ? (s.lang == 'el' ? 'Αποκλεισμένος' : 'Banned')
                            : (_isAcademicMode ? s.subjectHint : s.typeMessage),
                        hintStyle: TextStyle(
                          color: context.brand.neutralGrey,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: context.chatComposerInputFill,
                        isDense: true,
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(user),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: _isSending || isBanned
                          ? (dark
                                ? cs.surfaceContainerHigh
                                : Colors.white.withValues(alpha: 0.3))
                          : (dark
                                ? cs.surfaceContainerHighest
                                : Colors.white.withValues(alpha: 0.8)),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.brand.darkText.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: context.brand.darkText,
                              size: 20,
                            ),
                      onPressed: (_isSending || isBanned)
                          ? null
                          : () => _sendMessage(user),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked != null) {
      if (mounted) setState(() => _pendingImages.add(picked));
    }
  }

  Future<void> _sendMessage(dynamic user) async {
    final s = S(widget.lang);
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;

    if (_editingMessageId != null) {
      await _saveEdit(text);
      return;
    }

    setState(() => _isSending = true);

    try {
      // Upload images in parallel if any (much faster than sequential)
      final storageService = ref.read(storageServiceProvider);
      final List<String> imageUrls;
      if (_pendingImages.isNotEmpty) {
        // Read all image bytes in parallel
        final bytesFutures = _pendingImages
            .map((xf) => xf.readAsBytes())
            .toList();
        final allBytes = await Future.wait(bytesFutures);

        // Upload all images in parallel
        for (final bytes in allBytes) {
          StorageService.ensureWithinUploadLimit(bytes.length);
        }

        final uploadFutures = List.generate(_pendingImages.length, (i) {
          final ext = StorageService.normalizeImageExt(_pendingImages[i].name);
          return storageService.uploadImageBytes(
            allBytes[i],
            'chat_images',
            ext: ext,
            ownerUid: user.uid,
            scopeId: widget.classroomId,
          );
        });
        imageUrls = await Future.wait(uploadFutures);
      } else {
        imageUrls = <String>[];
      }

      DateTime? dueDate;
      if (_isAcademicMode &&
          _selectedSubject != null &&
          _selectedSubject!.isNotEmpty) {
        final repo = ref.read(dashboardRepositoryProvider);
        dueDate = await repo.getNextSubjectOccurrence(
          widget.classroomId,
          _selectedSubject!,
        );
      }

      final msg = ChatMessage(
        id: '',
        classroomId: widget.classroomId,
        authorId: user.uid,
        authorName: user.fullName.isNotEmpty ? user.fullName : user.email,
        authorAvatarUrl: user.profilePictureUrl,
        type: _isAcademicMode ? MessageType.academic : MessageType.social,
        text: text,
        subject: _isAcademicMode ? _selectedSubject : null,
        dueDate: dueDate,
        imageUrls: imageUrls,
        timestamp: DateTime.now(),
      );

      await ref.read(chatServiceProvider).sendMessage(widget.classroomId, msg);

      if (_isAcademicMode && mounted) {
        CustomSnackBar.show(
          context: context,
          message: s.homeworkPosted,
          type: SnackBarType.success,
        );
      }

      _textController.clear();
      setState(() {
        _pendingImages.clear();
        _selectedSubject = null;
      });
    } on FormatException catch (e) {
      if (e.message == 'profanity_detected' && mounted) {
        CustomSnackBar.show(
          context: context,
          message: s.profanityDetected,
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: FirebaseErrorHandler.getMessage(e, widget.lang),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _saveEdit(String nextText) async {
    final s = S(widget.lang);
    setState(() => _isSending = true);
    try {
      await ref
          .read(chatServiceProvider)
          .editMessage(widget.classroomId, _editingMessageId!, nextText);
      _textController.clear();
      setState(() {
        _editingMessageId = null;
        _initialEditText = null;
      });
    } on FormatException catch (e) {
      if (e.message == 'profanity_detected' && mounted) {
        CustomSnackBar.show(
          context: context,
          message: s.profanityDetected,
          type: SnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${s.error}: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startEditing(ChatMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _initialEditText = _textController.text; // Store current text in composer
      _textController.text = message.text;
    });
  }

  void _showCreatePollDialog(dynamic user) {
    showCreatePollDialog(
      context: context,
      classroomId: widget.classroomId,
      userId: user.uid,
      userName: user.fullName.isNotEmpty ? user.fullName : user.email,
      lang: widget.lang,
      ref: ref,
    );
  }
}

/// Watches [chatMessagesProvider] in isolation so the AppBar and composer do not
/// rebuild on every message event.
class _ClassroomMessagesList extends ConsumerWidget {
  final String classroomId;
  final String lang;
  final ScrollController scrollController;
  final AppUser user;
  final Classroom? classroom;
  final void Function(ChatMessage message) onEditMessage;

  const _ClassroomMessagesList({
    required this.classroomId,
    required this.lang,
    required this.scrollController,
    required this.user,
    required this.classroom,
    required this.onEditMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);
    final messagesAsync = ref.watch(chatMessagesProvider(classroomId));
    final limit = ref.watch(chatMessageLimitProvider(classroomId));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: context.brand.neutralGrey.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  s.noMessagesYet,
                  style: TextStyle(color: context.brand.neutralGrey),
                ),
              ],
            ),
          );
        }

        // Show "load older" button when the current batch is exactly full
        // (indicates there may be more messages).
        final mayHaveMore = messages.length >= limit;

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: messages.length + (mayHaveMore ? 1 : 0),
          itemBuilder: (context, index) {
            // The list is reversed, so index == messages.length is visually
            // at the top — show the "load older" button there.
            if (index == messages.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      lang == 'el' ? 'Παλαιότερα μηνύματα' : 'Load older messages',
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () {
                      ref
                          .read(chatMessageLimitProvider(classroomId).notifier)
                          .state += 50;
                    },
                  ),
                ),
              );
            }
            final message = messages[index];
            final messageKey = ValueKey('classroom_${message.id}');
            final isMe = message.authorId == user.uid;
            final isAdminAuthor = classroom?.isAdmin(message.authorId) ?? false;
            final topGap = chatMessageTopPadding(
              newer: message.timestamp,
              older: index < messages.length - 1
                  ? messages[index + 1].timestamp
                  : null,
              newerAuthorId: message.authorId,
              olderAuthorId: index < messages.length - 1
                  ? messages[index + 1].authorId
                  : null,
            );

            if (message.isDeleted) {
              return KeyedSubtree(
                key: messageKey,
                child: chatMessageListGap(
                  topPadding: topGap,
                  child: _DeletedMessageBubble(isMe: isMe, s: s),
                ),
              );
            }

            if (message.type == MessageType.poll && message.pollId != null) {
              return KeyedSubtree(
                key: messageKey,
                child: chatMessageListGap(
                  topPadding: topGap,
                  child: PollMessageBubble(
                    message: message,
                    classroomId: classroomId,
                    userId: user.uid,
                    isMe: isMe,
                    lang: lang,
                  ),
                ),
              );
            }

            if (message.type == MessageType.voiceMessage) {
              return KeyedSubtree(
                key: messageKey,
                child: chatMessageListGap(
                  topPadding: topGap,
                  child: _VoiceMessageBubble(
                    message: message,
                    isMe: isMe,
                    isAdminAuthor: isAdminAuthor,
                    classroomId: classroomId,
                    userId: user.uid,
                    s: s,
                  ),
                ),
              );
            }

            return KeyedSubtree(
              key: messageKey,
              child: chatMessageListGap(
                topPadding: topGap,
                child: _ChatMessageBubble(
                  message: message,
                  isMe: isMe,
                  isAdminAuthor: isAdminAuthor,
                  classroomId: classroomId,
                  userId: user.uid,
                  s: s,
                  onEdit: () => onEditMessage(message),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('${s.error}: $err')),
    );
  }
}

// ─── Chat Bubbles ───

class _ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isAdminAuthor;
  final String classroomId;
  final String userId;
  final S s;
  final VoidCallback onEdit;

  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.isAdminAuthor,
    required this.classroomId,
    required this.userId,
    required this.s,
    required this.onEdit,
  });

  @override
  ConsumerState<_ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<_ChatMessageBubble> {
  // Web: uses WebAudioPlayer (HTMLAudioElement)
  // Native: uses audioplayers AudioPlayer
  dynamic _player; // WebAudioPlayer or AudioPlayer
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  DateTime _lastProgressUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  Duration _totalDuration = Duration.zero;
  final Map<String, Uint8List> _decodedImageBytesCache = {};

  Uint8List _decodedBytesFor(String url) {
    final cached = _decodedImageBytesCache[url];
    if (cached != null) return cached;
    final decoded = Uint8List.fromList(decodeBase64DataUri(url));
    _decodedImageBytesCache[url] = decoded;
    return decoded;
  }

  void _setPlaybackProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressUiUpdate);
    final shouldThrottle =
        elapsed < const Duration(milliseconds: 120) &&
        (clamped - _playbackProgress).abs() < 0.035 &&
        clamped < 0.985;
    if (shouldThrottle) return;
    _lastProgressUiUpdate = now;
    if (mounted) {
      setState(() => _playbackProgress = clamped);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    if (_player != null) {
      if (kIsWeb) {
        (_player as WebAudioPlayer).dispose();
      } else {
        (_player as AudioPlayer).dispose();
      }
    }
    super.dispose();
  }

  Future<void> _togglePlayback(String url) async {
    if (_isPlaying) {
      // Stop playback
      try {
        if (kIsWeb) {
          (_player as WebAudioPlayer).stop();
        } else {
          await (_player as AudioPlayer).stop();
        }
      } catch (e) {
        debugPrint('Stop error: $e');
      }
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      }
      return;
    }

    // Start playback
    final durationMs = widget.message.voiceDurationMs ?? 3000;
    _totalDuration = Duration(milliseconds: durationMs);

    try {
      if (kIsWeb) {
        // Use web-native audio
        _player ??= WebAudioPlayer(
          onProgress: (p) {
            _setPlaybackProgress(p);
          },
          onComplete: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          },
        );
        await (_player as WebAudioPlayer).play(url);
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      } else {
        // Use audioplayers for native
        if (_player == null) {
          _player = AudioPlayer();
          final ap = _player as AudioPlayer;
          _completeSub = ap.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          });
          _positionSub = ap.onPositionChanged.listen((pos) {
            if (mounted && _totalDuration.inMilliseconds > 0) {
              _setPlaybackProgress(
                pos.inMilliseconds / _totalDuration.inMilliseconds,
              );
            }
          });
        }
        await (_player as AudioPlayer).play(UrlSource(url));
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      }
    }
  }

  List<double> _getAmplitudes() {
    const barCount = 28;
    final amps = widget.message.voiceAmplitudes;
    if (amps != null && amps.isNotEmpty) {
      // Resample to barCount
      if (amps.length == barCount) return amps;
      final result = <double>[];
      for (int i = 0; i < barCount; i++) {
        final idx = (i * amps.length / barCount).floor().clamp(
          0,
          amps.length - 1,
        );
        result.add(amps[idx]);
      }
      return result;
    }
    // Fallback: deterministic pseudo-random pattern based on message ID
    final hash = widget.message.id.hashCode;
    return List.generate(barCount, (i) {
      final seed = (hash + i * 7) % 100;
      return 0.15 + (seed / 100) * 0.6;
    });
  }

  void _showUserProfile(BuildContext context, String authorId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileSheet(userId: authorId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final isAdminAuthor = widget.isAdminAuthor;
    final s = widget.s;

    // Voice messages are handled by the dedicated _VoiceMessageBubble widget

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showMessageOptions(context, message, isMe, s),
            child: GlassContainer(
              blur: 0,
              backgroundColor: context.chatBubbleGlassFill(isMe),
              customBorderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author name + admin badge
                    if (!isMe)
                      GestureDetector(
                        onTap: () =>
                            _showUserProfile(context, message.authorId),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.authorName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.9),
                              ),
                            ),
                            if (isAdminAuthor) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.35),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  s.admin,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Academic subject tag
                    if (message.type == MessageType.academic &&
                        message.subject != null &&
                        message.subject!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.subject!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Message text
                    if (message.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],

                    // Edited tag
                    if (message.isEdited && !message.isDeleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          s.edited,
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // Images
                    if (message.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...message.imageUrls.map(
                        (url) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ChatInlineImage(
                            url: url,
                            heroTag: 'img_${message.id}_$url',
                            decodedBytes: isBase64DataUri(url)
                                ? _decodedBytesFor(url)
                                : null,
                            errorLabel: widget.s.lang == 'el'
                                ? 'Σφάλμα φόρτωσης'
                                : 'Error loading',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    imageUrl: url,
                                    heroTag: 'img_${message.id}_$url',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],

                    // Academic mode Verification Buttons (peers only — not the author)
                    if (message.type == MessageType.academic &&
                        message.subject != null &&
                        message.authorId != widget.userId) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _VerificationButton(
                              icon: Icons.check_circle_outline,
                              label: s.lang == 'el' ? 'Επιβεβαίωση' : 'Verify',
                              count: message.verifiedBy.length,
                              isActive: message.verifiedBy.contains(
                                widget.userId,
                              ),
                              color: const Color(
                                0xffa4f5a6,
                              ), // AppTheme.successMint equivalent color
                              onTap: () {
                                ref
                                    .read(chatServiceProvider)
                                    .toggleMessageVerification(
                                      widget.classroomId,
                                      message.id,
                                      widget.userId,
                                      true,
                                    );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _VerificationButton(
                              icon: Icons.cancel_outlined,
                              label: s.lang == 'el' ? 'Απόρριψη' : 'Disapprove',
                              count: message.disapprovedBy.length,
                              isActive: message.disapprovedBy.contains(
                                widget.userId,
                              ),
                              color: context
                                  .brand
                                  .dangerRose, // context.brand.dangerRose
                              onTap: () {
                                ref
                                    .read(chatServiceProvider)
                                    .toggleMessageVerification(
                                      widget.classroomId,
                                      message.id,
                                      widget.userId,
                                      false,
                                    );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Voice message with waveform + playhead
                    if (message.voiceUrl != null &&
                        message.voiceUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      RepaintBoundary(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _isPlaying
                                ? context.brand.royalLavender.withValues(
                                    alpha: 0.12,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _isPlaying
                                  ? context.brand.royalLavender.withValues(
                                      alpha: 0.25,
                                    )
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  // Play/Pause button — large and animated
                                  GestureDetector(
                                    onTap: () =>
                                        _togglePlayback(message.voiceUrl!),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _isPlaying
                                            ? context.brand.royalLavender
                                            : context.brand.royalLavender
                                                  .withValues(alpha: 0.85),
                                        shape: BoxShape.circle,
                                        boxShadow: _isPlaying
                                            ? [
                                                BoxShadow(
                                                  color: context
                                                      .brand
                                                      .royalLavender
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: context
                                                      .brand
                                                      .royalLavender
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                      ),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          key: ValueKey(_isPlaying),
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Waveform with playhead overlay
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final amplitudes = _getAmplitudes();
                                        final totalWidth = constraints.maxWidth;
                                        final playheadX =
                                            _playbackProgress * totalWidth;

                                        return SizedBox(
                                          height: 36,
                                          child: Stack(
                                            alignment: Alignment.centerLeft,
                                            children: [
                                              // Waveform bars
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: List.generate(amplitudes.length, (
                                                  i,
                                                ) {
                                                  final amplitude =
                                                      amplitudes[i];
                                                  final barHeight =
                                                      4.0 + amplitude * 28.0;
                                                  final barProgress =
                                                      (i + 0.5) /
                                                      amplitudes.length;
                                                  final isPlayed =
                                                      _isPlaying &&
                                                      barProgress <=
                                                          _playbackProgress;
                                                  return Expanded(
                                                    child: Center(
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 80,
                                                            ),
                                                        height: barHeight,
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 0.8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isPlayed
                                                              ? context
                                                                    .brand
                                                                    .royalLavender
                                                              : context
                                                                    .brand
                                                                    .neutralGrey
                                                                    .withValues(
                                                                      alpha:
                                                                          0.35,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                2,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                              // Playhead line (only when playing)
                                              if (_isPlaying)
                                                Positioned(
                                                  left: playheadX.clamp(
                                                    0,
                                                    totalWidth - 2,
                                                  ),
                                                  top: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 2.5,
                                                    decoration: BoxDecoration(
                                                      color: context
                                                          .brand
                                                          .royalLavender,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: context
                                                              .brand
                                                              .royalLavender
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              // Playhead dot (circle on top of the line)
                                              if (_isPlaying)
                                                Positioned(
                                                  left: (playheadX - 4).clamp(
                                                    0,
                                                    totalWidth - 8,
                                                  ),
                                                  top: 0,
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: context
                                                          .brand
                                                          .royalLavender,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: context
                                                              .brand
                                                              .royalLavender
                                                              .withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          blurRadius: 3,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              // Duration row below waveform
                              if (message.voiceDurationMs != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 50,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _isPlaying
                                            ? _formatDuration(
                                                (_playbackProgress *
                                                        message
                                                            .voiceDurationMs!)
                                                    .toInt(),
                                              )
                                            : _formatDuration(
                                                message.voiceDurationMs!,
                                              ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _isPlaying
                                              ? context.brand.royalLavender
                                              : context.brand.neutralGrey,
                                          fontWeight: _isPlaying
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      if (_isPlaying) ...[
                                        Text(
                                          ' / ${_formatDuration(message.voiceDurationMs!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.brand.neutralGrey,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Timestamp below the message bubble
          const SizedBox(height: 6),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: context.brand.darkText.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    S s,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: 24,
          backgroundColor: Colors.white.withValues(
            alpha: 0.9,
          ), // Higher opacity for readability
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.brand.neutralGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (message.type == MessageType.voiceMessage ||
                  (message.voiceUrl != null && message.voiceUrl!.isNotEmpty))
                ListTile(
                  leading: Icon(
                    Icons.volume_up_outlined,
                    color: context.brand.darkText,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Ακρόαση' : 'Listen',
                    style: TextStyle(
                      color: context.brand.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _togglePlayback(message.voiceUrl!);
                  },
                ),
              if (isMe) ...[
                ListTile(
                  leading: Icon(
                    Icons.edit_outlined,
                    color: context.brand.darkText,
                  ),
                  title: Text(
                    s.edit,
                    style: TextStyle(
                      color: context.brand.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onEdit();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.brand.errorRed,
                  ),
                  title: Text(
                    s.delete,
                    style: TextStyle(
                      color: context.brand.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(message.id);
                  },
                ),
              ],
              if (!isMe)
                ListTile(
                  leading: Icon(
                    Icons.report_outlined,
                    color: context.brand.sunsetWarning,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Αναφορά' : 'Report',
                    style: TextStyle(
                      color: context.brand.sunsetWarning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportMessage(message);
                  },
                ),
              if (!isMe)
                ListTile(
                  leading: Icon(
                    Icons.block_outlined,
                    color: context.brand.dangerRose,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Αποκλεισμός' : 'Block',
                    style: TextStyle(color: context.brand.dangerRose),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _blockUser(message.authorId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await ref
          .read(chatServiceProvider)
          .deleteMessage(widget.classroomId, messageId);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Delete failed: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    try {
      await ref
          .read(chatServiceProvider)
          .reportMessage(
            messageId: message.id,
            reporterId: widget.userId,
            reportedUserId: message.authorId,
            messageText: message.text,
            contextId: widget.classroomId,
            contextType: 'classroom',
            reason: 'User reported in classroom',
          );
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.s.reportedSuccessfully,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${widget.s.reportFailed}: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _blockUser(String userId) async {
    try {
      await ref.read(authRepositoryProvider).blockUser(userId);
      await ref
          .read(friendshipServiceProvider)
          .removeFriend(widget.userId, userId);
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.s.userBlocked,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${widget.s.error}: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _DeletedMessageBubble extends StatelessWidget {
  final bool isMe;
  final S s;
  const _DeletedMessageBubble({required this.isMe, required this.s});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        borderRadius: 16,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 14, color: context.brand.neutralGrey),
            const SizedBox(width: 4),
            Text(
              s.messageDeleted,
              style: TextStyle(
                color: context.brand.neutralGrey,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Message Bubble ───

class _VoiceMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isAdminAuthor;
  final String classroomId;
  final String userId;
  final S s;

  const _VoiceMessageBubble({
    required this.message,
    required this.isMe,
    required this.isAdminAuthor,
    required this.classroomId,
    required this.userId,
    required this.s,
  });

  @override
  ConsumerState<_VoiceMessageBubble> createState() =>
      _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<_VoiceMessageBubble> {
  dynamic _player;
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  DateTime _lastProgressUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  Duration _totalDuration = Duration.zero;

  void _setPlaybackProgress(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressUiUpdate);
    final shouldThrottle =
        elapsed < const Duration(milliseconds: 120) &&
        (clamped - _playbackProgress).abs() < 0.035 &&
        clamped < 0.985;
    if (shouldThrottle) return;
    _lastProgressUiUpdate = now;
    if (mounted) {
      setState(() => _playbackProgress = clamped);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _completeSub?.cancel();
    if (_player != null) {
      if (kIsWeb) {
        (_player as WebAudioPlayer).dispose();
      } else {
        (_player as AudioPlayer).dispose();
      }
    }
    super.dispose();
  }

  Future<void> _togglePlayback(String url) async {
    if (_isPlaying) {
      try {
        if (kIsWeb) {
          (_player as WebAudioPlayer).stop();
        } else {
          await (_player as AudioPlayer).stop();
        }
      } catch (e) {
        debugPrint('Stop error: $e');
      }
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      }
      return;
    }

    final durationMs = widget.message.voiceDurationMs ?? 3000;
    _totalDuration = Duration(milliseconds: durationMs);

    try {
      if (kIsWeb) {
        _player ??= WebAudioPlayer(
          onProgress: (p) {
            _setPlaybackProgress(p);
          },
          onComplete: () {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          },
        );
        await (_player as WebAudioPlayer).play(url);
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      } else {
        if (_player == null) {
          _player = AudioPlayer();
          final ap = _player as AudioPlayer;
          _completeSub = ap.onPlayerComplete.listen((_) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _playbackProgress = 0.0;
              });
            }
          });
          _positionSub = ap.onPositionChanged.listen((pos) {
            if (mounted && _totalDuration.inMilliseconds > 0) {
              _setPlaybackProgress(
                pos.inMilliseconds / _totalDuration.inMilliseconds,
              );
            }
          });
        }
        await (_player as AudioPlayer).play(UrlSource(url));
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint('Playback error: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
        });
      }
    }
  }

  List<double> _getAmplitudes() {
    const barCount = 28;
    final amps = widget.message.voiceAmplitudes;
    if (amps != null && amps.isNotEmpty) {
      if (amps.length == barCount) return amps;
      final result = <double>[];
      for (int i = 0; i < barCount; i++) {
        final idx = (i * amps.length / barCount).floor().clamp(
          0,
          amps.length - 1,
        );
        result.add(amps[idx]);
      }
      return result;
    }
    final hash = widget.message.id.hashCode;
    return List.generate(barCount, (i) {
      final seed = (hash + i * 7) % 100;
      return 0.15 + (seed / 100) * 0.6;
    });
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;
    final isAdminAuthor = widget.isAdminAuthor;
    final durationMs = message.voiceDurationMs ?? 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () =>
                  _showMessageOptions(context, message, isMe, widget.s),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                  colors: isMe
                      ? [
                          context.brand.royalLavender.withValues(alpha: 0.18),
                          context.brand.royalLavender.withValues(alpha: 0.08),
                        ]
                      : dark
                      ? [const Color(0xFF2A2A3D), context.brand.surfaceElevated]
                      : [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.6),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 20),
                ),
                border: Border.all(
                  color: _isPlaying
                      ? context.brand.royalLavender.withValues(alpha: 0.35)
                      : dark
                      ? cs.outline.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPlaying
                        ? context.brand.royalLavender.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: _isPlaying ? 16 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author name (for others' messages)
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.authorName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                          if (isAdminAuthor) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: cs.outline.withValues(alpha: 0.35),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                widget.s.admin,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Voice player row
                  Row(
                    children: [
                      // Play/Pause button
                      GestureDetector(
                        onTap: () => _togglePlayback(message.voiceUrl ?? ''),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isPlaying
                                ? context.brand.royalLavender
                                : (isMe
                                      ? context.brand.royalLavender.withValues(
                                          alpha: 0.85,
                                        )
                                      : context.brand.royalLavender.withValues(
                                          alpha: 0.8,
                                        )),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: context.brand.royalLavender.withValues(
                                  alpha: _isPlaying ? 0.45 : 0.2,
                                ),
                                blurRadius: _isPlaying ? 14 : 6,
                                spreadRadius: _isPlaying ? 1 : 0,
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(_isPlaying),
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Waveform + duration
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Waveform
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final amplitudes = _getAmplitudes();
                                final totalWidth = constraints.maxWidth;
                                final playheadX =
                                    _playbackProgress * totalWidth;

                                return SizedBox(
                                  height: 32,
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      // Bars
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: List.generate(
                                          amplitudes.length,
                                          (i) {
                                            final amplitude = amplitudes[i];
                                            final barHeight =
                                                4.0 + amplitude * 24.0;
                                            final barProgress =
                                                (i + 0.5) / amplitudes.length;
                                            final isPlayed =
                                                _isPlaying &&
                                                barProgress <=
                                                    _playbackProgress;
                                            return Expanded(
                                              child: Center(
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 80,
                                                  ),
                                                  height: barHeight,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 0.8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isPlayed
                                                        ? context
                                                              .brand
                                                              .royalLavender
                                                        : (isMe
                                                              ? context
                                                                    .brand
                                                                    .royalLavender
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    )
                                                              : context
                                                                    .brand
                                                                    .neutralGrey
                                                                    .withValues(
                                                                      alpha:
                                                                          0.35,
                                                                    )),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          100,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Playhead
                                      if (_isPlaying)
                                        Positioned(
                                          left: playheadX.clamp(
                                            0,
                                            totalWidth - 2,
                                          ),
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 2,
                                            decoration: BoxDecoration(
                                              color:
                                                  context.brand.royalLavender,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: context
                                                      .brand
                                                      .royalLavender
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            // Duration row
                            Row(
                              children: [
                                Text(
                                  _isPlaying
                                      ? _formatDuration(
                                          (_playbackProgress * durationMs)
                                              .toInt(),
                                        )
                                      : _formatDuration(durationMs),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isPlaying
                                        ? context.brand.royalLavender
                                        : context.brand.neutralGrey,
                                    fontWeight: _isPlaying
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Text(
                                  ' / ${_formatDuration(durationMs)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.brand.neutralGrey,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.mic,
                                  size: 13,
                                  color: _isPlaying
                                      ? context.brand.royalLavender.withValues(
                                          alpha: 0.6,
                                        )
                                      : context.brand.neutralGrey.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _isPlaying ? 'Playing...' : 'Voice message',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _isPlaying
                                        ? context.brand.royalLavender
                                        : context.brand.neutralGrey,
                                    fontWeight: _isPlaying
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  message.voiceDurationMs != null
                                      ? '${(message.voiceDurationMs! / 1000).toStringAsFixed(1)}s'
                                      : '',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.brand.neutralGrey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Timestamp below the bubble
          const SizedBox(height: 4),
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: context.brand.darkText.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    ),  // Align
    );  // RepaintBoundary
  }

  void _showMessageOptions(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    S s,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.brand.neutralGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isMe || widget.isAdminAuthor)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.brand.errorRed,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Διαγραφή Μηνύματος' : 'Delete Message',
                    style: TextStyle(
                      color: context.brand.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(message.id);
                  },
                ),
              if (!isMe) ...[
                ListTile(
                  leading: Icon(
                    Icons.report_outlined,
                    color: context.brand.sunsetWarning,
                  ),
                  title: Text(
                    widget.s.lang == 'el'
                        ? 'Αναφορά Μηνύματος'
                        : 'Report Message',
                    style: TextStyle(
                      color: context.brand.sunsetWarning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportMessage(message);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.block_outlined,
                    color: context.brand.errorRed,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Αποκλεισμός Χρήστη' : 'Block User',
                    style: TextStyle(
                      color: context.brand.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _blockUser(message.authorId);
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _deleteMessage(String messageId) async {
    try {
      await ref
          .read(chatServiceProvider)
          .deleteMessage(widget.classroomId, messageId);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error deleting message: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _reportMessage(ChatMessage message) async {
    try {
      await ref
          .read(chatServiceProvider)
          .reportMessage(
            reporterId: widget.userId,
            reportedUserId: message.authorId,
            messageId: message.id,
            contextId: widget.classroomId,
            contextType: 'classroom',
            messageText: message.text,
            reason: 'Inappropriate content',
          );
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.s.reportedSuccessfully,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${widget.s.reportFailed}: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _blockUser(String authorId) async {
    try {
      await ref.read(authRepositoryProvider).blockUser(authorId);
      await ref
          .read(friendshipServiceProvider)
          .removeFriend(widget.userId, authorId);
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.s.userBlocked,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: '${widget.s.error}: $e',
          type: SnackBarType.error,
        );
      }
    }
  }
}

class _VerificationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _VerificationButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 360;
    final inactiveBg = dark
        ? cs.surfaceContainerHigh.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.5);
    final inactiveFg = dark ? Colors.white : context.brand.neutralGrey;
    final countLabel = count > 99 ? '99+' : '$count';
    final buttonLabel = count > 0 ? '$label ($countLabel)' : label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 6,
          horizontal: isNarrow ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: dark ? 0.32 : 0.15)
              : inactiveBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? color
                : (dark
                      ? cs.outline.withValues(alpha: 0.35)
                      : context.brand.neutralGrey.withValues(alpha: 0.2)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isActive ? color : inactiveFg),
            SizedBox(width: isNarrow ? 3 : 4),
            Flexible(
              child: Text(
                buttonLabel,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? color : inactiveFg,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
