import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/utils/firebase_error_handler.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final String _lang =
      'el'; // Assuming default language for simplicity, could get from provider

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      try {
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(_email);

        if (mounted) {
          CustomSnackBar.show(
            context: context,
            message: _lang == 'el'
                ? 'Στάλθηκε email επαναφοράς κωδικού'
                : 'Password reset email sent',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          final message = FirebaseErrorHandler.getMessage(e, _lang);
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
    return Scaffold(
      backgroundColor: context.brand.canvasBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.brand.darkText),
        title: Text(
          _lang == 'el' ? 'Επαναφορά Κωδικού' : 'Reset Password',
          style: TextStyle(
            color: context.brand.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                  Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: context.brand.primaryPurple.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _lang == 'el'
                        ? 'Ξεχάσατε τον κωδικό σας;'
                        : 'Forgot your password?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.brand.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lang == 'el'
                        ? 'Εισάγετε το email σας και θα σας στείλουμε έναν σύνδεσμο για επαναφορά'
                        : 'Enter your email and we will send you a reset link',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.brand.darkText.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: _glassInputDecoration(
                      _lang == 'el' ? 'Email' : 'Email Address',
                      Icons.email_outlined,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          !value.contains('@')) {
                        return _lang == 'el'
                            ? 'Παρακαλώ εισάγετε ένα έγκυρο email'
                            : 'Please enter a valid email';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: context.brand.primaryPurple.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.brand.primaryPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                          : Text(
                              _lang == 'el' ? 'Αποστολή Email' : 'Send Email',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
}
