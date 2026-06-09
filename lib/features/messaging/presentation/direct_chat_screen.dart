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
import 'package:intl/intl.dart';
import '../../../shared/image_utils.dart';
import '../../../shared/storage_service.dart';
import '../../../shared/utils/firebase_error_handler.dart';
import '../../auth/data/auth_repository.dart';
import '../data/direct_message_service.dart';
import '../../classroom/data/friendship_service.dart';
import '../data/safety_service.dart';
import '../domain/direct_chat_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import 'voice_recorder_widget.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/user_profile_sheet.dart';
import 'widgets/chat_message_spacing.dart';
import 'widgets/chat_inline_image.dart';

String _directChatDateDividerLabel(DateTime timestamp, String lang) {
  final d = timestamp.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(d.year, d.month, d.day);
  if (msgDay == today) {
    return lang == 'el' ? 'Σήμερα' : 'Today';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (msgDay == yesterday) {
    return lang == 'el' ? 'Χθες' : 'Yesterday';
  }
  if (lang == 'el') {
    const months = <String>[
      '',
      'Ιανουαρίου',
      'Φεβρουαρίου',
      'Μαρτίου',
      'Απριλίου',
      'Μαΐου',
      'Ιουνίου',
      'Ιουλίου',
      'Αυγούστου',
      'Σεπτεμβρίου',
      'Οκτωβρίου',
      'Νοεμβρίου',
      'Δεκεμβρίου',
    ];
    final m = months[d.month];
    if (d.year == today.year) {
      return '${d.day} $m';
    }
    return '${d.day} $m ${d.year}';
  }
  return DateFormat.yMMMMd().format(d);
}

class DirectChatScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String currentUserId;
  final String friendName;
  final String? friendAvatar;
  final String lang;

  const DirectChatScreen({
    super.key,
    required this.friendId,
    required this.currentUserId,
    required this.friendName,
    this.friendAvatar,
    required this.lang,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isAcademicMode = false;
  String? _selectedSubject;
  final List<XFile> _pendingImages = [];
  bool _isSending = false;
  bool _showVoiceRecorder = false;
  String? _editingMessageId;
  String? _initialEditText;

  String? _chatId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      final chatId = await ref
          .read(directMessageServiceProvider)
          .getOrCreateDirectChat(widget.currentUserId, widget.friendId);
      if (mounted) {
        setState(() {
          _chatId = chatId;
          _isLoading = false;
        });
        // Mark as read when entering
        await ref
            .read(directMessageServiceProvider)
            .markAsRead(chatId, widget.currentUserId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
          context: context,
          message: 'Error initializing chat: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showUserProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileSheet(userId: widget.friendId),
    );
  }

  Future<void> _showChatActions() async {
    if (!mounted) return;
    final s = S(widget.lang);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: 24,
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.9),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.brand.errorRed,
              ),
              title: Text(
                s.lang == 'el' ? 'Αφαίρεση από φίλους' : 'Remove from friends',
                style: TextStyle(
                  color: context.brand.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'remove_friend'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_sweep_outlined,
                color: context.brand.sunsetWarning,
              ),
              title: Text(
                s.lang == 'el'
                    ? 'Διαγραφή συνομιλίας (μόνο μηνύματα)'
                    : 'Clear conversation (messages only)',
                style: TextStyle(
                  color: context.brand.sunsetWarning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, 'clear_chat'),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'block') {
      await _blockUser(widget.friendId);
      return;
    }
    if (action == 'remove_friend') {
      await _removeFriend();
      return;
    }
    if (action == 'clear_chat') {
      await _clearConversation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return AppTheme.globalGradient(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: context.brand.darkText),
              title: InkWell(
                onTap: _showUserProfile,
                child: Row(
                  children: [
                    UserAvatar(
                      profilePictureUrl: widget.friendAvatar,
                      fullName: widget.friendName,
                      radius: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.friendName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.brand.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.more_vert, color: context.brand.darkText),
                  tooltip: s.lang == 'el'
                      ? 'Ενέργειες συνομιλίας'
                      : 'Chat actions',
                  onPressed: _showChatActions,
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chatId == null
                ? Center(child: Text(s.error))
                : Column(
                    children: [
                      Expanded(
                        child: _MessagesList(
                          chatId: _chatId!,
                          currentUserId: widget.currentUserId,
                          scrollController: _scrollController,
                          lang: widget.lang,
                          onEdit: _startEditing,
                        ),
                      ),
                      // Voice recorder overlay
                      if (_showVoiceRecorder)
                        VoiceRecorderWidget(
                          onCancel: () =>
                              setState(() => _showVoiceRecorder = false),
                          onSend:
                              (
                                Uint8List bytes,
                                int durationMs,
                                List<double> amplitudes,
                              ) async {
                                setState(() => _showVoiceRecorder = false);
                                try {
                                  const ext = kIsWeb ? 'wav' : 'm4a';
                                  final storageService = ref.read(
                                    storageServiceProvider,
                                  );
                                  final voiceUrl = await storageService
                                      .uploadVoiceBytes(
                                        bytes,
                                        'direct_chat_voice',
                                        ext: ext,
                                        ownerUid: widget.currentUserId,
                                        scopeId: _chatId!,
                                      );
                                  final msg = DirectMessage(
                                    id: '',
                                    senderId: widget.currentUserId,
                                    type: 'voiceMessage',
                                    text: '',
                                    voiceUrl: voiceUrl,
                                    voiceDurationMs: durationMs,
                                    voiceAmplitudes: amplitudes,
                                    timestamp: DateTime.now(),
                                  );
                                  await ref
                                      .read(directMessageServiceProvider)
                                      .sendDirectMessage(_chatId!, msg);
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

                      // Composer bar
                      if (!_showVoiceRecorder) _buildComposer(user, s),
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

  Widget _buildComposer(dynamic user, S s) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GlassContainer(
      borderRadius: 0,
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
                    onPressed: () => setState(() => _showVoiceRecorder = true),
                    tooltip: s.voiceMessage,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !ref
                          .read(safetyServiceProvider)
                          .isUserBanned(user),
                      decoration: InputDecoration(
                        hintText:
                            ref.read(safetyServiceProvider).isUserBanned(user)
                            ? (user.preferredLanguage == 'el'
                                  ? 'Αποκλεισμένος μέχρι ${ref.read(safetyServiceProvider).getRemainingBanTime(user)}'
                                  : 'Banned until ${ref.read(safetyServiceProvider).getRemainingBanTime(user)}')
                            : s.typeMessage,
                        hintStyle: TextStyle(
                          color: context.brand.neutralGrey,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
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
                      color: _isSending
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
                      onPressed:
                          (_isSending ||
                              ref
                                  .read(safetyServiceProvider)
                                  .isUserBanned(user))
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

    if (_chatId == null) return;

    if (_editingMessageId != null) {
      await _saveEdit(text, s);
      return;
    }

    setState(() => _isSending = true);

    try {
      // Upload images in parallel if any (much faster than sequential)
      final storageService = ref.read(storageServiceProvider);
      final List<String> imageUrls;
      if (_pendingImages.isNotEmpty) {
        final bytesFutures = _pendingImages
            .map((xf) => xf.readAsBytes())
            .toList();
        final allBytes = await Future.wait(bytesFutures);

        for (final bytes in allBytes) {
          StorageService.ensureWithinUploadLimit(bytes.length);
        }

        final uploadFutures = List.generate(_pendingImages.length, (i) {
          final ext = StorageService.normalizeImageExt(_pendingImages[i].name);
          return storageService.uploadImageBytes(
            allBytes[i],
            'direct_chat_images',
            ext: ext,
            ownerUid: widget.currentUserId,
            scopeId: _chatId!,
          );
        });
        imageUrls = await Future.wait(uploadFutures);
      } else {
        imageUrls = <String>[];
      }

      final msg = DirectMessage(
        id: '',
        senderId: widget.currentUserId,
        type: _isAcademicMode ? 'academic' : 'social',
        text: text,
        subject: _isAcademicMode ? _selectedSubject : null,
        imageUrls: imageUrls,
        timestamp: DateTime.now(),
      );

      await ref
          .read(directMessageServiceProvider)
          .sendDirectMessage(_chatId!, msg);

      _textController.clear();
      setState(() {
        _pendingImages.clear();
        _selectedSubject = null;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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

  Future<void> _saveEdit(String nextText, S s) async {
    if (_chatId == null || _editingMessageId == null) return;
    setState(() => _isSending = true);
    try {
      await ref
          .read(directMessageServiceProvider)
          .editMessage(_chatId!, _editingMessageId!, nextText);
      _textController.clear();
      setState(() {
        _editingMessageId = null;
        _initialEditText = null;
      });
    } on FormatException catch (e) {
      if (e.message == 'profanity_detected' && mounted) {
        CustomSnackBar.show(
          context: context,
          message: s.lang == 'el'
              ? 'Μη αποδεκτό περιεχόμενο.'
              : 'Profanity detected.',
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

  Future<void> _blockUser(String authorId) async {
    try {
      await ref.read(authRepositoryProvider).blockUser(authorId);
      await ref
          .read(friendshipServiceProvider)
          .removeFriend(widget.currentUserId, authorId);
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: S(widget.lang).userBlocked,
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.lang == 'el' ? 'Σφάλμα.' : 'Something went wrong.',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    try {
      await ref
          .read(friendshipServiceProvider)
          .removeFriend(widget.currentUserId, widget.friendId);
      if (mounted) {
        final s = S(widget.lang);
        CustomSnackBar.show(
          context: context,
          message: s.lang == 'el'
              ? 'Ο χρήστης αφαιρέθηκε από τους φίλους.'
              : 'User removed from friends.',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _clearConversation() async {
    if (_chatId == null) return;
    try {
      await ref.read(directMessageServiceProvider).clearConversation(_chatId!);
      if (mounted) {
        final s = S(widget.lang);
        CustomSnackBar.show(
          context: context,
          message: s.lang == 'el'
              ? 'Η συνομιλία καθαρίστηκε.'
              : 'Conversation cleared.',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _startEditing(DirectMessage message) {
    setState(() {
      _editingMessageId = message.id;
      _initialEditText = _textController.text;
      _textController.text = message.text;
    });
  }
}

class _ChatDateDivider extends StatelessWidget {
  final String label;

  const _ChatDateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outline.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.28,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, thickness: 1, color: line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, thickness: 1, color: line)),
        ],
      ),
    );
  }
}

class _MessagesList extends ConsumerWidget {
  final String chatId;
  final String currentUserId;
  final ScrollController scrollController;
  final String lang;
  final Function(DirectMessage) onEdit;

  const _MessagesList({
    required this.chatId,
    required this.currentUserId,
    required this.scrollController,
    required this.lang,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(directMessagesProvider(chatId));
    final limit = ref.watch(dmMessageLimitProvider(chatId));
    final s = S(lang);

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

        final mayHaveMore = messages.length >= limit;

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          itemCount: messages.length + (mayHaveMore ? 1 : 0),
          itemBuilder: (context, index) {
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
                          .read(dmMessageLimitProvider(chatId).notifier)
                          .state += 50;
                    },
                  ),
                ),
              );
            }
            final msg = messages[index];
            final messageKey = ValueKey('direct_${msg.id}');
            final isMe = msg.senderId == currentUserId;
            final topGap = chatMessageTopPadding(
              newer: msg.timestamp,
              older: index < messages.length - 1
                  ? messages[index + 1].timestamp
                  : null,
              newerAuthorId: msg.senderId,
              olderAuthorId: index < messages.length - 1
                  ? messages[index + 1].senderId
                  : null,
            );
            final showDayDivider =
                index < messages.length - 1 &&
                !chatSameCalendarDay(
                  msg.timestamp,
                  messages[index + 1].timestamp,
                );

            if (msg.isDeleted) {
              return KeyedSubtree(
                key: messageKey,
                child: chatMessageListGap(
                  topPadding: topGap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDayDivider)
                        _ChatDateDivider(
                          label: _directChatDateDividerLabel(
                            messages[index + 1].timestamp,
                            lang,
                          ),
                        ),
                      _DeletedMessageBubble(isMe: isMe, s: s),
                    ],
                  ),
                ),
              );
            }

            return KeyedSubtree(
              key: messageKey,
              child: chatMessageListGap(
                topPadding: topGap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDayDivider)
                      _ChatDateDivider(
                        label: _directChatDateDividerLabel(
                          messages[index + 1].timestamp,
                          lang,
                        ),
                      ),
                    _DirectMessageBubble(
                      message: msg,
                      isMe: isMe,
                      chatId: chatId,
                      currentUserId: currentUserId,
                      s: s,
                      onEdit: () => onEdit(msg),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _DirectMessageBubble extends ConsumerStatefulWidget {
  final DirectMessage message;
  final bool isMe;
  final String chatId;
  final String currentUserId;
  final S s;
  final VoidCallback onEdit;

  const _DirectMessageBubble({
    required this.message,
    required this.isMe,
    required this.chatId,
    required this.currentUserId,
    required this.s,
    required this.onEdit,
  });

  @override
  ConsumerState<_DirectMessageBubble> createState() =>
      _DirectMessageBubbleState();
}

class _DirectMessageBubbleState extends ConsumerState<_DirectMessageBubble> {
  dynamic _player;
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

  void _showUserProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileSheet(userId: widget.message.senderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: isMe ? null : _showUserProfile,
        onLongPress: () =>
            _showMessageOptions(context, message, isMe, widget.s),
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
                // Academic subject tag
                if (message.type == 'academic' &&
                    message.subject != null &&
                    message.subject!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
                  const SizedBox(height: 4),
                ],

                // Message text
                if (message.text.isNotEmpty) ...[
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
                      widget.s.edited,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

                // Voice message
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
                              GestureDetector(
                                onTap: () => _togglePlayback(message.voiceUrl!),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
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
                                              color: context.brand.royalLavender
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: context.brand.royalLavender
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 4,
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
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    const barWidth = 3.0;
                                    final amps = _getAmplitudes();
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: List.generate(amps.length, (i) {
                                        final progressThreshold =
                                            i / amps.length;
                                        final isPlayed =
                                            _playbackProgress >
                                            progressThreshold;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 100,
                                          ),
                                          width: barWidth,
                                          height: 24 * amps[i],
                                          decoration: BoxDecoration(
                                            color: isPlayed
                                                ? context.brand.royalLavender
                                                : context.brand.neutralGrey
                                                      .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
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
                  ),
                ],

                // Timestamp
                const SizedBox(height: 6),
                Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 9,
                      color: context.brand.darkText.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageOptions(
    BuildContext context,
    DirectMessage message,
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
              ],
              if (!isMe) ...[
                ListTile(
                  leading: Icon(
                    Icons.report_outlined,
                    color: context.brand.sunsetWarning,
                  ),
                  title: Text(
                    s.lang == 'el' ? 'Αναφορά Μηνύματος' : 'Report Message',
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
                    _blockUser(message.senderId);
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
      final deletedText = widget.s.lang == 'el'
          ? '🚫 Διαγραμμένο μήνυμα'
          : '🚫 Deleted message';
      await ref
          .read(directMessageServiceProvider)
          .deleteMessage(widget.chatId, messageId, deletedText: deletedText);
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

  void _reportMessage(DirectMessage message) async {
    try {
      await ref
          .read(directMessageServiceProvider)
          .reportMessage(
            reporterId: widget.currentUserId,
            reportedUserId: message.senderId,
            messageId: message.id,
            chatId: widget.chatId,
            messageText: message.text,
            reason: 'Inappropriate content',
          );
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: widget.s.lang == 'el'
              ? 'Η αναφορά στάλθηκε.'
              : 'Report sent.',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _blockUser(String authorId) async {
    try {
      await ref.read(authRepositoryProvider).blockUser(authorId);
      await ref
          .read(friendshipServiceProvider)
          .removeFriend(widget.currentUserId, authorId);
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
          message: widget.s.lang == 'el' ? 'Σφάλμα.' : 'Something went wrong.',
          type: SnackBarType.error,
        );
      }
    }
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.brand.neutralGrey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.brand.neutralGrey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 14,
              color: context.brand.neutralGrey.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              s.lang == 'el' ? 'Διαγραμμένο μήνυμα' : 'Deleted message',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: context.brand.neutralGrey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
