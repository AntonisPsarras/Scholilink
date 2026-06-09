import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../constants/avatar_assets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../../../shared/storage_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  List<String> _achievements = [];
  late String _selectedLanguage;
  String? _pendingProfilePicture;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _bioController = TextEditingController(text: widget.user.bio);
    _achievements = List.from(widget.user.achievements);
    _selectedLanguage = widget.user.preferredLanguage;
    _pendingProfilePicture = widget.user.profilePictureUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S(widget.user.preferredLanguage).lang == 'el'
                    ? 'Αλλαγή Φωτογραφίας προφίλ'
                    : 'Change Profile Picture',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.brand.royalLavender.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: context.brand.royalLavender,
                  ),
                ),
                title: Text(
                  S(widget.user.preferredLanguage).lang == 'el'
                      ? 'Ανέβασμα Εικόνας'
                      : 'Upload Image',
                  style: TextStyle(color: cs.onSurface),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadCustomImage();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.brand.mintSuccess.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.face, color: context.brand.mintSuccess),
                ),
                title: Text(
                  S(widget.user.preferredLanguage).lang == 'el'
                      ? 'Έτοιμα Avatars'
                      : 'Premade Avatars',
                  style: TextStyle(color: cs.onSurface),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showPremadeAvatars();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadCustomImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked != null) {
      if (!mounted) return;
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: S(widget.user.preferredLanguage).lang == 'el'
                ? 'Περικοπή'
                : 'Crop Image',
            toolbarColor: context.brand.royalLavender,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: S(widget.user.preferredLanguage).lang == 'el'
                ? 'Περικοπή'
                : 'Crop Image',
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(context: context),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isUploadingImage = true);
        try {
          final bytes = await croppedFile.readAsBytes();
          final ext = croppedFile.path.split('.').last;
          final storageService = ref.read(storageServiceProvider);
          final url = await storageService.uploadImageBytes(
            bytes,
            'profile_pictures',
            ext: ext,
            ownerUid: widget.user.uid,
          );
          setState(() => _pendingProfilePicture = url);
        } catch (e) {
          if (mounted) {
            CustomSnackBar.show(
              context: context,
              message: 'Upload failed: $e',
              type: SnackBarType.error,
            );
          }
        }
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showPremadeAvatars() {
    final List<String> avatars = avatarAssetPaths;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S(widget.user.preferredLanguage).lang == 'el'
                        ? 'Επιλογή Έτοιμου Avatar'
                        : 'Choose Premade Avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: avatars.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _pendingProfilePicture = avatars[index]);
                        Navigator.pop(context);
                      },
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final s = constraints.maxWidth;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.brand.royalLavender.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SvgPicture.asset(
                                avatars[index],
                                width: s,
                                height: s,
                                fit: BoxFit.cover,
                                placeholderBuilder: (_) => Container(
                                  color: context.brand.neutralGrey.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // No longer returning ImageProvider directly, UserAvatar handles it natively.

  @override
  Widget build(BuildContext context) {
    final s = S(widget.user.preferredLanguage);
    final user = widget.user;

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.editProfile),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Profile picture section — tappable to change
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingImage
                            ? null
                            : _showProfilePictureOptions,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _isUploadingImage
                                ? CircleAvatar(
                                    radius: 60,
                                    backgroundColor:
                                        context.brand.royalLavender,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : UserAvatar(
                                    profilePictureUrl: _pendingProfilePicture,
                                    fullName: user.fullName,
                                    radius: 60,
                                  ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: context.brand.royalLavender,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_pendingProfilePicture != null &&
                          _pendingProfilePicture!.contains(
                            'googleusercontent.com',
                          ))
                        Text(
                          'Synced from Google',
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Name field
                Text(
                  s.fullName,
                  style: TextStyle(
                    color: context.brand.neutralGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? context.brand.inputFill
                        : Colors.white,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Bio field
                Text(
                  s.lang == 'el' ? 'Σχετικά με μένα' : 'About Me',
                  style: TextStyle(
                    color: context.brand.neutralGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 300,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: s.lang == 'el'
                        ? 'Γράψε λίγα λόγια για σένα...'
                        : 'Write a few words about yourself...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? context.brand.inputFill
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Achievements section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.lang == 'el'
                          ? 'Ακαδημαϊκά Επιτεύγματα'
                          : 'Academic Achievements',
                      style: TextStyle(
                        color: context.brand.neutralGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addAchievement,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.lang == 'el' ? 'Προσθήκη' : 'Add'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.brand.royalLavender,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_achievements.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2A2A3D)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.35)
                            : context.brand.neutralGrey.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        s.lang == 'el'
                            ? 'Δεν υπάρχουν επιτεύγματα'
                            : 'No achievements yet',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _achievements.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.only(left: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? context.brand.inputFill
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.brand.neutralGrey.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars,
                              color: context.brand.sunsetWarning,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _achievements[index],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: context.brand.errorRed,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _achievements.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),

                // Language selector
                Text(
                  s.languageSelect,
                  style: TextStyle(
                    color: context.brand.neutralGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.language,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? context.brand.inputFill
                        : Colors.white,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'el',
                      child: Text(
                        'Ελληνικά (EL)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(
                        'English (EN)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedLanguage = val!),
                ),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.brand.royalLavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(s.saveAndContinue),
                  ),
                ),
                const SizedBox(height: 32),

                // Change password section
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  s.changePassword,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showChangePasswordDialog(context),
                  icon: const Icon(Icons.lock_outline),
                  label: Text(s.changePassword),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand.royalLavender,
                    side: BorderSide(color: context.brand.royalLavender),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Delete account section
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  s.dangerZone,
                  style: TextStyle(
                    color: context.brand.errorRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showDeleteAccountDialog(context),
                  icon: const Icon(Icons.delete_forever),
                  label: Text(s.deleteAccount),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.brand.errorRed,
                    side: BorderSide(color: context.brand.errorRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addAchievement() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S(widget.user.preferredLanguage).lang == 'el'
              ? 'Προσθήκη Επιτεύγματος'
              : 'Add Achievement',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: S(widget.user.preferredLanguage).lang == 'el'
                ? 'π.χ. 19.5 Μέσος Όρος'
                : 'e.g. 19.5 GPA',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S(widget.user.preferredLanguage).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _achievements.add(controller.text.trim()));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.royalLavender,
              foregroundColor: Colors.white,
            ),
            child: Text(S(widget.user.preferredLanguage).saveAndContinue),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateUserProfile(
            widget.user.copyWith(
              fullName: _nameController.text.trim(),
              preferredLanguage: _selectedLanguage,
              profilePictureUrl: _pendingProfilePicture,
              bio: _bioController.text.trim(),
              achievements: _achievements,
            ),
          );
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: S(widget.user.preferredLanguage).profileUpdated,
          type: SnackBarType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: 'Error: $e',
          type: SnackBarType.error,
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showChangePasswordDialog(BuildContext context) {
    final s = S(widget.user.preferredLanguage);
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: s.currentPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: s.newPassword),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: s.confirmPassword),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPwCtrl.text != confirmPwCtrl.text) {
                CustomSnackBar.show(
                  context: context,
                  message: s.passwordsDoNotMatch,
                  type: SnackBarType.error,
                );
                return;
              }
              if (newPwCtrl.text.length < 8) {
                CustomSnackBar.show(
                  context: context,
                  message: s.passwordTooShort,
                  type: SnackBarType.error,
                );
                return;
              }
              try {
                await ref
                    .read(authRepositoryProvider)
                    .updatePassword(currentPwCtrl.text, newPwCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (ctx.mounted) {
                  CustomSnackBar.show(
                    context: ctx,
                    message: s.passwordChanged,
                    type: SnackBarType.success,
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  CustomSnackBar.show(
                    context: ctx,
                    message: '${s.error}: $e',
                    type: SnackBarType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.royalLavender,
              foregroundColor: Colors.white,
            ),
            child: Text(s.saveAndContinue),
          ),
        ],
      ),
    ).then((_) {
      currentPwCtrl.dispose();
      newPwCtrl.dispose();
      confirmPwCtrl.dispose();
    });
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final s = S(widget.user.preferredLanguage);
    final pwCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.deleteAccountWarning),
            const SizedBox(height: 16),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: s.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(authRepositoryProvider)
                    .deleteAccount(pwCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  CustomSnackBar.show(
                    context: ctx,
                    message: '${s.error}: $e',
                    type: SnackBarType.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.brand.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(s.deleteAccount),
          ),
        ],
      ),
    ).then((_) => pwCtrl.dispose());
  }
}
