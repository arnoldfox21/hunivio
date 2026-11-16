import 'dart:math' as math;
import 'package:flutter/material.dart';

class LevelBadgeIcon extends StatelessWidget {
  final String level;
  final double size;

  const LevelBadgeIcon({
    super.key,
    required this.level,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LevelBadgePainter(level.trim().toLowerCase()),
      ),
    );
  }
}

class LevelPillBadge extends StatelessWidget {
  final String level;
  final bool compact;

  const LevelPillBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  static Color primaryColorFor(String level) {
    switch (level.trim().toLowerCase()) {
      case 'platinum':
        return const Color(0xFF0EA5E9);
      case 'gold':
        return const Color(0xFFD97706);
      case 'silver':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFB45309);
    }
  }

  static Color bgColorFor(String level) {
    switch (level.trim().toLowerCase()) {
      case 'platinum':
        return const Color(0xFFE0F2FE);
      case 'gold':
        return const Color(0xFFFEF3C7);
      case 'silver':
        return const Color(0xFFF1F5F9);
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = primaryColorFor(level);
    final bg = bgColorFor(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LevelBadgeIcon(level: level, size: compact ? 16 : 20),
          SizedBox(width: compact ? 4 : 6),
          Text(
            level,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadgePainter extends CustomPainter {
  final String tier;

  _LevelBadgePainter(this.tier);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    final List<Color> gradientColors;
    final Color borderColor;
    switch (tier) {
      case 'platinum':
        gradientColors = const [
          Color(0xFF38BDF8),
          Color(0xFF0284C7),
          Color(0xFF1E3A8A),
        ];
        borderColor = const Color(0xFFBAE6FD);
        break;
      case 'gold':
        gradientColors = const [
          Color(0xFFFDE047),
          Color(0xFFF59E0B),
          Color(0xFFB45309),
        ];
        borderColor = const Color(0xFFFEF08A);
        break;
      case 'silver':
        gradientColors = const [
          Color(0xFFF1F5F9),
          Color(0xFF94A3B8),
          Color(0xFF475569),
        ];
        borderColor = const Color(0xFFE2E8F0);
        break;
      default:
        gradientColors = const [
          Color(0xFFFDBA74),
          Color(0xFFD97706),
          Color(0xFF7C2D12),
        ];
        borderColor = const Color(0xFFFED7AA);
        break;
    }

    // Shield silhouette
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.20)
      ..quadraticBezierTo(w * 0.90, h * 0.64, w * 0.50, h * 0.94)
      ..quadraticBezierTo(w * 0.10, h * 0.64, w * 0.12, h * 0.20)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ).createShader(rect);

    canvas.drawShadow(shield, Colors.black.withOpacity(0.25), 3, false);
    canvas.drawPath(shield, fillPaint);

    // Metallic rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.055)
      ..color = borderColor;
    canvas.drawPath(shield, rimPaint);

    // Inner emblem per tier
    final emblemPaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    if (tier == 'platinum' || tier == 'gold') {
      // Crown / diamond crest
      final crown = Path()
        ..moveTo(w * 0.27, h * 0.62)
        ..lineTo(w * 0.24, h * 0.38)
        ..lineTo(w * 0.39, h * 0.49)
        ..lineTo(w * 0.50, h * 0.30)
        ..lineTo(w * 0.61, h * 0.49)
        ..lineTo(w * 0.76, h * 0.38)
        ..lineTo(w * 0.73, h * 0.62)
        ..close();
      canvas.drawPath(crown, emblemPaint);

      if (tier == 'platinum') {
        final gem = Path()
          ..moveTo(w * 0.50, h * 0.67)
          ..lineTo(w * 0.58, h * 0.75)
          ..lineTo(w * 0.50, h * 0.83)
          ..lineTo(w * 0.42, h * 0.75)
          ..close();
        canvas.drawPath(gem, Paint()..color = const Color(0xFFE0F2FE));
      }
    } else if (tier == 'silver') {
      // Double chevron
      final chevPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(1.8, w * 0.085);
      final c1 = Path()
        ..moveTo(w * 0.32, h * 0.45)
        ..lineTo(w * 0.50, h * 0.33)
        ..lineTo(w * 0.68, h * 0.45);
      final c2 = Path()
        ..moveTo(w * 0.32, h * 0.62)
        ..lineTo(w * 0.50, h * 0.50)
        ..lineTo(w * 0.68, h * 0.62);
      canvas.drawPath(c1, chevPaint);
      canvas.drawPath(c2, chevPaint);
    } else {
      // Bronze: 5-point star
      final star = Path();
      final cx = w * 0.50;
      final cy = h * 0.50;
      final outerR = w * 0.21;
      final innerR = w * 0.095;
      for (int i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final r = i.isEven ? outerR : innerR;
        final x = cx + r * math.cos(angle);
        final y = cy + r * math.sin(angle);
        if (i == 0) {
          star.moveTo(x, y);
        } else {
          star.lineTo(x, y);
        }
      }
      star.close();
      canvas.drawPath(star, emblemPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LevelBadgePainter oldDelegate) =>
      oldDelegate.tier != tier;
}
