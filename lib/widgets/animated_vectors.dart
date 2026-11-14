import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Smooth, modern page transition (fade + subtle upward slide + micro scale).
class HuniVioPageTransitionsBuilder extends PageTransitionsBuilder {
  const HuniVioPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// Springy tactile scale wrapper for cards, chips, and buttons on tap.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.965,
    this.duration = const Duration(milliseconds: 130),
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Smooth staggered entrance animation (fade + slide up) for list items & cards.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 380),
    this.offsetY = 18,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);

    final delayMs = (widget.index.clamp(0, 6)) * 45;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Animated multi-layer vector wave + floating geometric rings backdrop.
class AnimatedVectorBackdrop extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final bool subtle;

  const AnimatedVectorBackdrop({
    super.key,
    this.primaryColor = AppColors.primaryGreen,
    this.secondaryColor = AppColors.darkGreen,
    this.subtle = false,
  });

  @override
  State<AnimatedVectorBackdrop> createState() => _AnimatedVectorBackdropState();
}

class _AnimatedVectorBackdropState extends State<AnimatedVectorBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _VectorBackdropPainter(
            progress: _controller.value,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
            subtle: widget.subtle,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _VectorBackdropPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool subtle;

  _VectorBackdropPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.subtle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final waveShift = math.sin(progress * math.pi * 2) * 14;
    final floatY = math.cos(progress * math.pi * 2) * 8;

    // Soft floating translucent circles
    final circlePaint1 = Paint()
      ..color = Colors.white.withOpacity(subtle ? 0.08 : 0.10)
      ..style = PaintingStyle.fill;
    final circlePaint2 = Paint()
      ..color = Colors.white.withOpacity(subtle ? 0.06 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.22 + floatY),
      size.width * 0.20,
      circlePaint1,
    );
    canvas.drawCircle(
      Offset(size.width * 0.14, size.height * 0.72 - floatY),
      size.width * 0.16,
      circlePaint1,
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.68 + floatY * 0.7),
      size.width * 0.11,
      circlePaint2,
    );

    // Organic vector wave at bottom
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(subtle ? 0.09 : 0.12)
      ..style = PaintingStyle.fill;
    final wavePath = Path()
      ..moveTo(0, size.height * 0.80 + waveShift)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.70 - waveShift,
        size.width * 0.56,
        size.height * 0.82 + waveShift * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.92 + waveShift,
        size.width,
        size.height * 0.76 - waveShift,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _VectorBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.subtle != subtle;
  }
}

/// Animated vector illustration for empty states (floating house/key/chat vector + pulsing rings).
class AnimatedVectorEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color accentColor;

  const AnimatedVectorEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.accentColor = AppColors.primaryGreen,
  });

  @override
  State<AnimatedVectorEmptyState> createState() =>
      _AnimatedVectorEmptyStateState();
}

class _AnimatedVectorEmptyStateState extends State<AnimatedVectorEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final bob = math.sin(_controller.value * math.pi) * 6;
                final pulse = 1.0 + (_controller.value * 0.14);
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accentColor.withOpacity(0.08),
                            border: Border.all(
                              color: widget.accentColor.withOpacity(0.16),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, -bob),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.accentColor.withOpacity(0.18),
                                widget.accentColor.withOpacity(0.08),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accentColor.withOpacity(0.14),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.icon,
                            size: 34,
                            color: widget.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (widget.action != null) ...[
              const SizedBox(height: 18),
              widget.action!,
            ],
          ],
        ),
      ),
    );
  }
}
