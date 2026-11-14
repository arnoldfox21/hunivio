import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserGuideStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final double borderRadius;

  const UserGuideStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.borderRadius = 14,
  });
}

class AppUserGuideOverlay {
  static const String _seenPrefKey = 'hunivio_user_guide_seen_v1';

  static Future<bool> hasSeenGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenPrefKey) ?? false;
  }

  static Future<void> markGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenPrefKey, true);
  }

  static Future<void> showIfFirstInstall(
    BuildContext context,
    List<UserGuideStep> steps,
  ) async {
    final seen = await hasSeenGuide();
    if (seen || !context.mounted) return;
    await showNow(context, steps, persistSeen: true);
  }

  static Future<void> showNow(
    BuildContext context,
    List<UserGuideStep> steps, {
    bool persistSeen = true,
  }) async {
    final validSteps =
        steps.where((s) => s.targetKey.currentContext != null).toList();
    if (validSteps.isEmpty || !context.mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    bool closed = false;

    void closeGuide() {
      if (closed) return;
      closed = true;
      entry.remove();
      if (persistSeen) {
        markGuideSeen();
      }
    }

    entry = OverlayEntry(
      builder: (_) => _UserGuideOverlayWidget(
        steps: validSteps,
        onFinish: closeGuide,
      ),
    );
    overlay.insert(entry);
  }
}

class _UserGuideOverlayWidget extends StatefulWidget {
  final List<UserGuideStep> steps;
  final VoidCallback onFinish;

  const _UserGuideOverlayWidget({
    required this.steps,
    required this.onFinish,
  });

  @override
  State<_UserGuideOverlayWidget> createState() =>
      _UserGuideOverlayWidgetState();
}

class _UserGuideOverlayWidgetState extends State<_UserGuideOverlayWidget> {
  int _index = 0;

  static const _primaryGreen = Color(0xFF1BAA56);

  Rect? _getTargetRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onFinish();
      return;
    }
    setState(() => _index += 1);
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() => _index -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final rawRect = _getTargetRect(step.targetKey);
    final targetRect = rawRect?.inflate(6);

    final bool showBelow = targetRect == null
        ? true
        : (targetRect.center.dy < screenSize.height * 0.52);

    const horizontalMargin = 16.0;
    final maxCardTop = targetRect == null
        ? screenSize.height * 0.35
        : (showBelow ? targetRect.bottom + 14 : null);
    final maxCardBottom = targetRect == null
        ? null
        : (showBelow ? null : screenSize.height - targetRect.top + 14);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  borderRadius: step.borderRadius,
                ),
              ),
            ),
          ),
          if (targetRect != null)
            Positioned.fromRect(
              rect: targetRect,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(step.borderRadius + 4),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.92),
                      width: 2.2,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: horizontalMargin,
            right: horizontalMargin,
            top: maxCardTop,
            bottom: maxCardBottom,
            child: SafeArea(
              top: showBelow,
              bottom: !showBelow,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            step.icon,
                            color: _primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_index + 1}/${widget.steps.length}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      step.description,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: widget.onFinish,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'Lewati',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        if (_index > 0) ...[
                          OutlinedButton(
                            onPressed: _prev,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Kembali'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            _index >= widget.steps.length - 1
                                ? 'Mengerti!'
                                : 'Lanjut',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;

  _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.68);
    final fullPath = Path()..addRect(Offset.zero & size);

    if (targetRect == null) {
      canvas.drawPath(fullPath, bgPaint);
      return;
    }

    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          targetRect!,
          Radius.circular(borderRadius + 4),
        ),
      );
    final combined = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(combined, bgPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius;
  }
}
