import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void _ensureAthensTzLoaded() {
  try {
    tz.getLocation('Europe/Athens');
  } catch (_) {
    tzdata.initializeTimeZones();
  }
}

DateTime? nextRefreshFromCallableData(Map<Object?, Object?>? data) {
  if (data == null || data['nextRefreshAt'] == null) return null;
  return DateTime.tryParse(data['nextRefreshAt'].toString())?.toUtc();
}

DateTime? nextRefreshFromFunctionsDetails(Object? details) {
  if (details is Map && details['nextRefreshAt'] != null) {
    return DateTime.tryParse(details['nextRefreshAt'].toString())?.toUtc();
  }
  return null;
}

bool sparkLimitMessageIsPro(String? subscriptionType) {
  final s = (subscriptionType ?? '').trim().toLowerCase();
  return s == 'pro';
}

/// User-facing copy when daily Sparks are exhausted; [nextResetUtc] is the absolute instant from the server.
String sparkLimitUserMessage({
  required String? preferredLanguage,
  DateTime? nextResetUtc,
  String? subscriptionType,
}) {
  final el = preferredLanguage == 'el' || preferredLanguage == null;
  final isPro = sparkLimitMessageIsPro(subscriptionType);

  if (isPro) {
    if (nextResetUtc == null) {
      return el
          ? '🚨 Έφτασες το ημερήσιο όριο AI Sparks για το πρόγραμμά σου. Νέα επαναφόρτιση με την προγραμματισμένη ανανέωση ημέρας.'
          : "🚨 You've reached your daily AI Spark limit on your plan. Quota restores on the scheduled daily refresh.";
    }
    _ensureAthensTzLoaded();
    final loc = tz.getLocation('Europe/Athens');
    final wall = tz.TZDateTime.from(nextResetUtc.toUtc(), loc);
    final fmt = DateFormat('dd/MM/yyyy HH:mm').format(wall);
    return el
        ? '🚨 Έφτασες το ημερήσιο όριο AI Sparks. Επόμενη επαναφόρτιση γύρω στο $fmt (ώρα Ελλάδας).'
        : '🚨 Daily AI Spark limit reached. Next refill is around $fmt (Greece time).';
  }

  if (nextResetUtc == null) {
    return el
        ? '🚨 Έφτασες το ημερήσιο όριο Sparks! Αναβάθμισε σε Pro για περισσότερα.'
        : '🚨 Daily Spark limit reached. Upgrade to Pro for more.';
  }
  _ensureAthensTzLoaded();
  final loc = tz.getLocation('Europe/Athens');
  final wall = tz.TZDateTime.from(nextResetUtc.toUtc(), loc);
  final fmt = DateFormat('dd/MM/yyyy HH:mm').format(wall);
  return el
      ? '🚨 Έφτασες το ημερήσιο όριο Sparks. Επόμενη ανανέωση: $fmt (ώρα Ελλάδας). Αναβάθμισε σε Pro για περισσότερα τώρα.'
      : '🚨 Daily Spark limit reached. Next refresh: $fmt (Greece time). Upgrade to Pro for more capacity.';
}
