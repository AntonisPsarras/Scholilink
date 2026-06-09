import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/classroom_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/image_utils.dart';
import '../../../shared/app_shell_insets.dart';
import '../../../shared/responsive_layout.dart';
import '../../../shared/desktop_page_shell.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'create_join_dialog.dart';
import '../../messaging/presentation/classroom_chat_screen.dart';
import '../../messaging/presentation/friends_view.dart';
import '../../messaging/presentation/add_friend_dialog.dart';

class ClassroomScreen extends ConsumerWidget {
  const ClassroomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Please log in'));
        }

        final s = S(user.preferredLanguage);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.transparent, // Allow global gradient
            appBar: AppBar(
              title: Text(s.myClassrooms),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: Icon(
                        Icons.add_rounded,
                        color: context.brand.royalLavender,
                      ),
                      tooltip: DefaultTabController.of(context).index == 0
                          ? s.createTooltip
                          : s.addFriend,
                      onPressed: () {
                        if (DefaultTabController.of(context).index == 0) {
                          showCreateJoinDialog(
                            context,
                            ref,
                            user.uid,
                            user.preferredLanguage,
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => AddFriendDialog(
                              lang: user.preferredLanguage,
                              currentUserId: user.uid,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
              bottom: TabBar(
                indicatorColor: context.brand.royalLavender,
                labelColor: context.brand.royalLavender,
                unselectedLabelColor: context.brand.neutralGrey,
                tabs: [
                  Tab(text: s.classroom, icon: const Icon(Icons.groups)),
                  Tab(text: s.friends, icon: const Icon(Icons.person)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Tab 1: Classrooms
                Consumer(
                  builder: (context, ref, child) {
                    final classroomsAsync = ref.watch(userClassroomsProvider);
                    return classroomsAsync.when(
                      data: (classrooms) {
                        if (classrooms.isEmpty) {
                          return _NoClassroomView(
                            lang: user.preferredLanguage,
                            userId: user.uid,
                          );
                        }
                        return _ClassroomListView(
                          classrooms: classrooms,
                          lang: user.preferredLanguage,
                          userId: user.uid,
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) =>
                          Center(child: Text('${s.error}: $err')),
                    );
                  },
                ),
                // Tab 2: Friends
                FriendsView(
                  lang: user.preferredLanguage,
                  currentUserId: user.uid,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

class _NoClassroomView extends ConsumerWidget {
  final String lang;
  final String userId;
  const _NoClassroomView({required this.lang, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);
    return Scaffold(
      backgroundColor: Colors.transparent, // Allow global gradient
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.brand.royalLavender.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 64,
                  color: context.brand.royalLavender,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                s.classroom,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 12),
              Text(
                s.noClassroomYet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.brand.neutralGrey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      showCreateJoinDialog(context, ref, userId, lang),
                  icon: const Icon(Icons.add),
                  label: Text(s.createClassroom),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.brand.royalLavender,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showCreateJoinDialog(
                    context,
                    ref,
                    userId,
                    lang,
                    initialTab: 1,
                  ),
                  icon: const Icon(Icons.login),
                  label: Text(s.joinClassroom),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand.royalLavender,
                    side: BorderSide(color: context.brand.royalLavender),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomListView extends ConsumerWidget {
  final List<dynamic> classrooms;
  final String lang;
  final String userId;

  const _ClassroomListView({
    required this.classrooms,
    required this.lang,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(lang);

    final bottomPad = shellBottomContentPadding(context);

    return Scaffold(
      backgroundColor: Colors.transparent, // Allow global gradient
      body: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
        itemCount: classrooms.length,
        itemBuilder: (context, index) {
          final classroom = classrooms[index];
          final isAdmin = classroom.adminIds.contains(userId);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                ref.read(selectedClassroomIdProvider.notifier).state =
                    classroom.id;
                final chatScreen = ClassroomChatScreen(
                  classroomId: classroom.id,
                  lang: lang,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResponsiveLayout.isDesktop(context)
                        ? DesktopPageShell(
                            selectedNavIndex: 3,
                            child: chatScreen,
                          )
                        : chatScreen,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: classroom.profileImageUrl == null
                            ? LinearGradient(
                                colors: [
                                  context.brand.royalLavender,
                                  context.brand.royalLavender.withValues(
                                    alpha: 0.6,
                                  ),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: classroom.profileImageUrl != null
                          ? (isBase64DataUri(classroom.profileImageUrl!)
                                ? Image.memory(
                                    Uint8List.fromList(
                                      decodeBase64DataUri(
                                        classroom.profileImageUrl!,
                                      ),
                                    ),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  )
                                : Builder(
                                    builder: (context) {
                                      final px =
                                          (56 *
                                                  MediaQuery.devicePixelRatioOf(
                                                    context,
                                                  ))
                                              .round();
                                      return CachedNetworkImage(
                                        imageUrl: classroom.profileImageUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        memCacheWidth: px,
                                        memCacheHeight: px,
                                        maxWidthDiskCache: px,
                                        maxHeightDiskCache: px,
                                        placeholder: (_, __) => Container(
                                          width: 56,
                                          height: 56,
                                          color: context.brand.royalLavender
                                              .withValues(alpha: 0.2),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.school, size: 28),
                                      );
                                    },
                                  ))
                          : Center(
                              child: Text(
                                classroom.name.isNotEmpty
                                    ? classroom.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  classroom.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.brand.sunsetWarning
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    s.admin,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${classroom.members.length} ${s.members}',
                            style: TextStyle(
                              color: context.brand.neutralGrey,
                              fontSize: 13,
                            ),
                          ),
                          if (classroom.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              classroom.description,
                              style: TextStyle(
                                color: context.brand.neutralGrey,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Copy invite code
                    IconButton(
                      icon: Icon(
                        Icons.vpn_key_rounded,
                        size: 20,
                        color: context.brand.neutralGrey,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: classroom.inviteCode),
                        );
                        CustomSnackBar.show(
                          context: context,
                          message: s.inviteCodeCopied,
                          type: SnackBarType.success,
                        );
                      },
                      tooltip: s.inviteCode,
                    ),
                    Icon(Icons.chevron_right, color: context.brand.neutralGrey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
