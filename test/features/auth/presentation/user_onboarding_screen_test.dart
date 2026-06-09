import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_dashboard/features/auth/data/auth_repository.dart';
import 'package:student_dashboard/features/auth/domain/user_model.dart';
import 'package:student_dashboard/features/auth/presentation/user_onboarding_screen.dart';
import 'package:student_dashboard/l10n/app_localizations.dart';

void main() {
  testWidgets('Onboarding shows progress and moves to next step', (
    tester,
  ) async {
    final user = AppUser(
      uid: 'u1',
      email: 'user@example.com',
      schoolRole: 'student',
      preferredLanguage: 'el',
      isProfileComplete: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp(
          locale: const Locale('el'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const UserOnboardingScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('1/'), findsOneWidget);

    await tester.tap(find.text('Ελληνική'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Επόμενο'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('2/'), findsOneWidget);
  });
}
