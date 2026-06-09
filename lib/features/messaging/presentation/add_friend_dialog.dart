import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/l10n.dart';
import '../../../theme/app_theme.dart';
import '../../classroom/data/friendship_service.dart';
import '../../auth/domain/user_model.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/data/user_public_sync.dart';

class AddFriendDialog extends ConsumerStatefulWidget {
  final String lang;
  final String currentUserId;

  const AddFriendDialog({
    super.key,
    required this.lang,
    required this.currentUserId,
  });

  @override
  ConsumerState<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends ConsumerState<AddFriendDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<AppUser> _searchResults = [];

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final usersSnap = await firestore
          .collection(kUserPublicCollection)
          .orderBy('fullName')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(25)
          .get();

      final queryLower = query.toLowerCase();
      final results = <AppUser>[];
      final seenUids = <String>{};

      for (final doc in usersSnap.docs) {
        final user = appUserFromPublicMap(doc.data(), doc.id);
        if (user.uid == widget.currentUserId) continue;

        final nameMatch = user.fullName.toLowerCase().contains(queryLower);
        if (nameMatch &&
            !seenUids.contains(user.uid) &&
            user.fullName.isNotEmpty) {
          results.add(user);
          seenUids.add(user.uid);
        }
      }

      setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(String receiverId) async {
    try {
      final success = await ref
          .read(friendshipServiceProvider)
          .sendFriendRequest(widget.currentUserId, receiverId);

      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: success ? S(widget.lang).requestSent : S(widget.lang).requestFailed,
          type: success ? SnackBarType.success : SnackBarType.error,
        );
        if (success) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // Show the actual exception message to the user, like "Friendship already exists"
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        CustomSnackBar.show(
          context: context,
          message: '${S(widget.lang).requestFailed}: $errorMessage',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);

    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cs.surface,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.addFriend,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: s.friendUidHint,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: cs.onSurfaceVariant),
                    onPressed: _searchUsers,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ).applyDefaults(Theme.of(context).inputDecorationTheme),
                onSubmitted: (_) => _searchUsers(),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_searchResults.isEmpty &&
                            _searchController.text.isNotEmpty)
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              s.noUsersFound,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: UserAvatar(
                                profilePictureUrl: user.profilePictureUrl,
                                fullName: user.fullName,
                                radius: 20,
                              ),
                              title: Text(
                                user.fullName,
                                style: TextStyle(color: cs.onSurface),
                              ),
                              subtitle: Text(
                                user.currentClass ??
                                    (widget.lang == 'el'
                                        ? 'Μαθητής'
                                        : 'Student'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.brand.royalLavender,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _sendRequest(user.uid),
                                child: Text(s.sendRequest),
                              ),
                            );
                          },
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
