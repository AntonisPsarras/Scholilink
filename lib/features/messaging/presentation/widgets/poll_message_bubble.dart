import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/glass_container.dart';
import '../../../../shared/l10n.dart';
import '../../../../theme/app_theme.dart';
import '../../data/chat_providers.dart';
import '../../data/chat_service.dart';
import '../../domain/chat_message_model.dart';
import '../../../../shared/widgets/custom_snackbar.dart';

/// Poll card for classroom chat. Watches [pollProvider] (autoDispose) so the
/// Firestore subscription ends when this row is disposed off-screen.
class PollMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final String classroomId;
  final String userId;
  final bool isMe;
  final String lang;

  const PollMessageBubble({
    super.key,
    required this.message,
    required this.classroomId,
    required this.userId,
    required this.isMe,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);
    final pollKey = '$classroomId/${message.pollId}';
    final pollAsync = ref.watch(pollProvider(pollKey));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GlassContainer(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A3D)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: 16,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.all(14),
          child: pollAsync.when(
            data: (poll) {
              if (poll == null) {
                return Text(
                  s.pollNotFound,
                  style: TextStyle(color: context.brand.neutralGrey),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.poll,
                        size: 18,
                        color: context.brand.royalLavender,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.poll,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.brand.royalLavender,
                        ),
                      ),
                      if (poll.isAnonymous) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s.anonymous,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.brand.neutralGrey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    poll.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(poll.options.length, (i) {
                    final opt = poll.options[i];
                    final hasVoted = opt.voterIds.contains(userId);
                    final totalVotes = poll.totalVotes;
                    final percentage = totalVotes > 0
                        ? (opt.voterIds.length / totalVotes)
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () async {
                          try {
                            await ref
                                .read(chatServiceProvider)
                                .votePoll(classroomId, poll.id, i, userId);
                          } catch (e) {
                            if (context.mounted) {
                              CustomSnackBar.show(
                                context: context,
                                message: s.pollVoteFailed,
                                type: SnackBarType.error,
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasVoted
                                  ? context.brand.royalLavender
                                  : context.brand.neutralGrey.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            color: hasVoted
                                ? context.brand.royalLavender.withValues(
                                    alpha: 0.08,
                                  )
                                : Colors.transparent,
                          ),
                          child: Stack(
                            children: [
                              if (totalVotes > 0)
                                Positioned.fill(
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: percentage,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: context.brand.royalLavender
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      opt.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: hasVoted
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(percentage * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.brand.neutralGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    '${poll.totalVotes} ${s.votes}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.brand.neutralGrey,
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
