import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/chat_provider.dart';
import '../domain/ai_chat_models.dart';
import '../data/ai_chat_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/ai_pulsing_indicator.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/responsive_layout.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/domain/parental_consent_eligibility.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../../../shared/ai_upload_service.dart';
import '../../auth/presentation/parental_consent_screen.dart';
import '../../../shared/l10n.dart';
import '../../../shared/app_locale.dart';

class StudyBuddyScreen extends ConsumerStatefulWidget {
  const StudyBuddyScreen({super.key});

  @override
  ConsumerState<StudyBuddyScreen> createState() => _StudyBuddyScreenState();
}

class _StudyBuddyScreenState extends ConsumerState<StudyBuddyScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final List<XFile> _selectedImages = [];
  ProviderSubscription<List<AIChatMessage>>? _chatSubscription;

  /// Which AI message shows the copy toolbar (single open at a time).
  String? _copyToolbarMessageId;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _composerFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _chatSubscription = ref.listenManual(chatProvider, (previous, next) {
      if (next.length != (previous?.length ?? 0)) {
        _scrollToBottom();
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null && mounted) {
      setState(() => _selectedImages.add(picked));
    }
  }

  void _removeImageAt(int idx) {
    setState(() => _selectedImages.removeAt(idx));
  }

  @override
  void dispose() {
    _chatSubscription?.close();
    _textController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final chatNotifier = ref.read(chatProvider.notifier);
    final isTyping = chatNotifier.isTyping;
    final activeSessionId = ref.watch(activeChatSessionIdProvider);
    final curUser = ref.watch(authStateProvider).value;
    final sparks = curUser?.aiSparks ?? 0;
    final nextSparkReset = ref.watch(sparkNextResetUtcProvider);
    final langUi = ref.watch(appLocaleProvider).languageCode;
    final s = S(langUi);

    Future<void> handleSend() async {
      if (isTyping) return;
      final text = _textController.text.trim();
      if (text.isEmpty && _selectedImages.isEmpty) return;

      if (sparks <= 0) {
        await _offerRewardedSparkRefill(
          curUser,
          nextSparkReset: nextSparkReset,
        );
        return;
      }

      final queuedImages = List<XFile>.from(_selectedImages);
      final sessionForUpload = activeSessionId ?? 'pending';
      final attachments = await uploadAiImages(
        files: queuedImages,
        feature: 'chat',
        sessionId: sessionForUpload,
      );
      final imageBytes = <Uint8List>[];
      for (final xf in queuedImages) {
        imageBytes.add(await xf.readAsBytes());
      }
      if (!mounted) return;

      _textController.clear();
      setState(() => _selectedImages.clear());
      FocusScope.of(this.context).unfocus();

      await chatNotifier.sendMessage(
        text,
        onSessionCreated: (newId) {
          ref.read(activeChatSessionIdProvider.notifier).state = newId;
        },
        attachments: attachments,
        images: imageBytes,
      );
    }

    if (curUser != null && requiresParentalAiGate(curUser)) {
      return Scaffold(
        backgroundColor: context.brand.backgroundSnow,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            s.aiStudyAssistantTitle,
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: IconThemeData(color: context.brand.darkText),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: ParentalConsentScreen(),
          ),
        ),
      );
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);

    // ── Desktop layout: global gradient + transparent scaffold + left sidebar ──
    if (isDesktop) {
      return AppTheme.globalGradient(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // ── Persistent history sidebar ──────────────────────────────────
              Container(
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back + title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: context.brand.darkText,
                                size: 20,
                              ),
                              onPressed: () => Navigator.maybePop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.aiStudyAssistantSidebar,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: context.brand.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // New chat button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: LiquidTouch(
                          onTap: () =>
                              ref
                                      .read(
                                        activeChatSessionIdProvider.notifier,
                                      )
                                      .state =
                                  null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.brand.royalLavender,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s.aiNewChat,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          s.aiHistorySection,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.8,
                            ),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Sessions list
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final sessionsAsync = ref.watch(
                              chatSessionsProvider,
                            );
                            final activeId = ref.watch(
                              activeChatSessionIdProvider,
                            );
                            return sessionsAsync.when(
                              data: (sessions) => sessions.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        s.aiNoChatsYet,
                                        style: TextStyle(
                                          color: context.brand.neutralGrey
                                              .withValues(alpha: 0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      itemCount: sessions.length,
                                      itemBuilder: (ctx, i) {
                                        final session = sessions[i];
                                        final isActive = session.id == activeId;
                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? context.brand.royalLavender
                                                      .withValues(alpha: 0.12)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 0,
                                                ),
                                            title: Text(
                                              session.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isActive
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isActive
                                                    ? context
                                                          .brand
                                                          .royalLavender
                                                    : context.brand.darkText,
                                              ),
                                            ),
                                            subtitle: Text(
                                              DateFormat(
                                                'dd/MM, HH:mm',
                                              ).format(session.lastMessageAt),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                            onTap: () =>
                                                ref
                                                    .read(
                                                      activeChatSessionIdProvider
                                                          .notifier,
                                                    )
                                                    .state = session
                                                    .id,
                                          ),
                                        );
                                      },
                                    ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Text(
                                '${s.error}: $e',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Main chat area ─────────────────────────────────────────────
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      // Minimal top bar (sparks + actions)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: context.brand.royalLavender,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              activeSessionId == null
                                  ? s.aiNewChat
                                  : s.aiStudyAssistantTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: context.brand.darkText,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.brand.royalLavender.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    color: context.brand.royalLavender,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$sparks',
                                    style: TextStyle(
                                      color: context.brand.royalLavender,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Messages area
                      Expanded(
                        child: messages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 72,
                                      color: context.brand.royalLavender
                                          .withValues(alpha: 0.2),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      s.aiWelcomePitch,
                                      style: TextStyle(
                                        color: context.brand.neutralGrey,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ScrollConfiguration(
                                behavior: ScrollConfiguration.of(
                                  context,
                                ).copyWith(scrollbars: false),
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (ScrollNotification n) {
                                    if (_copyToolbarMessageId != null) {
                                      setState(
                                        () => _copyToolbarMessageId = null,
                                      );
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      16,
                                    ),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final m = messages[index];
                                      return _ChatBubble(
                                        ui: s,
                                        message: m,
                                        showCopyToolbar:
                                            _copyToolbarMessageId == m.id &&
                                            !m.isUser,
                                        onAiLongPress: m.isUser
                                            ? null
                                            : () => setState(
                                                () => _copyToolbarMessageId =
                                                    m.id,
                                              ),
                                        onDismissToolbar: () => setState(
                                          () => _copyToolbarMessageId = null,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                      if (isTyping)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: AIPulsingIndicator(
                            color: context.brand.royalLavender,
                            size: 20,
                          ),
                        ),
                      // ── Modern pill input bar ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? context.brand.surfaceElevated
                                    : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Theme.of(context).colorScheme.outline
                                            .withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedImages.isNotEmpty)
                                    SizedBox(
                                      height: 56,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _selectedImages.length,
                                        itemBuilder: (context, i) => Stack(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              margin: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: kIsWeb
                                                    ? Image.network(
                                                        _selectedImages[i].path,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(
                                                          _selectedImages[i]
                                                              .path,
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: GestureDetector(
                                                onTap: () => _removeImageAt(i),
                                                child: const CircleAvatar(
                                                  radius: 7,
                                                  backgroundColor: Colors.red,
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 9,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: _pickImage,
                                        icon: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          color: context.brand.neutralGrey,
                                          size: 20,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _textController,
                                          focusNode: _composerFocusNode,
                                          keyboardType: TextInputType.multiline,
                                          textInputAction:
                                              TextInputAction.newline,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          style: TextStyle(
                                            fontFamily: 'Fustat',
                                            fontSize: 14,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                          maxLines: null,
                                          minLines: 1,
                                          decoration: InputDecoration(
                                            hintText: s.aiAskAnythingHint,
                                            hintStyle: TextStyle(
                                              fontFamily: 'Fustat',
                                              color: context.brand.neutralGrey,
                                              fontSize: 14,
                                            ),
                                            border: InputBorder.none,
                                            isDense: false,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 10,
                                                ),
                                          ),
                                          onSubmitted: isTyping
                                              ? null
                                              : (_) => handleSend(),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: isTyping ? null : handleSend,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isTyping
                                                ? context.brand.royalLavender
                                                      .withValues(alpha: 0.4)
                                                : context.brand.royalLavender,
                                            shape: BoxShape.circle,
                                            boxShadow: isTyping
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: context
                                                          .brand
                                                          .royalLavender
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: isTyping
                                              ? const AIPulsingIndicator(
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : const Icon(
                                                  Icons.arrow_upward_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Mobile layout (unchanged) ──────────────────────────────────────────────
    return Scaffold(
      backgroundColor: context.brand.backgroundSnow,
      endDrawer: const _HistoryDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: context.brand.darkText),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.aiStudyAssistantTitle,
              style: TextStyle(
                color: context.brand.darkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (activeSessionId == null)
              Text(
                s.aiNewChat,
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontSize: 12,
                ),
              )
            else
              Text(
                s.aiChatInProgress,
                style: TextStyle(
                  color: context.brand.royalLavender,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.brand.royalLavender.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      color: context.brand.royalLavender,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$sparks',
                      style: TextStyle(
                        color: context.brand.royalLavender,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: context.brand.royalLavender,
            ),
            onPressed: () =>
                ref.read(activeChatSessionIdProvider.notifier).state = null,
            tooltip: s.aiNewChat,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.history_rounded,
                color: context.brand.royalLavender,
              ),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: s.aiHistorySection,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 80,
                              color: context.brand.royalLavender.withValues(
                                alpha: 0.2,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              s.aiWelcomePitch,
                              style: TextStyle(
                                color: context.brand.neutralGrey,
                                fontSize: 16,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification n) {
                          if (_copyToolbarMessageId != null) {
                            setState(() => _copyToolbarMessageId = null);
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final m = messages[index];
                            return _ChatBubble(
                              ui: s,
                              message: m,
                              showCopyToolbar:
                                  _copyToolbarMessageId == m.id && !m.isUser,
                              onAiLongPress: m.isUser
                                  ? null
                                  : () => setState(
                                      () => _copyToolbarMessageId = m.id,
                                    ),
                              onDismissToolbar: () =>
                                  setState(() => _copyToolbarMessageId = null),
                            );
                          },
                        ),
                      ),
              ),

              if (isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AIPulsingIndicator(
                    color: context.brand.royalLavender,
                    size: 20,
                  ),
                ),

              // Input area
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 64,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, i) => Stack(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                margin: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImages[i].path,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_selectedImages[i].path),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImageAt(i),
                                  child: const CircleAvatar(
                                    radius: 8,
                                    backgroundColor: Colors.red,
                                    child: Icon(
                                      Icons.close,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _pickImage,
                              icon: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: context.brand.royalLavender,
                              ),
                            ),
                            Expanded(
                              child: GlassContainer(
                                height: 50,
                                borderRadius: 999,
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? context.brand.inputFill
                                    : context.brand.neutralGrey.withValues(
                                        alpha: 0.05,
                                      ),
                                border: Border.all(
                                  color: _composerFocusNode.hasFocus
                                      ? context.brand.primaryPurple.withValues(
                                          alpha: 0.72,
                                        )
                                      : Theme.of(context).brightness ==
                                            Brightness.dark
                                      ? Theme.of(context).colorScheme.outline
                                            .withValues(alpha: 0.25)
                                      : context.brand.neutralGrey.withValues(
                                          alpha: 0.1,
                                        ),
                                  width: _composerFocusNode.hasFocus ? 1.5 : 1,
                                ),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _composerFocusNode,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  expands: true,
                                  maxLines: null,
                                  minLines: null,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: TextStyle(
                                    fontFamily: 'Fustat',
                                    fontSize: 15,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: s.aiAskAnythingHint,
                                    hintStyle: TextStyle(
                                      fontFamily: 'Fustat',
                                      color: context.brand.neutralGrey,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                    filled: false,
                                    isDense: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 8,
                                    ),
                                  ),
                                  onSubmitted: isTyping
                                      ? null
                                      : (_) => handleSend(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isTyping)
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: context.brand.royalLavender.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const AIPulsingIndicator(
                                  color: Colors.white,
                                  size: 22,
                                ),
                              )
                            else
                              LiquidTouch(
                                onTap: handleSend,
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: context.brand.royalLavender,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.brand.royalLavender,
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_upward_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _offerRewardedSparkRefill(
    AppUser? user, {
    DateTime? nextSparkReset,
  }) async {
    if (user == null) return;
    final preferredLanguage = user.preferredLanguage;
    CustomSnackBar.show(
      context: context,
      message: sparkLimitUserMessage(
        preferredLanguage: preferredLanguage,
        nextResetUtc: nextSparkReset,
        subscriptionType: user.subscriptionType,
      ),
      type: SnackBarType.warning,
    );
  }
}

class _HistoryDrawer extends ConsumerWidget {
  const _HistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    final activeId = ref.watch(activeChatSessionIdProvider);
    final langUi = ref.watch(appLocaleProvider).languageCode;
    final s = S(langUi);

    return Drawer(
      backgroundColor: context.brand.backgroundSnow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                s.aiChatHistoryDrawerTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.brand.darkText,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => sessions.isEmpty
                    ? Center(
                        child: Text(
                          s.aiNoChatsYet,
                          style: TextStyle(color: context.brand.neutralGrey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final isActive = session.id == activeId;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? context.brand.royalLavender.withValues(
                                      alpha: 0.1,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isActive
                                      ? context.brand.royalLavender
                                      : context.brand.darkText,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat(
                                  'dd/MM, HH:mm',
                                ).format(session.lastMessageAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isActive
                                      ? context.brand.royalLavender.withValues(
                                          alpha: 0.7,
                                        )
                                      : context.brand.neutralGrey,
                                ),
                              ),
                              onTap: () {
                                ref
                                    .read(activeChatSessionIdProvider.notifier)
                                    .state = session
                                    .id;
                                Navigator.pop(context);
                              },
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final user = ref
                                      .read(authStateProvider)
                                      .value;
                                  if (user != null) {
                                    await ref
                                        .read(aiChatRepositoryProvider)
                                        .deleteSession(user.uid, session.id);
                                    if (isActive) {
                                      ref
                                              .read(
                                                activeChatSessionIdProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${s.error}: $e')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: LiquidTouch(
                  onTap: () {
                    ref.read(activeChatSessionIdProvider.notifier).state = null;
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: context.brand.royalLavender,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          s.aiNewChat,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain text for clipboard: remove common Markdown syntax while keeping readable prose.
String _stripMarkdownForClipboard(String input) {
  if (input.isEmpty) return '';
  var t = input;
  t = t.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  t = t.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  t = t.replaceAllMapped(
    RegExp(r'```[\w]*\n?([\s\S]*?)```'),
    (m) => '${m.group(1)?.trim() ?? ''}\n',
  );
  t = t.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
  t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  t = t.replaceAll('**', '').replaceAll('__', '');
  t = t.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1) ?? '');
  t = t.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m.group(1) ?? '');
  t = t.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  t = t.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
  return t.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

class _ChatBubble extends StatelessWidget {
  final S ui;
  final AIChatMessage message;
  final bool showCopyToolbar;
  final VoidCallback? onAiLongPress;
  final VoidCallback onDismissToolbar;

  const _ChatBubble({
    required this.ui,
    required this.message,
    required this.showCopyToolbar,
    required this.onAiLongPress,
    required this.onDismissToolbar,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const aiBubbleDark = Color(0xFF2A2A3D);
    const aiTextDark = Color(0xFFE7E7EA);
    final aiFg = dark ? aiTextDark : context.brand.darkText;
    final bubbleColor = message.isUser
        ? context.brand.royalLavender
        : (dark ? aiBubbleDark : Colors.white);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(message.isUser ? 20 : 4),
          bottomRight: Radius.circular(message.isUser ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: message.isUser
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                      fontFamily: 'Fustat',
                    ),
                  ),
                if (message.attachments.isNotEmpty) ...[
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in message.attachments)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Builder(
                            builder: (context) {
                              final px =
                                  (110 * MediaQuery.devicePixelRatioOf(context))
                                      .round();
                              return CachedNetworkImage(
                                imageUrl: a['downloadUrl']?.toString() ?? '',
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                memCacheWidth: px,
                                memCacheHeight: px,
                                maxWidthDiskCache: px,
                                maxHeightDiskCache: px,
                                placeholder: (_, __) => Container(
                                  width: 110,
                                  height: 110,
                                  color: context.brand.neutralGrey.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 110,
                                  height: 110,
                                  color: context.brand.neutralGrey.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: context.brand.neutralGrey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            )
          : MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: aiFg,
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: 'Fustat',
                ),
                strong: TextStyle(
                  color: dark ? Colors.white : context.brand.darkText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Fustat',
                ),
                em: TextStyle(
                  color: aiFg,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Fustat',
                ),
                listBullet: TextStyle(color: aiFg),
                h1: TextStyle(
                  color: dark ? Colors.white : context.brand.darkText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Fustat',
                ),
                code: TextStyle(
                  backgroundColor: dark
                      ? Colors.black.withValues(alpha: 0.28)
                      : context.brand.neutralGrey.withValues(alpha: 0.1),
                  color: aiFg,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                blockquote: TextStyle(color: aiFg),
                a: TextStyle(
                  color: dark
                      ? context.brand.royalLavender
                      : context.brand.primaryPurple,
                ),
              ),
            ),
    );

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: bubble,
        ),
      );
    }

    final plain = _stripMarkdownForClipboard(message.text);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TapRegion(
          onTapOutside: (_) => onDismissToolbar(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onLongPress: onAiLongPress,
                behavior: HitTestBehavior.opaque,
                child: bubble,
              ),
              if (showCopyToolbar) ...[
                const SizedBox(height: 6),
                Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? context.brand.surfaceElevated
                      : Colors.white,
                  elevation: 1,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: plain));
                      onDismissToolbar();
                      CustomSnackBar.show(
                        context: context,
                        message: ui.aiCopied,
                        type: SnackBarType.success,
                        duration: const Duration(milliseconds: 1500),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: context.brand.primaryPurple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            ui.aiCopy,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.brand.darkText,
                              fontFamily: 'Fustat',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
