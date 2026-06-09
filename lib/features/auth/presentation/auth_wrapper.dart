import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'login_screen.dart';
import 'user_onboarding_screen.dart';
import 'consent_deep_link_listener.dart';
import '../../dashboard/presentation/home_scaffold.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/push_notification_service.dart';

// Firebase handles session persistence natively. This provider exists as a placeholder for future session logic.
final firebasePersistenceProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  return;
});

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  ProviderSubscription<AsyncValue<AppUser?>>? _authStateSubscription;
  String? _lastInitializedUid;
  String? _lastInitializedLanguage;
  Future<void> _pushSyncFuture = Future<void>.value();

  void _schedulePushSync(Future<void> Function() action) {
    _pushSyncFuture = _pushSyncFuture
        .then((_) => action())
        .catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    _authStateSubscription = ref.listenManual<AsyncValue<AppUser?>>(
      authStateProvider,
      (previous, next) {
        final user = next.valueOrNull;
        if (user == null) {
          _lastInitializedUid = null;
          _lastInitializedLanguage = null;
          _schedulePushSync(
            PushNotificationService.instance.clearCurrentUserToken,
          );
          return;
        }
        final shouldReinitialize =
            _lastInitializedUid != user.uid ||
            _lastInitializedLanguage != user.preferredLanguage;
        if (!shouldReinitialize) return;

        _lastInitializedUid = user.uid;
        _lastInitializedLanguage = user.preferredLanguage;
        _schedulePushSync(
          () => PushNotificationService.instance.initializeForUser(
            uid: user.uid,
            preferredLanguage: user.preferredLanguage,
          ),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firebasePersistence = ref.watch(firebasePersistenceProvider);

    return ConsentDeepLinkListener(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppTheme.globalGradient(
          child: firebasePersistence.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, stack) => const LoginScreen(),
            data: (_) {
              final authState = ref.watch(authStateProvider);
              return authState.when(
                data: (user) {
                  if (user == null) {
                    return const LoginScreen();
                  } else if (!user.isProfileComplete) {
                    return const UserOnboardingScreen();
                  } else {
                    return const HomeScaffold();
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, stack) => const Center(
                  child: Text('Could not load account. Please sign in again.'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
