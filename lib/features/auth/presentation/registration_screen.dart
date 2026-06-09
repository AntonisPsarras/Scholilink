import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import '../data/saved_login_password_storage.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/l10n.dart';
import '../../../../shared/app_locale.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/utils/firebase_error_handler.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _fullName = '';
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _rememberMe = prefs.getBool('remember_me') ?? true);
  }

  Future<void> _saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', value);
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        final lang = ref.read(appLocaleProvider).languageCode;
        // Set persistence based on remember-me
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(
            _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
          );
        }
        await ref
            .read(authRepositoryProvider)
            .createUserWithEmailAndPassword(_email, _password);

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_email', _email);
        } else {
          await prefs.remove('saved_email');
        }
        await SavedLoginPasswordStorage.clear();

        // Update user profile with full name and language
        final user = ref.read(authStateProvider).value;
        if (user != null) {
          await ref
              .read(authRepositoryProvider)
              .updateUserProfile(
                user.copyWith(fullName: _fullName, preferredLanguage: lang),
              );
        }

        if (mounted) {
          Navigator.of(context).pop(); // Go back to AuthWrapper/Login
        }
      } catch (e) {
        if (mounted) {
          final errorMessage = FirebaseErrorHandler.getMessage(
            e,
            ref.read(appLocaleProvider).languageCode,
          );
          CustomSnackBar.show(
            context: context,
            message: errorMessage,
            type: SnackBarType.error,
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  InputDecoration _glassInputDecoration(String labelText, IconData icon) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(
          icon,
          color: context.brand.darkText.withValues(alpha: 0.85),
        ),
      ).applyDefaults(Theme.of(context).inputDecorationTheme);
    }
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(
        icon,
        color: context.brand.darkText.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLocaleProvider).languageCode;
    final s = S(lang);

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Let AuthWrapper's global gradient show
        appBar: AppBar(
          title: Text(
            s.registerFor,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: context.brand.darkText),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.welcome,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: context.brand.darkText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lang == 'el'
                          ? 'Δημιουργήστε έναν νέο λογαριασμό'
                          : 'Create a new account',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.brand.neutralGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Language Selection
                    Builder(
                      builder: (context) {
                        final dark =
                            Theme.of(context).brightness == Brightness.dark;
                        final cs = Theme.of(context).colorScheme;
                        final menuFg = dark
                            ? cs.onSurface
                            : context.brand.darkText;
                        return DropdownButtonFormField<String>(
                          key: ValueKey(lang),
                          initialValue: lang,
                          decoration:
                              _glassInputDecoration(
                                s.languageSelect,
                                Icons.language_outlined,
                              ).copyWith(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: context.brand.neutralGrey,
                          ),
                          dropdownColor: dark
                              ? cs.surfaceContainerHigh
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(16),
                          selectedItemBuilder: (context) => [
                            Text(
                              'Ελληνικά (Greek)',
                              style: TextStyle(color: menuFg),
                            ),
                            Text('English', style: TextStyle(color: menuFg)),
                          ],
                          items: [
                            DropdownMenuItem(
                              value: 'el',
                              child: Text(
                                'Ελληνικά (Greek)',
                                style: TextStyle(color: menuFg),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(
                                'English',
                                style: TextStyle(color: menuFg),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            ref
                                .read(appLocaleProvider.notifier)
                                .setLanguage(value, persistToProfile: false);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      style: TextStyle(
                        color: context.brand.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _glassInputDecoration(
                        s.fullName,
                        Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return s.lang == 'el'
                              ? 'Παρακαλώ εισάγετε το ονοματεπώνυμό σας'
                              : 'Please enter your full name';
                        }
                        return null;
                      },
                      onSaved: (value) => _fullName = value!,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      style: TextStyle(
                        color: context.brand.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _glassInputDecoration(
                        s.email,
                        Icons.email_outlined,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            !value.contains('@')) {
                          return s.lang == 'el'
                              ? 'Παρακαλώ εισάγετε ένα έγκυρο email'
                              : 'Please enter a valid email';
                        }
                        return null;
                      },
                      onSaved: (value) => _email = value!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      style: TextStyle(
                        color: context.brand.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _glassInputDecoration(
                        s.password,
                        Icons.lock_outline,
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return s.lang == 'el'
                              ? 'Ο κωδικός πρέπει να είναι τουλάχιστον 8 χαρακτήρες'
                              : 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                      onSaved: (value) => _password = value!,
                    ),
                    const SizedBox(height: 12),
                    // Remember me checkbox
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              setState(() => _rememberMe = val ?? true);
                              _saveRememberMe(_rememberMe);
                            },
                            activeColor: context.brand.royalLavender,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.rememberMe,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.brand.neutralGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ButtonStyle(
                          elevation: const WidgetStatePropertyAll(0),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return const Color(0xFF2A2A3D);
                            }
                            return context.brand.royalLavender;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return Colors.white.withValues(alpha: 0.54);
                            }
                            return Colors.white;
                          }),
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
                            : Text(
                                s.createAccount,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            lang == 'el' ? 'ή' : 'or',
                            style: TextStyle(color: context.brand.neutralGrey),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google Sign In
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: OutlinedButton.icon(
                        onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final px =
                                      (24 *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .round();
                                  return CachedNetworkImage(
                                    imageUrl:
                                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                    height: 24,
                                    width: 24,
                                    memCacheWidth: px,
                                    memCacheHeight: px,
                                    maxWidthDiskCache: px,
                                    maxHeightDiskCache: px,
                                    placeholder: (_, __) =>
                                        const SizedBox(width: 24, height: 24),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.g_mobiledata,
                                      size: 24,
                                    ),
                                  );
                                },
                              ),
                        label: Text(
                          s.signInWithGoogle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? context.brand.primaryPurple.withValues(
                                  alpha: 0.12,
                                )
                              : Colors.white.withValues(alpha: 0.5),
                          foregroundColor: context.brand.darkText,
                          elevation: 0,
                          side: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? context.brand.primaryPurple.withValues(
                                    alpha: 0.45,
                                  )
                                : Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signInWithGoogle() async {
    final lang = ref.read(appLocaleProvider).languageCode;
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: lang == 'el'
              ? 'Η σύνδεση με Google απέτυχε'
              : 'Google sign-in failed',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }
}
