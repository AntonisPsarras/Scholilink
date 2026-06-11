import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/ai_pulsing_indicator.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/responsive_layout.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/domain/parental_consent_eligibility.dart';
import '../../../core/spark_limit_message.dart';
import '../../../core/spark_sync.dart';
import '../../../shared/ai_upload_service.dart';
import '../../../shared/ocr_image_bytes.dart';
import '../../auth/presentation/parental_consent_screen.dart';
import '../providers/smart_notes_provider.dart';
import '../domain/smart_notes_models.dart';
import '../data/smart_notes_repository.dart';
import '../../../shared/l10n.dart';
import '../../../shared/app_locale.dart';

class SmartNotesScreen extends ConsumerStatefulWidget {
  const SmartNotesScreen({super.key});

  @override
  ConsumerState<SmartNotesScreen> createState() => _SmartNotesScreenState();
}

class _SmartNotesScreenState extends ConsumerState<SmartNotesScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScreenshotController _screenshotController = ScreenshotController();
  final List<XFile> _selectedImages = [];
  String _lengthOption = 'short';
  String _depthOption = 'basic';
  bool _showModeControls = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (pickedFile != null) {
      setState(() => _selectedImages.add(pickedFile));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  @override
  void initState() {
    super.initState();
    _composerFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _composerFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final sessionId = ref.watch(activeNoteSessionIdProvider);
    final sparks = user?.aiSparks ?? 0;
    final nextSparkReset = ref.watch(sparkNextResetUtcProvider);
    final langUi = ref.watch(appLocaleProvider).languageCode;
    final loc = S(langUi);

    if (user != null && requiresParentalAiGate(user)) {
      return Scaffold(
        backgroundColor: context.brand.backgroundSnow,
        appBar: AppBar(
          title: Text(loc.smartNotesTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: ParentalConsentScreen()),
      );
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);

    // ── Desktop layout: global gradient + persistent left sidebar ─────────────
    if (isDesktop) {
      return AppTheme.globalGradient(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              // ── Persistent notes-history sidebar ─────────────────────────
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
                                loc.smartNotesSidebarShort,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: LiquidTouch(
                          onTap: () =>
                              ref
                                      .read(
                                        activeNoteSessionIdProvider.notifier,
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
                                  loc.smartNotesNewNotes,
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
                          loc.aiHistorySection,
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
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final sessionsAsync = ref.watch(
                              smartNotesSessionsProvider,
                            );
                            final activeId = ref.watch(
                              activeNoteSessionIdProvider,
                            );
                            return sessionsAsync.when(
                              data: (sessions) => sessions.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        loc.smartNotesNoNotesYet,
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
                                        final s = sessions[i];
                                        final isActive = s.id == activeId;
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
                                                ),
                                            title: Text(
                                              s.title,
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
                                                'dd/MM/yy',
                                              ).format(s.lastInteractionAt),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                            onTap: () =>
                                                ref
                                                    .read(
                                                      activeNoteSessionIdProvider
                                                          .notifier,
                                                    )
                                                    .state = s
                                                    .id,
                                          ),
                                        );
                                      },
                                    ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) => Text(
                                '${loc.error}: $e',
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
              // ── Main notes area ───────────────────────────────────────────
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              color: context.brand.royalLavender,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              loc.smartNotesTitle,
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
                      // Notes content — provider watch isolated to list subtree
                      Expanded(
                        child: _SmartNotesInteractionList(
                          loc: loc,
                          desktopPadding: true,
                        ),
                      ),
                      // ── Modern pill input bar ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? context.brand.surfaceElevated
                                    : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(24),
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
                              child: _buildInputArea(
                                loc,
                                sparks,
                                sessionId,
                                user,
                                user?.preferredLanguage,
                                nextSparkReset,
                                isDesktop: true,
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

    // ── Mobile layout (unchanged) ─────────────────────────────────────────────
    return Scaffold(
      backgroundColor: context.brand.backgroundSnow,
      endDrawer: const _NotesHistoryDrawer(),
      appBar: AppBar(
        title: Text(
          loc.smartNotesTitle,
          style: TextStyle(
            color: context.brand.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: context.brand.darkText),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: context.brand.royalLavender,
            ),
            onPressed: () =>
                ref.read(activeNoteSessionIdProvider.notifier).state = null,
            tooltip: loc.smartNotesNewNotes,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: Icon(
                Icons.history_rounded,
                color: context.brand.royalLavender,
              ),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: loc.aiHistorySection,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _SmartNotesInteractionList(
              loc: loc,
              desktopPadding: false,
              screenshotController: _screenshotController,
            ),
          ),
          _buildInputArea(
            loc,
            sparks,
            sessionId,
            user,
            user?.preferredLanguage,
            nextSparkReset,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(
    S loc,
    int sparks,
    String? sessionId,
    AppUser? user,
    String? preferredLanguage,
    DateTime? nextSparkReset, {
    bool isDesktop = false,
  }) {
    int estimatedCost() {
      if (_lengthOption == 'long' && _depthOption == 'inDepth') return 3;
      if (_lengthOption == 'medium' && _depthOption == 'standard') return 2;
      return 1;
    }

    return Container(
      padding: isDesktop
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: isDesktop
          ? null
          : BoxDecoration(
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
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _showModeControls = !_showModeControls),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.brand.royalLavender.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.brand.royalLavender.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: context.brand.royalLavender,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${loc.smartNotesNoteSettingsLabel} • ${estimatedCost()} Sparks',
                      style: TextStyle(
                        color: context.brand.darkText.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _showModeControls ? Icons.expand_less : Icons.expand_more,
                    color: context.brand.royalLavender,
                  ),
                ],
              ),
            ),
          ),
          if (_showModeControls) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loc.smartNotesLengthSection,
                style: TextStyle(
                  color: context.brand.darkText.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(loc.smartNotesLenShort),
                  selected: _lengthOption == 'short',
                  onSelected: (_) => setState(() => _lengthOption = 'short'),
                ),
                ChoiceChip(
                  label: Text(loc.smartNotesLenMedium),
                  selected: _lengthOption == 'medium',
                  onSelected: (_) => setState(() => _lengthOption = 'medium'),
                ),
                ChoiceChip(
                  label: Text(loc.smartNotesLenLong),
                  selected: _lengthOption == 'long',
                  onSelected: (_) => setState(() => _lengthOption = 'long'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                loc.smartNotesDepthSection,
                style: TextStyle(
                  color: context.brand.darkText.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(loc.smartNotesDepthBasic),
                  selected: _depthOption == 'basic',
                  onSelected: (_) => setState(() => _depthOption = 'basic'),
                ),
                ChoiceChip(
                  label: Text(loc.smartNotesDepthStandard),
                  selected: _depthOption == 'standard',
                  onSelected: (_) => setState(() => _depthOption = 'standard'),
                ),
                ChoiceChip(
                  label: Text(loc.smartNotesDepthInDepth),
                  selected: _depthOption == 'inDepth',
                  onSelected: (_) => setState(() => _depthOption = 'inDepth'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          if (_selectedImages.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) => _ImagePreviewThumbnail(
                  image: _selectedImages[index],
                  onRemove: () => _removeImage(index),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
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
                  borderRadius: 999,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? context.brand.inputFill
                      : context.brand.neutralGrey.withValues(alpha: 0.05),
                  border: Border.all(
                    color: _composerFocusNode.hasFocus
                        ? context.brand.primaryPurple.withValues(alpha: 0.72)
                        : Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.25)
                        : context.brand.neutralGrey.withValues(alpha: 0.12),
                    width: _composerFocusNode.hasFocus ? 1.5 : 1,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: TextField(
                      controller: _textController,
                      focusNode: _composerFocusNode,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: loc.smartNotesPasteOrAskHint,
                        hintStyle: TextStyle(
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
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) {
                  final isLoading = ref.watch(
                    smartNotesProvider.select((s) => s.isLoading),
                  );
                  if (isLoading) {
                    return Container(
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
                    );
                  }
                  return LiquidTouch(
                    onTap: () async {
                      final text = _textController.text.trim();
                      if (text.isEmpty && _selectedImages.isEmpty) return;
                      final effectivePrompt = text.isNotEmpty
                          ? text
                          : loc.smartNotesPromptFromImagesOnly;

                      final estimated = estimatedCost();
                      if (sparks < estimated) {
                        await _offerRewardedSparkRefill(
                          user,
                          preferredLanguage: preferredLanguage,
                          nextSparkReset: nextSparkReset,
                        );
                        return;
                      }

                      final queuedImages = List<XFile>.from(_selectedImages);
                      final images = await prepareAiImagesFromXFiles(
                        queuedImages,
                      );
                      final attachments = await uploadAiImages(
                        imageBytes: images,
                        feature: 'notes',
                        sessionId: sessionId ?? 'pending',
                      );

                      if (!mounted) return;
                      _textController.clear();
                      setState(() => _selectedImages.clear());
                      if (!context.mounted) return;
                      FocusScope.of(context).unfocus();

                      await ref
                          .read(smartNotesProvider.notifier)
                          .processPrompt(
                            effectivePrompt,
                            images: images,
                            attachments: attachments,
                            lengthOption: _lengthOption,
                            depthOption: _depthOption,
                            onSessionCreated: (newId) {
                              ref
                                      .read(
                                        activeNoteSessionIdProvider.notifier,
                                      )
                                      .state =
                                  newId;
                            },
                          );
                    },
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: context.brand.royalLavender,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _offerRewardedSparkRefill(
    AppUser? user, {
    String? preferredLanguage,
    DateTime? nextSparkReset,
  }) async {
    if (user == null) return;
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

Future<Uint8List> _captureSmartNoteCardPng(
  BuildContext context,
  SmartNoteCard card,
) async {
  final controller = ScreenshotController();
  // [captureFromWidget] lays out with the *viewport* max height, so tall notes
  // overflow (RenderFlex bottom overflow). [captureFromLongWidget] measures
  // intrinsic height under loose vertical constraints, then captures at that size.
  return controller.captureFromLongWidget(
    Material(
      color: Colors.white,
      child: Container(
        width: 900,
        padding: const EdgeInsets.all(24),
        child: _CardContent(card: card),
      ),
    ),
    context: context,
    constraints: const BoxConstraints(maxWidth: 900),
    delay: const Duration(milliseconds: 400),
  );
}

class _SmartNotesInteractionList extends ConsumerWidget {
  final S loc;
  final bool desktopPadding;
  final ScreenshotController? screenshotController;

  const _SmartNotesInteractionList({
    required this.loc,
    required this.desktopPadding,
    this.screenshotController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(smartNotesProvider);
    final interactions = notesState.interactions;
    final padding = desktopPadding
        ? const EdgeInsets.fromLTRB(24, 16, 24, 8)
        : const EdgeInsets.all(20);

    if (interactions.isEmpty && !notesState.isLoading) {
      final placeholder = _SmartNotesInitialPlaceholder(loc: loc);
      if (screenshotController != null) {
        return Screenshot(
          controller: screenshotController!,
          child: Container(
            color: context.brand.backgroundSnow,
            padding: padding,
            child: placeholder,
          ),
        );
      }
      return SingleChildScrollView(padding: padding, child: placeholder);
    }

    final trailingCount =
        (notesState.isLoading ? 1 : 0) + (notesState.error != null ? 1 : 0);

    Widget listView = ListView.builder(
      padding: padding,
      itemCount: interactions.length + trailingCount,
      itemBuilder: (context, index) {
        if (index < interactions.length) {
          return _InteractionBlock(interaction: interactions[index]);
        }
        final trailingIndex = index - interactions.length;
        if (notesState.isLoading && trailingIndex == 0) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: AIPulsingIndicator(
              color: context.brand.royalLavender,
              size: 40,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            notesState.error!,
            style: TextStyle(color: context.brand.dangerRose),
          ),
        );
      },
    );

    if (desktopPadding) {
      listView = ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: listView,
      );
    }

    if (screenshotController != null) {
      listView = Screenshot(
        controller: screenshotController!,
        child: Container(color: context.brand.backgroundSnow, child: listView),
      );
    }

    return listView;
  }
}

class _SmartNotesInitialPlaceholder extends StatelessWidget {
  final S loc;

  const _SmartNotesInitialPlaceholder({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.note_alt_outlined,
          size: 100,
          color: context.brand.royalLavender.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 20),
        Text(
          loc.smartNotesWelcome,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.brand.neutralGrey,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InteractionBlock extends StatelessWidget {
  final SmartNoteInteraction interaction;
  const _InteractionBlock({required this.interaction});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interaction.prompt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: context.brand.neutralGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    interaction.prompt,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: context.brand.neutralGrey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (interaction.attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in interaction.attachments)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Builder(
                      builder: (context) {
                        final px =
                            (100 * MediaQuery.devicePixelRatioOf(context))
                                .round();
                        return CachedNetworkImage(
                          imageUrl: a['downloadUrl']?.toString() ?? '',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          memCacheWidth: px,
                          memCacheHeight: px,
                          maxWidthDiskCache: px,
                          maxHeightDiskCache: px,
                          placeholder: (_, __) => Container(
                            width: 100,
                            height: 100,
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
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
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Προφίλ: ${interaction.lengthOption} / ${interaction.depthOption} • ${interaction.sparkCostUsed} Sparks',
            style: TextStyle(fontSize: 12, color: context.brand.neutralGrey),
          ),
        ),
        ...interaction.cards.map((card) => _NoteCard(card: card)),
        const Divider(height: 40),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final SmartNoteCard card;
  const _NoteCard({required this.card});

  Future<void> _downloadSingleCardImage(BuildContext context) async {
    final bytes = await _captureSmartNoteCardPng(context, card);
    final fileName = 'smart_note_${DateTime.now().millisecondsSinceEpoch}.png';
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (context.mounted) {
      CustomSnackBar.show(
        context: context,
        message: 'Η εικόνα αποθηκεύτηκε: ${file.path}',
        type: SnackBarType.success,
      );
    }
  }

  Future<void> _shareCardImage(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final bytes = await _captureSmartNoteCardPng(context, card);
      final dir = await getTemporaryDirectory();
      final fileName =
          'scholilink_note_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
          text: 'Σημείωση από ScholiLink',
        ),
      );
    } catch (e, st) {
      debugPrint('Share note card failed: $e\n$st');
      if (context.mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Αποτυχία κοινοποίησης.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardContent(card: card),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!kIsWeb)
                  IconButton(
                    tooltip: 'Κοινοποίηση εικόνας (WhatsApp, κ.λπ.)',
                    onPressed: () => _shareCardImage(context),
                    icon: Icon(
                      Icons.share_outlined,
                      color: context.brand.primaryPurple,
                    ),
                  ),
                IconButton(
                  tooltip: 'Λήψη σημείωσης ως εικόνα',
                  onPressed: () => _downloadSingleCardImage(context),
                  icon: Icon(
                    Icons.image_outlined,
                    color: context.brand.royalLavender,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final SmartNoteCard card;
  const _CardContent({required this.card});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: context.brand.royalLavender,
            fontFamily: 'Fustat',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          card.content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            fontFamily: 'Fustat',
          ),
        ),
        if (card.bulletPoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...card.bulletPoints.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: context.brand.royalLavender,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Fustat',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ImagePreviewThumbnail extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;
  const _ImagePreviewThumbnail({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: kIsWeb
                  ? Builder(
                      builder: (context) {
                        final px = (60 * MediaQuery.devicePixelRatioOf(context))
                            .round();
                        return CachedNetworkImage(
                          imageUrl: image.path,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          memCacheWidth: px,
                          memCacheHeight: px,
                          maxWidthDiskCache: px,
                          maxHeightDiskCache: px,
                          placeholder: (_, __) =>
                              Container(color: Colors.grey.shade300),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.image_not_supported, size: 28),
                        );
                      },
                    )
                  : Image.file(
                      File(image.path),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: context.brand.dangerRose,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesHistoryDrawer extends ConsumerWidget {
  const _NotesHistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(smartNotesSessionsProvider);
    final activeId = ref.watch(activeNoteSessionIdProvider);
    final langUi = ref.watch(appLocaleProvider).languageCode;
    final loc = S(langUi);

    return Drawer(
      backgroundColor: context.brand.backgroundSnow,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                loc.smartNotesHistoryDrawerTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final isActive = s.id == activeId;
                    return ListTile(
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yy').format(s.lastInteractionAt),
                      ),
                      selected: isActive,
                      selectedTileColor: context.brand.royalLavender.withValues(
                        alpha: 0.1,
                      ),
                      onTap: () {
                        ref.read(activeNoteSessionIdProvider.notifier).state =
                            s.id;
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          final user = ref.read(authStateProvider).value;
                          if (user != null) {
                            await ref
                                .read(smartNotesRepositoryProvider)
                                .deleteSession(user.uid, s.id);
                            if (isActive) {
                              ref
                                      .read(
                                        activeNoteSessionIdProvider.notifier,
                                      )
                                      .state =
                                  null;
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('${loc.error}: $e'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LiquidTouch(
                onTap: () {
                  ref.read(activeNoteSessionIdProvider.notifier).state = null;
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.brand.royalLavender,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      loc.smartNotesNewNotes,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
