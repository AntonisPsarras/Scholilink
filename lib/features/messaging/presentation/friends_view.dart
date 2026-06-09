import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../classroom/data/classroom_providers.dart';
import '../data/direct_message_service.dart';
import '../domain/direct_chat_model.dart';
import '../../auth/domain/user_model.dart';
import 'direct_chat_screen.dart';
import 'widgets/friendship_tiles.dart';
import '../../../shared/widgets/user_avatar.dart';

class FriendsView extends ConsumerWidget {
  final String lang;
  final String currentUserId;

  const FriendsView({
    super.key,
    required this.lang,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);
    final friendsAsync = ref.watch(friendsProvider);
    final blockedUsers = ref.watch(
      authStateProvider.select(
        (async) => async.valueOrNull?.blockedUsers ?? const <String>[],
      ),
    );
    final pendingUids = ref
        .watch(pendingFriendRequestUidsProvider)
        .where((uid) => !blockedUsers.contains(uid))
        .toList();
    final sentUids = ref.watch(sentFriendRequestUidsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          if (pendingUids.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.pendingRequests,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.brand.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final uid in pendingUids)
                      PendingRequestTile(
                        key: ValueKey(uid),
                        senderUid: uid,
                        lang: lang,
                      ),
                    const Divider(),
                  ],
                ),
              ),
            ),

          if (sentUids.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'el' ? 'Απεσταλμένα αιτήματα' : 'Sent Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.brand.neutralGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final uid in sentUids)
                      SentRequestTile(
                        key: ValueKey(uid),
                        receiverUid: uid,
                        lang: lang,
                      ),
                    const Divider(),
                  ],
                ),
              ),
            ),

          friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: context.brand.neutralGrey.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.noFriendsYet,
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final friend = friends[index];
                    return _FriendTile(
                      key: ValueKey(friend.uid),
                      friend: friend,
                      lang: lang,
                      currentUserId: currentUserId,
                    );
                  }, childCount: friends.length),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    lang == 'el'
                        ? 'Δεν ήταν δυνατή η φόρτωση των φίλων.'
                        : 'Could not load friends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.brand.neutralGrey),
                  ),
                ),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

class _FriendTile extends ConsumerStatefulWidget {
  final AppUser friend;
  final String currentUserId;
  final String lang;

  const _FriendTile({
    super.key,
    required this.friend,
    required this.lang,
    required this.currentUserId,
  });

  @override
  ConsumerState<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends ConsumerState<_FriendTile> {
  DirectChat? _chat;
  StreamSubscription? _chatSub;

  @override
  void initState() {
    super.initState();
    _initChatWatch();
  }

  Future<void> _initChatWatch() async {
    try {
      final chatId = await ref
          .read(directMessageServiceProvider)
          .findDirectChatId(widget.currentUserId, widget.friend.uid);
      if (chatId == null || !mounted) return;

      _chatSub = ref
          .read(directMessageServiceProvider)
          .watchDirectChat(chatId)
          .listen((chat) {
            if (mounted) setState(() => _chat = chat);
          });
    } catch (e) {
      debugPrint('_FriendTile chat watch failed: $e');
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openChat(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(
                profilePictureUrl: widget.friend.profilePictureUrl,
                fullName: widget.friend.fullName,
                radius: 25,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.friend.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_chat != null && _chat!.lastMessageText.isNotEmpty)
                      Text(
                        _chat!.lastMessageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.brand.neutralGrey.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_chat != null &&
                  (_chat!.unreadCounts[widget.currentUserId] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.brand.errorRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_chat!.unreadCounts[widget.currentUserId]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.message_rounded,
                  color: context.brand.royalLavender,
                ),
                onPressed: () => _openChat(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectChatScreen(
          friendId: widget.friend.uid,
          currentUserId: widget.currentUserId,
          friendName: widget.friend.fullName,
          friendAvatar: widget.friend.profilePictureUrl,
          lang: widget.lang,
        ),
      ),
    );
  }
}
