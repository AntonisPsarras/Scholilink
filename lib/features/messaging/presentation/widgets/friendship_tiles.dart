import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/user_profile_sheet.dart';
import '../../../../shared/l10n.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/user_public_sync.dart';
import '../../../auth/domain/user_model.dart';
import '../../../classroom/data/friendship_service.dart';
import '../../../../shared/widgets/custom_snackbar.dart';

class PendingRequestTile extends ConsumerStatefulWidget {
  final String senderUid;
  final String lang;
  final bool compact;

  const PendingRequestTile({
    super.key,
    required this.senderUid,
    required this.lang,
    this.compact = false,
  });

  @override
  ConsumerState<PendingRequestTile> createState() => _PendingRequestTileState();
}

class _PendingRequestTileState extends ConsumerState<PendingRequestTile> {
  AppUser? _sender;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadSender();
  }

  Future<void> _loadSender() async {
    final doc = await FirebaseFirestore.instance
        .collection(kUserPublicCollection)
        .doc(widget.senderUid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _sender = appUserFromPublicMap(doc.data()!, doc.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    if (_sender == null || currentUid == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.only(bottom: widget.compact ? 4 : 8),
      elevation: widget.compact ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: widget.compact ? Colors.transparent : null,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                UserProfileSheet(userId: widget.senderUid),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: widget.compact
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 0)
              : null,
          leading: UserAvatar(
            profilePictureUrl: _sender!.profilePictureUrl,
            fullName: _sender!.fullName,
            radius: widget.compact ? 18 : 20,
          ),
          title: Text(
            _sender!.fullName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.compact ? 14 : 16,
            ),
          ),
          subtitle: Text(
            s.newRequest,
            style: TextStyle(
              fontSize: widget.compact ? 11 : 12,
              color: context.brand.mintSuccess,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: context.brand.mintSuccess,
                  size: widget.compact ? 20 : 24,
                ),
                tooltip: widget.compact ? null : s.accept,
                padding: widget.compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(8.0),
                constraints: const BoxConstraints(),
                onPressed: _actionInProgress
                    ? null
                    : () async {
                        if (!mounted) return;
                        setState(() => _actionInProgress = true);
                        try {
                          await ref
                              .read(friendshipServiceProvider)
                              .acceptFriendRequest(
                                currentUid,
                                widget.senderUid,
                              );
                          if (context.mounted) {
                            CustomSnackBar.show(
                              context: context,
                              message: widget.lang == 'el'
                                  ? 'Αποδεχτήκατε το αίτημα από τον/την ${_sender!.fullName}!'
                                  : 'Accepted request from ${_sender!.fullName}!',
                              type: SnackBarType.success,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackBar.show(
                              context: context,
                              message: s.error,
                              type: SnackBarType.error,
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _actionInProgress = false);
                          }
                        }
                      },
              ),
              if (!widget.compact) const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.cancel,
                  color: context.brand.sunsetWarning,
                  size: widget.compact ? 20 : 24,
                ),
                tooltip: widget.compact ? null : s.decline,
                padding: widget.compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.all(8.0),
                constraints: const BoxConstraints(),
                onPressed: _actionInProgress
                    ? null
                    : () async {
                        if (!mounted) return;
                        setState(() => _actionInProgress = true);
                        try {
                          await ref
                              .read(friendshipServiceProvider)
                              .declineFriendRequest(
                                currentUid,
                                widget.senderUid,
                              );
                        } catch (e) {
                          if (context.mounted) {
                            CustomSnackBar.show(
                              context: context,
                              message: s.error,
                              type: SnackBarType.error,
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _actionInProgress = false);
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SentRequestTile extends ConsumerStatefulWidget {
  final String receiverUid;
  final String lang;

  const SentRequestTile({
    super.key,
    required this.receiverUid,
    required this.lang,
  });

  @override
  ConsumerState<SentRequestTile> createState() => _SentRequestTileState();
}

class _SentRequestTileState extends ConsumerState<SentRequestTile> {
  AppUser? _receiver;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadReceiver();
  }

  Future<void> _loadReceiver() async {
    final doc = await FirebaseFirestore.instance
        .collection(kUserPublicCollection)
        .doc(widget.receiverUid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _receiver = appUserFromPublicMap(doc.data()!, doc.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (_receiver == null || currentUid == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) =>
                UserProfileSheet(userId: widget.receiverUid),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: UserAvatar(
            profilePictureUrl: _receiver!.profilePictureUrl,
            fullName: _receiver!.fullName,
            radius: 20,
          ),
          title: Text(
            _receiver!.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            widget.lang == 'el' ? 'Αίτημα στάλθηκε' : 'Request sent',
            style: TextStyle(fontSize: 12, color: context.brand.sunsetWarning),
          ),
          trailing: TextButton.icon(
            icon: _actionInProgress
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.brand.sunsetWarning,
                    ),
                  )
                : const Icon(Icons.close, size: 16),
            label: Text(widget.lang == 'el' ? 'Ακύρωση' : 'Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: context.brand.sunsetWarning,
            ),
            onPressed: _actionInProgress
                ? null
                : () async {
                    if (!mounted) return;
                    setState(() => _actionInProgress = true);
                    try {
                      await ref
                          .read(friendshipServiceProvider)
                          .cancelFriendRequest(
                            currentUid,
                            widget.receiverUid,
                          );
                      if (context.mounted) {
                        CustomSnackBar.show(
                          context: context,
                          message: widget.lang == 'el'
                              ? 'Το αίτημα ακυρώθηκε.'
                              : 'Request cancelled.',
                          type: SnackBarType.success,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        CustomSnackBar.show(
                          context: context,
                          message: s.error,
                          type: SnackBarType.error,
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _actionInProgress = false);
                      }
                    }
                  },
          ),
        ),
      ),
    );
  }
}
