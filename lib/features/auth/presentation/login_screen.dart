import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../data/saved_login_password_storage.dart';
import 'registration_screen.dart';
import 'reset_password_screen.dart';
import '../../../../shared/l10n.dart';
import '../../../../shared/app_locale.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/utils/firebase_error_handler.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = true;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    await SavedLoginPasswordStorage.migrateLegacyFromSharedPreferences();
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? true;
    setState(() => _rememberMe = remember);

    if (remember) {
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = await SavedLoginPasswordStorage.read();
      if (savedEmail != null) {
        _emailController.text = savedEmail;
        _email = savedEmail;
      }
      if (savedPassword != null) {
        _passwordController.text = savedPassword;
        _password = savedPassword;
      }
    } else {
      await prefs.remove('saved_email');
      await SavedLoginPasswordStorage.clear();
    }
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
        // Set persistence based on remember-me
        if (kIsWeb) {
          await FirebaseAuth.instance.setPersistence(
            _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
          );
        }

        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_email', _email);
          await SavedLoginPasswordStorage.write(_password);
        } else {
          await prefs.remove('saved_email');
          await SavedLoginPasswordStorage.clear();
        }

        await ref
            .read(authRepositoryProvider)
            .signInWithEmailAndPassword(_email, _password);
      } catch (e) {
        if (mounted) {
          final lang = ref.read(appLocaleProvider).languageCode;
          final message = FirebaseErrorHandler.getMessage(e, lang);
          CustomSnackBar.show(
            context: context,
            message: message,
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

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Handled by AuthWrapper's globalGradient
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.loginWelcomeTitle,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: context.brand.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.loginWelcomeSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.brand.darkText.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Align(
                    alignment: Alignment.center,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(value: 'el', label: Text('🇬🇷')),
                        ButtonSegment<String>(value: 'en', label: Text('🇬🇧')),
                      ],
                      selected: {lang},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        ref
                            .read(appLocaleProvider.notifier)
                            .setLanguage(
                              selection.first,
                              persistToProfile: false,
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wrap form in GlassContainer for visual grouping (optional, keeping flat for simplicity in mockup)
                  TextFormField(
                    controller: _emailController,
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
                        return lang == 'el'
                            ? 'Παρακαλώ εισάγετε ένα έγκυρο email'
                            : 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
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
                      if (value == null || value.isEmpty) {
                        return lang == 'el'
                            ? 'Παρακαλώ εισάγετε τον κωδικό σας'
                            : 'Please enter your password';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value!,
                  ),
                  const SizedBox(height: 12),
                  // Forgot Password & Remember me (Flexible rows avoid overflow on narrow widths / tests)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Text(
                                s.rememberMe,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.brand.neutralGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ResetPasswordScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          lang == 'el'
                              ? 'Ξέχασα τον κωδικό;'
                              : 'Forgot Password?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.brand.primaryPurple,
                            fontWeight: FontWeight.w600,
                          ),
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
                      style: Theme.of(context).brightness == Brightness.dark
                          ? ElevatedButton.styleFrom(
                              backgroundColor: context.brand.primaryPurple
                                  .withValues(alpha: 0.22),
                              foregroundColor: context.brand.darkText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            )
                          : ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.8,
                              ),
                              foregroundColor: context.brand.darkText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.brand.darkText,
                              ),
                            )
                          : Text(
                              s.login,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: context.brand.darkText,
                    ),
                    child: Text(s.noAccount),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.g_mobiledata, size: 24),
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
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? context.brand.primaryPurple.withValues(
                                  alpha: 0.45,
                                )
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        elevation: 0,
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
        ),
      ),
    );
  }

  void _signInWithGoogle() async {
    final lang = ref.read(appLocaleProvider).languageCode;
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
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
