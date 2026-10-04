import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// The touch primitive everything tappable is built on.
///
/// * Hit area is at least 48 x 48 around any child (unless [fill] is set, in
///   which case the child keeps its own width and only the height is raised).
/// * Feedback is an opacity change over 150 ms, an optional scale to 0.97, or a
///   background tint when [pressedColor] is set. There is no ripple.
/// * Disabled renders at 40% opacity and ignores input.
/// * Haptics are never triggered here; screens use the haptics contract.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    super.key,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.enabled = true,
    this.pressedOpacity = 0.7,
    this.scaleOnPress = false,
    this.pressedColor,
    this.fill = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  /// Replaces the child's own semantics when set.
  final String? semanticLabel;
  final bool enabled;
  final double pressedOpacity;

  /// Scales to 0.97 while pressed.
  final bool scaleOnPress;

  /// When set, a tint is painted behind the child while pressed instead of
  /// changing its opacity. Used by rows.
  final Color? pressedColor;

  /// Lets the child take its full width instead of shrinking to its content.
  final bool fill;

  static const double disabledOpacity = 0.4;
  static const double pressedScale = 0.97;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _active =>
      widget.enabled &&
      (widget.onPressed != null || widget.onLongPress != null);

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value); // ui-local
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.resolve(context, AppMotion.press);
    final bool pressed = _pressed && _active;
    final bool tinted = widget.pressedColor != null;

    final double opacity;
    if (!widget.enabled) {
      opacity = Pressable.disabledOpacity;
    } else if (pressed && !tinted) {
      opacity = widget.pressedOpacity;
    } else {
      opacity = 1;
    }

    Widget visual = AnimatedOpacity(
      opacity: opacity,
      duration: duration,
      curve: AppMotion.easeOut,
      child: AnimatedScale(
        scale: pressed && widget.scaleOnPress ? Pressable.pressedScale : 1,
        duration: duration,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );

    if (tinted) {
      visual = AnimatedContainer(
        duration: duration,
        curve: AppMotion.easeOut,
        color: pressed ? widget.pressedColor : Colors.transparent,
        child: visual,
      );
    }

    final Widget area = widget.fill
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
            child: visual,
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.touchTarget,
              minHeight: AppSizes.touchTarget,
            ),
            child: Align(widthFactor: 1, heightFactor: 1, child: visual),
          );

    final String? label = widget.semanticLabel;
    return Semantics(
      button: true,
      enabled: _active,
      label: label,
      excludeSemantics: label != null,
      onTap: _active ? widget.onPressed : null,
      onLongPress: _active ? widget.onLongPress : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (TapDownDetails _) => _setPressed(true) : null,
        onTapUp: _active ? (TapUpDetails _) => _setPressed(false) : null,
        onTapCancel: _active ? () => _setPressed(false) : null,
        onTap: _active ? widget.onPressed : null,
        onLongPress: _active
            ? () {
                _setPressed(false);
                widget.onLongPress?.call();
              }
            : null,
        child: area,
      ),
    );
  }
}
