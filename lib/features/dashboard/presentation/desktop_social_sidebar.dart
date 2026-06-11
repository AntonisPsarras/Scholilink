// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/glass_container.dart';
import '../../../shared/liquid_touch.dart';
import '../../../shared/l10n.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/subject_picker_dialog.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../ai_tutor/providers/chat_provider.dart';
import '../../ai_tutor/domain/ai_chat_models.dart';
import '../../ai_tutor/presentation/study_buddy_screen.dart';
import '../../ai_notes/providers/smart_notes_provider.dart';
import '../../ai_notes/presentation/smart_notes_screen.dart';
import '../data/dashboard_repository.dart';
import '../domain/exam_model.dart';

class DesktopSocialSidebar extends ConsumerStatefulWidget {
  const DesktopSocialSidebar({super.key});

  @override
  ConsumerState<DesktopSocialSidebar> createState() =>
      _DesktopSocialSidebarState();
}

class _DesktopSocialSidebarState extends ConsumerState<DesktopSocialSidebar> {
  // 0 = AI Chat, 1 = Smart Notes, 2 = Add Exam
  int _selectedTab = 0;

  // ── AI Chat state ──────────────────────────────────────────────────────────
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isAiSending = false;

  // ── Smart Notes state ──────────────────────────────────────────────────────
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessingNotes = false;

  // ── Add Exam state ─────────────────────────────────────────────────────────
  String? _examSubject;
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));
  bool _isSavingExam = false;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendChatMessage() async {
    // Function-level guard blocks Enter key AND button tap while thinking
    if (_isAiSending || _chatController.text.trim().isEmpty) return;
    final text = _chatController.text.trim();
    _chatController.clear();
    setState(() => _isAiSending = true);
    try {
      final notifier = ref.read(chatProvider.notifier);
      await notifier.sendMessage(
        text,
        onSessionCreated: (id) {
          ref.read(activeChatSessionIdProvider.notifier).state = id;
        },
      );
      _scrollChatToBottom();
    } finally {
      if (mounted) setState(() => _isAiSending = false);
    }
  }

  Future<void> _processNotes() async {
    if (_isProcessingNotes || _notesController.text.trim().isEmpty) return;
    setState(() => _isProcessingNotes = true);
    try {
      final notifier = ref.read(smartNotesProvider.notifier);
      await notifier.processPrompt(
        _notesController.text.trim(),
        onSessionCreated: (id) {
          ref.read(activeNoteSessionIdProvider.notifier).state = id;
        },
      );
      _notesController.clear();
    } finally {
      if (mounted) setState(() => _isProcessingNotes = false);
    }
  }

  Future<void> _saveExam(AppUser user, String lang) async {
    if (_examSubject == null) {
      CustomSnackBar.show(
        context: context,
        message: lang == 'el' ? 'Επίλεξε μάθημα.' : 'Please select a subject.',
        type: SnackBarType.error,
      );
      return;
    }
    setState(() => _isSavingExam = true);
    try {
      final exam = Exam(
        id: '',
        subject: _examSubject!,
        date: _examDate,
        classId: user.scheduleExamClassId,
      );
      await ref.read(dashboardRepositoryProvider).addExam(exam);
      if (mounted) {
        setState(() {
          _examSubject = null;
          _examDate = DateTime.now().add(const Duration(days: 7));
        });
        CustomSnackBar.show(
          context: context,
          message: lang == 'el' ? 'Εξέταση προστέθηκε!' : 'Exam added!',
          type: SnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el' ? 'Σφάλμα αποθήκευσης.' : 'Save error.',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingExam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox(width: 340);
        final s = S(user.preferredLanguage);
        return Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Mini profile card ────────────────────────────────────────
              GlassContainer(
                animate: false,
                padding: const EdgeInsets.all(14),
                borderRadius: 18,
                child: Row(
                  children: [
                    UserAvatar(
                      profilePictureUrl: user.profilePictureUrl,
                      fullName: user.fullName,
                      radius: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.currentClass ??
                                (s.lang == 'el' ? 'Μαθητής' : 'Student'),
                            style: TextStyle(
                              color: context.brand.neutralGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Quick Access tab bar ─────────────────────────────────────
              GlassContainer(
                animate: false,
                padding: const EdgeInsets.all(4),
                borderRadius: 16,
                child: Row(
                  children: [
                    _tabButton(
                      0,
                      Icons.chat_bubble_outline_rounded,
                      s.lang == 'el' ? 'AI Chat' : 'AI Chat',
                    ),
                    _tabButton(
                      1,
                      Icons.notes_rounded,
                      s.lang == 'el' ? 'Σημειώσεις' : 'Notes',
                    ),
                    _tabButton(
                      2,
                      Icons.calendar_today_outlined,
                      s.lang == 'el' ? 'Εξέταση' : 'Exam',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Tab content (fills remaining space) ──────────────────────
              Expanded(
                child: GlassContainer(
                  animate: false,
                  padding: EdgeInsets.zero,
                  borderRadius: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _selectedTab == 0
                        ? _DesktopAiChatTab(
                            s: s,
                            chatController: _chatController,
                            chatScrollController: _chatScrollController,
                            isAiSending: _isAiSending,
                            onSend: _sendChatMessage,
                          )
                        : _selectedTab == 1
                        ? _buildSmartNotesTab(s)
                        : _buildAddExamTab(s, user),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(width: 340),
      error: (_, __) => const SizedBox(width: 340),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: LiquidTouch(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? context.brand.darkText
                    : context.brand.neutralGrey,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? context.brand.darkText
                      : context.brand.neutralGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Smart Notes Tab ─────────────────────────────────────────────────────────
  Widget _buildSmartNotesTab(S s) {
    final notesState = ref.watch(smartNotesProvider);
    final lastInteraction = notesState.interactions.isNotEmpty
        ? notesState.interactions.last
        : null;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 15,
                color: context.brand.royalLavender,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.lang == 'el' ? 'Έξυπνες Σημειώσεις' : 'Smart Notes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: context.brand.neutralGrey,
                ),
                tooltip: s.lang == 'el' ? 'Άνοιγμα' : 'Open',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartNotesScreen()),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Last note output
        if (lastInteraction != null && !notesState.isLoading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: lastInteraction.cards
                  .take(2)
                  .map(
                    (card) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (card.title.isNotEmpty)
                            Text(
                              card.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          if (card.content.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              card.content,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.brand.neutralGrey,
                                height: 1.4,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        else if (notesState.isLoading || _isProcessingNotes)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.brand.royalLavender,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Επεξεργασία...',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.brand.neutralGrey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 36,
                      color: context.brand.neutralGrey.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.lang == 'el'
                          ? 'Γράψε κείμενο για να φτιάξω σημειώσεις'
                          : 'Write text to generate notes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.brand.neutralGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (notesState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              notesState.error!,
              style: TextStyle(fontSize: 11, color: context.brand.dangerRose),
            ),
          ),

        // Input + Process button
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Column(
            children: [
              TextField(
                controller: _notesController,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(
                  hintText: s.lang == 'el'
                      ? 'Επικόλλησε κείμενο ή θέμα...'
                      : 'Paste text or topic...',
                  hintStyle: TextStyle(
                    fontSize: 11,
                    color: context.brand.neutralGrey,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: LiquidTouch(
                  onTap: _isProcessingNotes ? () {} : _processNotes,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isProcessingNotes
                          ? context.brand.neutralGrey.withValues(alpha: 0.2)
                          : context.brand.royalLavender.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isProcessingNotes
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.brand.royalLavender,
                              ),
                            )
                          : Text(
                              s.lang == 'el'
                                  ? 'Δημιουργία Σημειώσεων'
                                  : 'Generate Notes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.brand.royalLavender,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Add Exam Tab ─────────────────────────────────────────────────────────────
  Widget _buildAddExamTab(S s, AppUser user) {
    final dateStr = '${_examDate.day}/${_examDate.month}/${_examDate.year}';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 15,
                color: context.brand.royalLavender,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.lang == 'el' ? 'Προσθήκη Εξέτασης' : 'Add Exam',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subject picker
                Text(
                  s.lang == 'el' ? 'Μάθημα' : 'Subject',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.brand.neutralGrey,
                  ),
                ),
                const SizedBox(height: 6),
                LiquidTouch(
                  onTap: () async {
                    final picked = await showSubjectPickerDialog(
                      context: context,
                      subjects: user.subjects,
                      title: s.lang == 'el'
                          ? 'Επίλεξε Μάθημα'
                          : 'Select Subject',
                      currentSubject: _examSubject,
                    );
                    if (picked != null && mounted) {
                      setState(() => _examSubject = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _examSubject ??
                                (s.lang == 'el'
                                    ? 'Επίλεξε μάθημα...'
                                    : 'Select subject...'),
                            style: TextStyle(
                              fontSize: 13,
                              color: _examSubject != null
                                  ? context.brand.darkText
                                  : context.brand.neutralGrey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          size: 18,
                          color: context.brand.neutralGrey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Date picker
                Text(
                  s.lang == 'el' ? 'Ημερομηνία' : 'Date',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.brand.neutralGrey,
                  ),
                ),
                const SizedBox(height: 6),
                LiquidTouch(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _examDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: context.brand.primaryPurple,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: context.brand.darkText,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null && mounted) {
                      setState(() => _examDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 15,
                          color: context.brand.neutralGrey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.brand.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Save button
                LiquidTouch(
                  onTap: _isSavingExam ? () {} : () => _saveExam(user, s.lang),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isSavingExam
                            ? [
                                context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                                context.brand.neutralGrey.withValues(
                                  alpha: 0.3,
                                ),
                              ]
                            : [
                                context.brand.royalLavender,
                                const Color(0xFFB1A2FB),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isSavingExam
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              s.lang == 'el'
                                  ? 'Αποθήκευση Εξέτασης'
                                  : 'Save Exam',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
    );
  }
}

/// Isolated AI chat tab — [chatProvider] watch scoped here so message
/// streaming does not rebuild the profile card or tab bar.
class _DesktopAiChatTab extends ConsumerWidget {
  final S s;
  final TextEditingController chatController;
  final ScrollController chatScrollController;
  final bool isAiSending;
  final VoidCallback onSend;

  const _DesktopAiChatTab({
    required this.s,
    required this.chatController,
    required this.chatScrollController,
    required this.isAiSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 15,
                color: context.brand.royalLavender,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.lang == 'el' ? 'AI Βοηθός' : 'AI Assistant',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: context.brand.neutralGrey,
                ),
                tooltip: s.lang == 'el' ? 'Άνοιγμα' : 'Open',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyBuddyScreen()),
                ),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 36,
                          color: context.brand.neutralGrey.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.lang == 'el'
                              ? 'Ρώτησέ με οτιδήποτε!'
                              : 'Ask me anything!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: chatScrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, i) =>
                      _DesktopAiChatBubble(message: messages[i]),
                ),
        ),
        if (isAiSending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.brand.royalLavender,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.lang == 'el' ? 'Σκέφτομαι...' : 'Thinking...',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.brand.neutralGrey,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatController,
                  style: const TextStyle(fontSize: 13),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: s.lang == 'el'
                        ? 'Γράψε μήνυμα...'
                        : 'Type a message...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: context.brand.neutralGrey,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isAiSending
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 36,
                        height: 36,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.brand.royalLavender,
                            ),
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('send'),
                        onTap: onSend,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.brand.royalLavender,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopAiChatBubble extends StatelessWidget {
  final AIChatMessage message;

  const _DesktopAiChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isUser
                  ? context.brand.royalLavender.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: 12,
                color: isUser ? Colors.white : context.brand.darkText,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
