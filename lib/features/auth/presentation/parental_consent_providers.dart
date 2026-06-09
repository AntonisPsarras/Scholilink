import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cooldown (seconds) after sending or resending the parental consent email.
class ParentalConsentUiState {
  final int resendCooldownSeconds;

  const ParentalConsentUiState({this.resendCooldownSeconds = 0});

  bool get canResend => resendCooldownSeconds <= 0;
}

class ParentalConsentUiNotifier extends StateNotifier<ParentalConsentUiState> {
  ParentalConsentUiNotifier() : super(const ParentalConsentUiState());

  Timer? _timer;

  /// Starts the 30s resend cooldown (after a successful send or resend).
  void startResendCooldown() {
    _timer?.cancel();
    state = const ParentalConsentUiState(resendCooldownSeconds: 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = state.resendCooldownSeconds;
      if (left <= 1) {
        _timer?.cancel();
        state = const ParentalConsentUiState();
      } else {
        state = ParentalConsentUiState(resendCooldownSeconds: left - 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final parentalConsentUiProvider =
    StateNotifierProvider<ParentalConsentUiNotifier, ParentalConsentUiState>((
      ref,
    ) {
      return ParentalConsentUiNotifier();
    });
