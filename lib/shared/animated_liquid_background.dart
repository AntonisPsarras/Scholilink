import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'performance_config.dart';

/// InheritedWidget that marks a subtree as already having an
/// [AnimatedLiquidBackground].  Nested instances check for this marker and
/// skip rendering a second background to prevent out-of-sync gradient seams
/// (e.g., center-column overlays on desktop where the root AuthWrapper already
/// provides the gradient and opened screens would otherwise add a second,
/// independently-animated layer).
class _AnimatedLiquidBgMarker extends InheritedWidget {
  const _AnimatedLiquidBgMarker({required super.child});

  static bool isPresent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AnimatedLiquidBgMarker>() !=
      null;

  @override
  bool updateShouldNotify(_AnimatedLiquidBgMarker old) => false;
}

class AnimatedLiquidBackground extends StatefulWidget {
  final Widget child;

  const AnimatedLiquidBackground({super.key, required this.child});

  @override
  State<AnimatedLiquidBackground> createState() =>
      _AnimatedLiquidBackgroundState();
}

class _AnimatedLiquidBackgroundState extends State<AnimatedLiquidBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (PerformanceConfig.useAnimatedBackground) {
      // 12 second loop — fast enough to feel alive, slow enough to stay calming
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 12),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLiquidAnimationPlayback();
  }

  /// Starts or stops [AnimationController.repeat] based on tier + [MediaQuery.disableAnimations].
  void _syncLiquidAnimationPlayback() {
    if (_controller == null) return;
    if (PerformanceConfig.shouldAnimateLiquidBackground(context)) {
      if (!_controller!.isAnimating) {
        _controller!.repeat();
      }
    } else {
      _controller!.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If an ancestor already provides the animated background, skip a second
    // animated layer (avoids seams). Still paint the static gradient behind
    // [child] — otherwise nested screens (e.g. desktop center overlays) only
    // get a transparent Scaffold and the tab underneath shows through.
    if (_AnimatedLiquidBgMarker.isPresent(context)) {
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: _StaticGradientLayers()),
          ),
          widget.child,
        ],
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final useAnimatedLayers =
        _controller != null &&
        PerformanceConfig.useAnimatedBackground &&
        !reduceMotion;

    // Static gradient: low-end tier, reduced motion, or controller paused
    if (!useAnimatedLayers) {
      return _AnimatedLiquidBgMarker(
        child: Stack(
          children: [
            const RepaintBoundary(child: _StaticGradientLayers()),
            widget.child,
          ],
        ),
      );
    }

    // Animated gradient — child is OUTSIDE the AnimatedBuilder
    // so it never rebuilds when the gradient changes (key optimization)
    return _AnimatedLiquidBgMarker(
      child: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) {
                final t = _controller!.value * 2 * math.pi;
                return _AnimatedGradientLayers(t: t);
              },
            ),
          ),
          widget.child, // Never rebuilds due to gradient animation
        ],
      ),
    );
  }
}

/// Three independent animated gradient layers creating an "aurora" floating effect.
/// Each layer uses a different frequency multiplier so they drift organically
/// relative to each other — never repeating the same combined pattern.
class _LiquidGradients {
  static List<Color> basePrimary(Brightness b) {
    if (b == Brightness.dark) {
      return const [Color(0xFF12121C), Color(0xFF1A1A28), Color(0xFF1E1B32)];
    }
    return const [Color(0xFFDDE8FF), Color(0xFFEDE5FF), Color(0xFFFFE9F3)];
  }

  static List<Color> overlayDrift(Brightness b) {
    if (b == Brightness.dark) {
      return const [Color(0x662A3A5C), Color(0x443D2B52), Colors.transparent];
    }
    return const [Color(0xAAE0F7FA), Color(0x77EEF0FF), Colors.transparent];
  }

  static List<Color> auroraAccent(Brightness b) {
    if (b == Brightness.dark) {
      return const [Color(0xFF6B5A9E), Color(0xFF3D6B72), Colors.transparent];
    }
    return const [Color(0xFFC5B7FC), Color(0xFFB2F0E8), Colors.transparent];
  }

  static double auroraOpacityCap(Brightness b) =>
      b == Brightness.dark ? 0.22 : 0.35;
}

class _AnimatedGradientLayers extends StatelessWidget {
  final double t;
  const _AnimatedGradientLayers({required this.t});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // Layer 1: primary slow drift (base hue — soft lavender/cyan)
    final begin1 = Alignment(math.cos(t * 0.9), math.sin(t * 0.9));
    final end1 = Alignment(
      math.cos(t * 0.9 + math.pi),
      math.sin(t * 0.9 + math.pi),
    );

    // Layer 2: secondary drift at different frequency (highlights/rose)
    final begin2 = Alignment(
      math.cos(t * 1.3 + math.pi / 3),
      math.sin(t * 1.3 + math.pi / 3),
    );
    final end2 = Alignment(
      math.cos(t * 1.3 + math.pi * 1.3),
      math.sin(t * 1.3 + math.pi * 1.3),
    );

    // Layer 3: aurora pulse — a gentle radial shimmer using sin for opacity pulsing
    final auroraPulse = (math.sin(t * 1.7) * 0.5 + 0.5); // 0.0 → 1.0 pulsing
    final auroraBegin = Alignment(math.cos(t * 0.6 + math.pi / 2), -1.0);
    final auroraEnd = Alignment(math.cos(t * 0.6 - math.pi / 2), 1.0);
    final cap = _LiquidGradients.auroraOpacityCap(brightness);

    return Stack(
      children: [
        // Base layer — soft pastels drifting slowly
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin1,
              end: end1,
              colors: _LiquidGradients.basePrimary(brightness),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Second layer — cool mint/indigo highlights floating over
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin2,
              end: end2,
              colors: _LiquidGradients.overlayDrift(brightness),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Third layer — aurora shimmer (pulses in opacity)
        Opacity(
          opacity: (auroraPulse * cap).clamp(0.0, cap),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: auroraBegin,
                end: auroraEnd,
                colors: _LiquidGradients.auroraAccent(brightness),
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Static fallback for low-end devices — no animation, just a beautiful gradient.
class _StaticGradientLayers extends StatelessWidget {
  const _StaticGradientLayers();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _LiquidGradients.basePrimary(b),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: _LiquidGradients.overlayDrift(b),
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Aurora accent — fixed midpoint opacity (matches animated layer average)
        Opacity(
          opacity: (0.5 * _LiquidGradients.auroraOpacityCap(b)).clamp(
            0.0,
            _LiquidGradients.auroraOpacityCap(b),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _LiquidGradients.auroraAccent(b),
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
