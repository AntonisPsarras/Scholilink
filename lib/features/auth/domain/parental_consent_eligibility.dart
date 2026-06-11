import 'user_model.dart';

/// Minimum age for AI without parental email verification.
/// Must match Cloud Functions `PARENTAL_CONSENT_MIN_AGE_YEARS` and
/// `user_private/{uid}.parentalConsentEligibility`.
const int kParentalConsentMinAgeYears = 15;

int ageInYearsFromBirthDate(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

/// Under-15 students need verified parental consent before AI features.
/// Users [kParentalConsentMinAgeYears]+ are not gated here (onboarding sets consent for them).
/// Under-15 users cannot self-assert consent — only server onboarding / parent verification can.
bool requiresParentalAiGate(AppUser user) {
  if (user.schoolRole != 'student') return false;
  final bd = user.birthDate;
  if (bd == null) {
    return !user.hasParentalConsent;
  }
  if (ageInYearsFromBirthDate(bd) >= kParentalConsentMinAgeYears) {
    return false;
  }
  return !user.hasParentalConsent;
}
