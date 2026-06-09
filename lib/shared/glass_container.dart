import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'performance_config.dart';

class GlassContainer extends StatefulWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double borderRadius;
  final BorderRadiusGeometry? customBorderRadius;

  /// When null, uses [AppBrandColors.glassBase] from the current theme.
  final Color? backgroundColor;
  final BoxBorder? border;
  final bool animate;

  /// When true, listens to the nearest [Scrollable] to pause breathing and optionally drop blur while scrolling.
  final bool respectScrollPerformance;

  /// If [respectScrollPerformance] is true, uses a translucent shell without [BackdropFilter] while the user scrolls.
  final bool degradeBlurWhileScrolling;

  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.blur = 15.0, // High frost blur
    this.borderRadius = 24.0,
    this.customBorderRadius,
    this.backgroundColor,
    this.border,
    this.animate = true,
    this.respectScrollPerformance = true,
    this.degradeBlurWhileScrolling = true,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  // Cache the blur filter to avoid recreating on every build
  ImageFilter? _cachedFilter;
  double _cachedBlurSigma = 0.0;

  ScrollPosition? _scrollPosition;
  VoidCallback? _scrollingStatusListener;
  bool _userScrolling = false;
  bool _lastBreathingSyncWasScrolling = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate && PerformanceConfig.useBreathingAnimation) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(
          milliseconds: 5000,
        ), // 5 seconds breathing loop
      );
      _controller!.value = math.Random().nextDouble();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.respectScrollPerformance) {
      _attachScrollAwareness();
    } else {
      _detachScrollAwareness();
      if (_userScrolling) {
        setState(() => _userScrolling = false);
      }
      _syncBreathingToScroll(false);
    }
    _applyBreathingPlayback();
  }

  @override
  void didUpdateWidget(covariant GlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.respectScrollPerformance != widget.respectScrollPerformance) {
      if (widget.respectScrollPerformance) {
        _attachScrollAwareness();
      } else {
        _detachScrollAwareness();
        if (_userScrolling) setState(() => _userScrolling = false);
        _syncBreathingToScroll(false);
      }
    }
  }

  void _attachScrollAwareness() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;

    _detachScrollAwareness();
    _scrollPosition = position;
    if (position == null) {
      if (_userScrolling) {
        setState(() => _userScrolling = false);
      }
      _syncBreathingToScroll(false);
      return;
    }

    void onScrollActivityChanged() {
      final v = position.isScrollingNotifier.value;
      if (!mounted) return;
      if (v != _userScrolling) {
        setState(() => _userScrolling = v);
      }
      _syncBreathingToScroll(v);
    }

    _scrollingStatusListener = onScrollActivityChanged;
    position.isScrollingNotifier.addListener(_scrollingStatusListener!);

    final initial = position.isScrollingNotifier.value;
    _userScrolling = initial;
    _syncBreathingToScroll(initial);
  }

  void _detachScrollAwareness() {
    if (_scrollPosition != null && _scrollingStatusListener != null) {
      _scrollPosition!.isScrollingNotifier.removeListener(
        _scrollingStatusListener!,
      );
    }
    _scrollPosition = null;
    _scrollingStatusListener = null;
  }

  bool _isDesktopLikePlatform() {
    final platform = defaultTargetPlatform;
    return kIsWeb ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  /// Starts/stops breathing from tier flags, reduced motion, desktop, and scroll state.
  void _applyBreathingPlayback() {
    if (_controller == null ||
        !widget.animate ||
        !PerformanceConfig.useBreathingAnimation) {
      return;
    }

    if (_isDesktopLikePlatform() ||
        !PerformanceConfig.shouldAnimateBreathing(context)) {
      _controller!.stop(canceled: false);
      return;
    }

    if (widget.respectScrollPerformance && _userScrolling) {
      _controller!.stop(canceled: false);
      return;
    }

    if (!_controller!.isAnimating) {
      _controller!.repeat(reverse: true);
    }
  }

  /// Pauses breathing while scrolling; resumes when idle. Does not call setState.
  void _syncBreathingToScroll(bool scrolling) {
    if (_controller == null || !widget.animate) return;
    if (!PerformanceConfig.useBreathingAnimation) return;

    if (scrolling == _lastBreathingSyncWasScrolling) {
      if (!scrolling) {
        _applyBreathingPlayback();
      }
      return;
    }
    _lastBreathingSyncWasScrolling = scrolling;

    if (scrolling) {
      _controller!.stop(canceled: false);
    } else {
      _applyBreathingPlayback();
    }
  }

  @override
  void dispose() {
    _detachScrollAwareness();
    _controller?.dispose();
    super.dispose();
  }

  ImageFilter _getBlurFilter() {
    final sigma = PerformanceConfig.useBlur
        ? (widget.blur > 0
              ? math.min(widget.blur, PerformanceConfig.blurSigma)
              : PerformanceConfig.blurSigma)
        : 0.0;
    if (_cachedFilter == null || _cachedBlurSigma != sigma) {
      _cachedBlurSigma = sigma;
      _cachedFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    }
    return _cachedFilter!;
  }

  bool get _useBackdropBlur {
    if (!PerformanceConfig.useBlur || widget.blur <= 0) return false;
    if (widget.respectScrollPerformance &&
        widget.degradeBlurWhileScrolling &&
        _userScrolling) {
      return false;
    }
    return true;
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final container = _buildCardShell();
    final isDesktopLike = _isDesktopLikePlatform();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final enableBreathingAnimation =
        widget.animate &&
        PerformanceConfig.useBreathingAnimation &&
        !isDesktopLike &&
        !reduceMotion;

    if (_controller == null || !enableBreathingAnimation) {
      return RepaintBoundary(child: container);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          // Keep scale range very tight (0.001) so sub-pixel text jitter is
          // invisible, while the glass "breathing" feel is preserved.
          final scale = 0.9995 + (_controller!.value * 0.001);
          return Transform.scale(
            scale: scale,
            filterQuality: FilterQuality.high,
            child: child,
          );
        },
        child: container,
      ),
    );
  }

  /// Outer shell: shadow + clip. Inner layers isolated for repaint & backdrop cost.
  Widget _buildCardShell() {
    final brand = context.brand;
    final resolvedBorderRadius =
        widget.customBorderRadius ?? BorderRadius.circular(widget.borderRadius);
    final dark = _isDarkMode;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: resolvedBorderRadius,
        boxShadow: [
          if (dark)
            BoxShadow(
              color: brand.glassFlatShadow,
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: brand.glassShadow,
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: resolvedBorderRadius,
        child: RepaintBoundary(child: _buildBlurStack(resolvedBorderRadius)),
      ),
    );
  }

  Widget _buildBlurStack(BorderRadiusGeometry borderRadius) {
    final layeredContent = _buildDecoratedContent(borderRadius);

    // Dark mode: flat panels — skip frosted blur so text stays crisp.
    if (_isDarkMode || !_useBackdropBlur) {
      return layeredContent;
    }

    return BackdropFilter(
      filter: _getBlurFilter(),
      child: RepaintBoundary(child: layeredContent),
    );
  }

  /// Light: gradient + specular. Dark: flat fill + subtle border (no metallic shine).
  Widget _buildDecoratedContent(BorderRadiusGeometry borderRadius) {
    final brand = context.brand;
    final base = widget.backgroundColor ?? brand.glassBase;

    if (_isDarkMode) {
      final fill = widget.backgroundColor ?? brand.surfaceElevated;
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: borderRadius,
          border:
              widget.border ??
              Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: RepaintBoundary(child: widget.child ?? const SizedBox.shrink()),
      );
    }

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: 0.5),
            brand.glassSheenPink,
            brand.glassSheenCyan,
            base.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
        borderRadius: borderRadius,
        border:
            widget.border ?? Border.all(color: brand.glassBorder, width: 1.2),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: brand.glassSpecularTop),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.25],
        ),
      ),
      child: RepaintBoundary(child: widget.child ?? const SizedBox.shrink()),
    );
  }
}
