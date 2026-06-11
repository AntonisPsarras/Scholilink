import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// Centralized performance configuration that adapts UI complexity
/// based on device capability. On high-end devices everything stays
/// identical; on lower-end devices, expensive effects like blur and
/// breathing animations are gracefully reduced.
///
/// Tier detection uses logical screen pixels as a GPU proxy, with
/// platform-specific thresholds: Android phones routinely have high
/// logical resolution while running on mid-range GPUs, so the Android
/// thresholds are deliberately more conservative.
class PerformanceConfig {
  static bool _initialized = false;

  /// Whether to use BackdropFilter blur (expensive GPU operation).
  /// Disabled on low-end devices; they get a solid translucent fallback.
  static bool useBlur = true;

  /// Whether GlassContainer breathing animations should run.
  /// Disabled on low-end devices to save battery and CPU.
  static bool useBreathingAnimation = true;

  /// Whether AnimatedLiquidBackground should animate gradients.
  /// Disabled on low/mid-tier devices; they get a static gradient.
  static bool useAnimatedBackground = true;

  /// Whether mobile [PageView] horizontal "jelly" skew + elastic snap runs.
  /// Disabled on low-end devices; also gated by reduced motion (see [shouldUseJellyScroll]).
  static bool useJellyScroll = true;

  /// Blur sigma to use when blur is enabled (high-end only; mid/low use 0).
  static double blurSigma = 12.0;

  /// Liquid gradient animation: tier flag plus system "reduce motion" / disable animations.
  static bool shouldAnimateLiquidBackground(BuildContext context) =>
      useAnimatedBackground && !MediaQuery.of(context).disableAnimations;

  /// Glass breathing: tier flag plus reduced motion.
  static bool shouldAnimateBreathing(BuildContext context) =>
      useBreathingAnimation && !MediaQuery.of(context).disableAnimations;

  /// PageView jelly stretch: tier flag plus reduced motion.
  static bool shouldUseJellyScroll(BuildContext context) =>
      useJellyScroll && !MediaQuery.of(context).disableAnimations;

  /// Initialize performance settings based on device characteristics.
  /// Should be called once during app startup after binding is initialized.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    final window = ui.PlatformDispatcher.instance.implicitView;
    if (window == null) return;

    final physicalSize = window.physicalSize;
    final devicePixelRatio = window.devicePixelRatio;

    // Calculate logical pixels as a rough device-tier proxy.
    final logicalWidth = physicalSize.width / devicePixelRatio;
    final logicalHeight = physicalSize.height / devicePixelRatio;
    final totalLogicalPixels = logicalWidth * logicalHeight;

    // Android phones have high logical-pixel counts but mid-range GPUs.
    // Using tighter thresholds on Android ensures most phones (e.g. 360×800,
    // 393×851, 412×915) are classified as mid-tier rather than high-end.
    // Web always runs in-browser so we keep the original thresholds there.
    final bool isAndroid = !kIsWeb && Platform.isAndroid;

    // Tier boundaries:
    //   Android low  < 250k  (~sub-720p phones)
    //   Android mid  < 550k  (~all typical 1080p phones up to large QHD phones)
    //   Android high ≥ 550k  (tablets / foldables with powerful GPUs)
    //
    //   Other  low  < 200k
    //   Other  mid  < 380k  (covers iPhone 14 class ~390×844 = 329k)
    //   Other  high ≥ 380k  (iPads, large iPhones in landscape, desktop)
    final double lowThreshold = isAndroid ? 250000 : 200000;
    final double midThreshold = isAndroid ? 550000 : 380000;

    if (totalLogicalPixels < lowThreshold) {
      // Low-end: disable blur and animations entirely
      useBlur = false;
      useBreathingAnimation = false;
      useAnimatedBackground = false;
      useJellyScroll = false;
      blurSigma = 0.0;
    } else if (totalLogicalPixels < midThreshold) {
      // Mid-tier: static gradient only — no blur, jelly, or breathing loops.
      useBlur = false;
      useBreathingAnimation = false;
      useAnimatedBackground = false;
      useJellyScroll = false;
      blurSigma = 0.0;
    } else {
      // High-end (tablets, desktop, large foldables): all effects enabled,
      // but cap blur sigma at 12 instead of the old 15 for a safety margin.
      useBlur = true;
      useBreathingAnimation = true;
      useAnimatedBackground = true;
      useJellyScroll = true;
      blurSigma = 12.0;
    }
  }
}
