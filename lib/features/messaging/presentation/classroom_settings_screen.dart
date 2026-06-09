import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../classroom/data/classroom_service.dart';
import '../../classroom/data/classroom_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/image_utils.dart';
import '../../../shared/storage_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';

import '../../../shared/widgets/user_profile_sheet.dart';

class ClassroomSettingsScreen extends ConsumerStatefulWidget {
  final String classroomId;
  final String lang;

  const ClassroomSettingsScreen({
    super.key,
    required this.classroomId,
    required this.lang,
  });

  @override
  ConsumerState<ClassroomSettingsScreen> createState() =>
      _ClassroomSettingsScreenState();
}

class _ClassroomSettingsScreenState
    extends ConsumerState<ClassroomSettingsScreen> {
  Map<String, Map<String, String>> _memberInfo = {};
  bool _membersLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final classroomAsync = ref.read(selectedClassroomProvider);
    final classroom = classroomAsync.valueOrNull;
    if (classroom == null) return;

    final members = await ref
        .read(classroomServiceProvider)
        .getMembers(classroom.members);
    if (!mounted) return;
    setState(() {
      _memberInfo = {
        for (final m in members)
          if ((m['uid'] ?? '').toString().isNotEmpty) m['uid']!: m,
      };
      _membersLoaded = true;
    });
  }

  String _getMemberName(String memberId, bool isCurrentUser, S s) {
    final info = _memberInfo[memberId];
    final name = info?['fullName'] ?? memberId.substring(0, 8);
    return isCurrentUser ? '$name (${s.you})' : name;
  }

  Widget _buildMemberAvatar(String memberId, bool isMemberAdmin) {
    final info = _memberInfo[memberId];
    final profileUrl = info?['profilePictureUrl'];
    final name = info?['fullName'] ?? memberId.substring(0, 8);

    return UserAvatar(
      profilePictureUrl: profileUrl,
      fullName: name,
      radius: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final authState = ref.watch(authStateProvider);
    final classroomAsync = ref.watch(selectedClassroomProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return classroomAsync.when(
          data: (classroom) {
            if (classroom == null) {
              return Scaffold(
                appBar: AppBar(title: Text(s.settings)),
                body: Center(child: Text(s.classroomNotFound)),
              );
            }

            final isAdmin = classroom.isAdmin(user.uid);

            return Scaffold(
              backgroundColor: context.brand.backgroundSnow,
              appBar: AppBar(
                title: Text(s.classroomSettings),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // Classroom info card
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Classroom avatar
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: classroom.profileImageUrl == null
                                      ? LinearGradient(
                                          colors: [
                                            context.brand.royalLavender,
                                            context.brand.royalLavender
                                                .withValues(alpha: 0.6),
                                          ],
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: classroom.profileImageUrl != null
                                    ? (isBase64DataUri(
                                            classroom.profileImageUrl!,
                                          )
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
                                                  imageUrl: classroom
                                                      .profileImageUrl!,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: px,
                                                  memCacheHeight: px,
                                                  maxWidthDiskCache: px,
                                                  maxHeightDiskCache: px,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                        width: 56,
                                                        height: 56,
                                                        color: context
                                                            .brand
                                                            .royalLavender
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                      ),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(
                                                        Icons.school,
                                                        size: 28,
                                                      ),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classroom.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    if (classroom.description.isNotEmpty)
                                      Text(
                                        classroom.description,
                                        style: TextStyle(
                                          color: context.brand.neutralGrey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    Text(
                                      '${classroom.members.length} ${s.members}',
                                      style: TextStyle(
                                        color: context.brand.neutralGrey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAdmin)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: context.brand.royalLavender,
                                  ),
                                  onPressed: () => _showEditDialog(
                                    context,
                                    ref,
                                    classroom.name,
                                    classroom.description,
                                    classroom.profileImageUrl,
                                    s,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Invite code
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: classroom.inviteCode),
                              );
                              CustomSnackBar.show(
                                context: context,
                                message: s.inviteCodeCopied,
                                type: SnackBarType.success,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: context.brand.sunsetWarning.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.vpn_key_rounded,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${s.inviteCode}: ${classroom.inviteCode}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: context.brand.neutralGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Members header
                  Text(
                    s.members,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Members list
                  if (!_membersLoaded)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ...classroom.members.map((memberId) {
                      final isMemberAdmin = classroom.isAdmin(memberId);
                      final isCurrentUser = memberId == user.uid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.25),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  UserProfileSheet(userId: memberId),
                            );
                          },
                          leading: _buildMemberAvatar(memberId, isMemberAdmin),
                          title: Text(
                            _getMemberName(memberId, isCurrentUser, s),
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: isMemberAdmin
                              ? Text(
                                  s.admin,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  s.member,
                                  style: TextStyle(
                                    color: context.brand.neutralGrey,
                                    fontSize: 12,
                                  ),
                                ),
                          trailing: isAdmin && !isCurrentUser
                              ? PopupMenuButton<String>(
                                  onSelected: (action) => _handleMemberAction(
                                    context,
                                    ref,
                                    action,
                                    user.uid,
                                    memberId,
                                    s,
                                  ),
                                  itemBuilder: (ctx) => [
                                    if (!isMemberAdmin)
                                      PopupMenuItem(
                                        value: 'promote',
                                        child: Text(s.promoteToAdmin),
                                      ),
                                    if (isMemberAdmin &&
                                        classroom.adminIds.length > 1)
                                      PopupMenuItem(
                                        value: 'demote',
                                        child: Text(s.demoteAdmin),
                                      ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text(
                                        s.removeMember,
                                        style: TextStyle(
                                          color: context.brand.errorRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Leave classroom
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _leaveClassroom(context, ref, user.uid, s),
                      icon: Icon(
                        Icons.exit_to_app,
                        color: context.brand.errorRed,
                      ),
                      label: Text(s.leaveClassroom),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.brand.errorRed,
                        side: BorderSide(color: context.brand.errorRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Delete classroom (admin only)
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _deleteClassroom(context, ref, user.uid, s),
                        icon: const Icon(Icons.delete_forever),
                        label: Text(s.deleteClassroom),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.brand.errorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => Scaffold(body: Center(child: Text(s.error))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentDesc,
    String? currentImage,
    S s,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final descCtrl = TextEditingController(text: currentDesc);
    String? pendingImageUrl = currentImage;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dlgCs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: dlgCs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: dlgCs.outline.withValues(alpha: 0.35)),
            ),
            title: Text(
              s.editClassroom,
              style: TextStyle(color: dlgCs.onSurface),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Classroom avatar picker
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 75,
                              maxWidth: 800,
                              maxHeight: 800,
                            );
                            if (picked != null) {
                              setDialogState(() => isUploading = true);
                              try {
                                final bytes = await picked.readAsBytes();
                                final ext = picked.name.split('.').last;
                                final storageService = ref.read(
                                  storageServiceProvider,
                                );
                                final currentUid =
                                    FirebaseAuth.instance.currentUser!.uid;
                                final url = await storageService
                                    .uploadImageBytes(
                                      bytes,
                                      'classroom_images',
                                      ext: ext,
                                      ownerUid: currentUid,
                                      scopeId: widget.classroomId,
                                    );
                                setDialogState(() => pendingImageUrl = url);
                              } catch (e) {
                                if (ctx.mounted) {
                                  CustomSnackBar.show(
                                    context: ctx,
                                    message: 'Upload failed: $e',
                                    type: SnackBarType.error,
                                  );
                                }
                              }
                              setDialogState(() => isUploading = false);
                            }
                          },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: pendingImageUrl == null
                                ? LinearGradient(
                                    colors: [
                                      context.brand.royalLavender,
                                      context.brand.royalLavender.withValues(
                                        alpha: 0.6,
                                      ),
                                    ],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isUploading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : (pendingImageUrl != null
                                    ? (isBase64DataUri(pendingImageUrl!)
                                          ? Image.memory(
                                              Uint8List.fromList(
                                                decodeBase64DataUri(
                                                  pendingImageUrl!,
                                                ),
                                              ),
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            )
                                          : Builder(
                                              builder: (context) {
                                                final px =
                                                    (80 *
                                                            MediaQuery.devicePixelRatioOf(
                                                              context,
                                                            ))
                                                        .round();
                                                return CachedNetworkImage(
                                                  imageUrl: pendingImageUrl!,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: px,
                                                  memCacheHeight: px,
                                                  maxWidthDiskCache: px,
                                                  maxHeightDiskCache: px,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                        width: 80,
                                                        height: 80,
                                                        color: context
                                                            .brand
                                                            .royalLavender
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                      ),
                                                  errorWidget: (_, __, ___) =>
                                                      const Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 40,
                                                      ),
                                                );
                                              },
                                            ))
                                    : Center(
                                        child: Text(
                                          currentName.isNotEmpty
                                              ? currentName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.brand.royalLavender,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: dlgCs.onSurface),
                    decoration: InputDecoration(
                      labelText: s.classroomName,
                      labelStyle: TextStyle(color: dlgCs.onSurfaceVariant),
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark
                          ? context.brand.inputFill
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: dlgCs.onSurface),
                    decoration: InputDecoration(
                      labelText: s.description,
                      labelStyle: TextStyle(color: dlgCs.onSurfaceVariant),
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark
                          ? context.brand.inputFill
                          : Colors.white,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  s.cancel,
                  style: TextStyle(color: dlgCs.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        final authState = ref.read(authStateProvider);
                        final user = authState.valueOrNull;
                        if (user != null) {
                          await ref
                              .read(classroomServiceProvider)
                              .updateClassroom(
                                widget.classroomId,
                                user.uid,
                                name: nameCtrl.text,
                                description: descCtrl.text,
                                profileImageUrl: pendingImageUrl,
                              );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brand.royalLavender,
                  foregroundColor: Colors.white,
                ),
                child: Text(s.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String userId,
    String targetId,
    S s,
  ) async {
    final service = ref.read(classroomServiceProvider);
    try {
      switch (action) {
        case 'promote':
          await service.promoteToAdmin(widget.classroomId, userId, targetId);
          break;
        case 'demote':
          await service.demoteAdmin(widget.classroomId, userId, targetId);
          break;
        case 'remove':
          await service.removeMember(widget.classroomId, userId, targetId);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(
          context: context,
          message: e.toString(),
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _leaveClassroom(
    BuildContext context,
    WidgetRef ref,
    String userId,
    S s,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.leaveClassroom),
        content: Text(s.leaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(s.leave),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(classroomServiceProvider)
          .leaveClassroom(widget.classroomId, userId);
      if (context.mounted) {
        Navigator.pop(context); // Pop settings
        Navigator.pop(context); // Pop chat
      }
    }
  }

  Future<void> _deleteClassroom(
    BuildContext context,
    WidgetRef ref,
    String userId,
    S s,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteClassroom),
        content: Text(s.deleteClassroomConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(classroomServiceProvider)
          .deleteClassroom(widget.classroomId, userId);
      if (context.mounted) {
        Navigator.pop(context); // Pop settings
        Navigator.pop(context); // Pop chat
      }
    }
  }
}
