import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_service.dart';
import '../domain/chat_message_model.dart';
import '../domain/poll_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';

void showCreatePollDialog({
  required BuildContext context,
  required String classroomId,
  required String userId,
  required String userName,
  required String lang,
  required WidgetRef ref,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.48)
        : null,
    builder: (ctx) => _CreatePollSheet(
      classroomId: classroomId,
      userId: userId,
      userName: userName,
      lang: lang,
    ),
  );
}

class _CreatePollSheet extends ConsumerStatefulWidget {
  final String classroomId;
  final String userId;
  final String userName;
  final String lang;

  const _CreatePollSheet({
    required this.classroomId,
    required this.userId,
    required this.userName,
    required this.lang,
  });

  @override
  ConsumerState<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<_CreatePollSheet> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _isAnonymous = false;
  bool _allowMultiple = false;
  bool _loading = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? cs.surface : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: dark
                ? cs.outline.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.brand.neutralGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.createPoll,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Question
            TextField(
              controller: _questionController,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                labelText: s.pollQuestion,
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: dark ? context.brand.inputFill : Colors.white,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Options
            Text(
              s.pollOptions,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ..._optionControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: '${s.option} ${i + 1}',
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: dark
                              ? context.brand.inputFill
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: context.brand.errorRed,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _optionControllers[i].dispose();
                            _optionControllers.removeAt(i);
                          });
                        },
                      ),
                  ],
                ),
              );
            }),

            if (_optionControllers.length < 6)
              TextButton.icon(
                onPressed: () {
                  setState(
                    () => _optionControllers.add(TextEditingController()),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(s.addOption),
                style: TextButton.styleFrom(
                  foregroundColor: context.brand.royalLavender,
                ),
              ),

            const SizedBox(height: 12),

            // Toggles
            SwitchListTile(
              title: Text(
                s.anonymousPoll,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
              subtitle: Text(
                s.anonymousPollDesc,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              value: _isAnonymous,
              activeTrackColor: context.brand.royalLavender.withValues(
                alpha: 0.5,
              ),
              activeThumbColor: context.brand.royalLavender,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isAnonymous = val),
            ),
            SwitchListTile(
              title: Text(
                s.allowMultipleVotes,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
              ),
              value: _allowMultiple,
              activeTrackColor: context.brand.royalLavender.withValues(
                alpha: 0.5,
              ),
              activeThumbColor: context.brand.royalLavender,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _allowMultiple = val),
            ),

            const SizedBox(height: 16),

            // Create button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brand.royalLavender,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(s.createPoll),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPoll() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) return;

    setState(() => _loading = true);

    try {
      final poll = Poll(
        id: '',
        classroomId: widget.classroomId,
        creatorId: widget.userId,
        creatorName: widget.userName,
        question: question,
        options: options.map((t) => PollOption(text: t)).toList(),
        isAnonymous: _isAnonymous,
        allowMultiple: _allowMultiple,
        createdAt: DateTime.now(),
      );

      final pollId = await ref
          .read(chatServiceProvider)
          .createPoll(widget.classroomId, poll);

      // Send a poll message in chat
      final msg = ChatMessage(
        id: '',
        classroomId: widget.classroomId,
        authorId: widget.userId,
        authorName: widget.userName,
        type: MessageType.poll,
        pollId: pollId,
        text: question,
        timestamp: DateTime.now(),
      );
      await ref.read(chatServiceProvider).sendMessage(widget.classroomId, msg);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
    }
  }
}
