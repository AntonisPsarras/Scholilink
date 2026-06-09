import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AIPulsingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const AIPulsingIndicator({super.key, this.size = 24.0, this.color});

  @override
  State<AIPulsingIndicator> createState() => _AIPulsingIndicatorState();
}

class _AIPulsingIndicatorState extends State<AIPulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Opacity(
            opacity: _animation.value,
            child: Icon(
              Icons.auto_awesome,
              size: widget.size,
              color: widget.color ?? context.brand.royalLavender,
            ),
          ),
        );
      },
    );
  }
}
