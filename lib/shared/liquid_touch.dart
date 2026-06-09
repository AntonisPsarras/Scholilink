import 'package:flutter/material.dart';

class LiquidTouch extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const LiquidTouch({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(24.0)),
  });

  @override
  State<LiquidTouch> createState() => _LiquidTouchState();
}

class _LiquidTouchState extends State<LiquidTouch>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late AnimationController _rippleController;
  Offset? _tapDownPosition;

  @override
  void initState() {
    super.initState();
    // Spring physics configuration for the press
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );

    // Ripple wave configuration
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _tapDownPosition = details.localPosition;
    });
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
    _triggerRipple();
    // Defer so pointer / mouse hover cleanup finishes before the tree changes
    // (avoids mouse_tracker assertions when opening routes or overlays).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      widget.onTap();
    });
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  void _triggerRipple() {
    _rippleController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _rippleController]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                widget.child,
                if (_tapDownPosition != null && _rippleController.isAnimating)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: CustomPaint(
                        painter: _LiquidRipplePainter(
                          center: _tapDownPosition!,
                          progress: _rippleController.value,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiquidRipplePainter extends CustomPainter {
  final Offset center;
  final double progress;

  _LiquidRipplePainter({required this.center, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0 || progress == 1.0) return;

    final double maxRadius = size.width > size.height
        ? size.width
        : size.height;
    // The easing for the ripple expansion
    final curveProgress = Curves.easeOutQuart.transform(progress);
    final double radius = maxRadius * 1.5 * curveProgress;

    // Wave opacity fades out as it expands
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.4 * opacity),
          Colors.white.withValues(alpha: 0.1 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _LiquidRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
  }
}
