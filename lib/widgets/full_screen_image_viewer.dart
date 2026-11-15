import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformCtrl = TransformationController();
  Offset? _doubleTapLocalPos;
  bool _showCloseButton = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformCtrl.value != Matrix4.identity()) {
      _transformCtrl.value = Matrix4.identity();
      return;
    }
    final pos = _doubleTapLocalPos;
    if (pos == null) return;
    const scale = 2.5;
    _transformCtrl.value = Matrix4.identity()
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        final total = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        return Center(
          child: CircularProgressIndicator(
            value: total != null && total > 0 ? loaded / total : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 56,
        ),
      ),
    );

    if (widget.heroTag != null) {
      imageWidget = Hero(tag: widget.heroTag!, child: imageWidget);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => setState(() => _showCloseButton = !_showCloseButton),
            onDoubleTapDown: (details) =>
                _doubleTapLocalPos = details.localPosition,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 1.0,
              maxScale: 4.5,
              clipBehavior: Clip.none,
              child: Center(child: imageWidget),
            ),
          ),
          if (_showCloseButton)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
