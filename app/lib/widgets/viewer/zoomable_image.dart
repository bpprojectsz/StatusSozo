import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// Pinch and double-tap zoom for an image: 1x to 4x, with a double tap that
/// animates between 1x and 2.5x over 200 ms (instantly under reduce motion).
///
/// It reports whether the image is zoomed so the pager can lock horizontal
/// swiping. Panning is enabled only while zoomed, so one-finger swipes at 1x
/// go to the pager.
class ZoomableImage extends StatefulWidget {
  const ZoomableImage({
    required this.bytes,
    super.key,
    this.onZoomChanged,
    this.onTap,
  });

  final Uint8List bytes;
  final ValueChanged<bool>? onZoomChanged;

  /// A single tap. It fires after the double-tap window.
  final VoidCallback? onTap;

  static const double minScale = 1;
  static const double maxScale = 4;
  static const double doubleTapScale = 2.5;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: AppMotion.viewerControls,
  );
  Animation<Matrix4>? _tween;
  Offset _doubleTapAt = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
    _animation.addListener(_onTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _animation.removeListener(_onTick);
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    final Animation<Matrix4>? tween = _tween;
    if (tween != null) {
      _controller.value = tween.value;
    }
  }

  void _onTransform() {
    final bool zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed); // ui-local
      widget.onZoomChanged?.call(zoomed);
    }
  }

  void _toggleZoom() {
    final Matrix4 start = _controller.value.clone();
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      const double scale = ZoomableImage.doubleTapScale;
      end = Matrix4.identity()
        ..translate(
          -_doubleTapAt.dx * (scale - 1),
          -_doubleTapAt.dy * (scale - 1),
        )
        ..scale(scale);
    }
    if (AppMotion.reduced(context)) {
      _controller.value = end;
      return;
    }
    _tween = Matrix4Tween(
      begin: start,
      end: end,
    ).animate(_animation.drive(CurveTween(curve: AppMotion.easeOut)));
    _animation
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (TapDownDetails details) =>
          _doubleTapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: ZoomableImage.minScale,
        maxScale: ZoomableImage.maxScale,
        panEnabled: _zoomed,
        child: SizedBox.expand(
          child: Image.memory(
            widget.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? trace) =>
                    const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
