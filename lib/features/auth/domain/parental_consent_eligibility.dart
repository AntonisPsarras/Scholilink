import 'user_model.dart';

int _ageInYears(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// Under-15 students need verified parental consent before AI features.
/// Users 15+ are not gated here (onboarding sets consent for them).
bool requiresParentalAiGate(AppUser user) {
  if (user.schoolRole != 'student') return false;
  final bd = user.birthDate;
  if (bd == null) {
    return !user.hasParentalConsent;
  }
  if (_ageInYears(bd) >= 15) {
    return false;
  }
  return !user.hasParentalConsent;
}
