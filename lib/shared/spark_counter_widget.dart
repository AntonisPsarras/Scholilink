import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../core/spark_sync.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/profile/presentation/upgrade_pro_screen.dart';

/// English reset phrase for the compact header (matches product spec).
String? _sparkResetPhrase(DateTime? nextResetUtc) {
  if (nextResetUtc == null) return null;
  final local = nextResetUtc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final resetDay = DateTime(local.year, local.month, local.day);
  final tomorrow = today.add(const Duration(days: 1));
  if (resetDay == today) {
    return 'resets at ${DateFormat('HH:mm').format(local)}';
  }
  if (resetDay == tomorrow) {
    return 'resets tomorrow';
  }
  return 'resets ${DateFormat('EEE d MMM', 'en').format(local)}';
}

class SparkCounterWidget extends ConsumerWidget {
  const SparkCounterWidget({super.key});

  static const double _fontSize = 12;
  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sparksData = ref.watch(
      authStateProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.aiSparks,
                async.valueOrNull!.subscriptionType,
                async.valueOrNull!.preferredLanguage,
              ),
      ),
    );

    if (sparksData == null) return const SizedBox.shrink();

    final sparks = sparksData.$1;
    final isPro = sparksData.$2 == 'pro';
    final preferredLanguage = sparksData.$3;

    final nextResetUtc = ref.watch(sparkNextResetUtcProvider);
    final resetPhrase = _sparkResetPhrase(nextResetUtc);

    final brand = context.brand;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useWarningAccent =
        (sparks > 0 && sparks <= 3) || (sparks == 0 && isPro);
    final warningText = isDark ? brand.sunsetWarning : const Color(0xFFC2410C);
    final accentColor = useWarningAccent ? warningText : brand.royalLavender;

    void sync() => unawaited(syncSparkStatusFromServer(ref));

    void openUpgrade() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpgradeProScreen()),
      );
    }

    final showFreeZeroState = sparks == 0 && !isPro;

    final semanticsReset = resetPhrase ?? 'next reset unknown';
    return Semantics(
      label: showFreeZeroState
          ? 'Sparks exhausted. $semanticsReset. Tap Pro to upgrade.'
          : 'Sparks: $sparks. $semanticsReset',
      liveRegion: true,
      child: InkWell(
        onTap: sync,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: brand.royalLavender.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: brand.royalLavender.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: accentColor, size: _iconSize),
              const SizedBox(width: 4),
              Flexible(
                child: showFreeZeroState
                    ? _FreeZeroRow(
                        onTapPro: openUpgrade,
                        baseStyle: TextStyle(
                          color: brand.neutralGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: _fontSize,
                          height: 1.15,
                        ),
                        proStyle: TextStyle(
                          color: brand.primaryPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: _fontSize,
                          height: 1.15,
                          decoration: TextDecoration.underline,
                          decorationColor: brand.primaryPurple.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      )
                    : Text(
                        preferredLanguage == 'el'
                            ? '$sparks Sparks'
                            : '$sparks sparks',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: _fontSize,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline Pro label tap target; outer [InkWell] still handles sync for the rest of the row.
class _FreeZeroRow extends StatelessWidget {
  const _FreeZeroRow({
    required this.onTapPro,
    required this.baseStyle,
    required this.proStyle,
  });

  final VoidCallback onTapPro;
  final TextStyle baseStyle;
  final TextStyle proStyle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Χρειάζεσαι '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapPro,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 1,
                  ),
                  child: Text('Pro', style: proStyle),
                ),
              ),
            ),
          ),
          const TextSpan(text: ' για περισσότερα'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
