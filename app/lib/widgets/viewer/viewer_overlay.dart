import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// Top and bottom chrome for the viewer: gradient scrims (scrim to transparent)
/// that fade over 200 ms, ignore touches while hidden, and honour safe areas.
class ViewerOverlay extends StatelessWidget {
  const ViewerOverlay({
    required this.visible,
    super.key,
    this.top,
    this.bottom,
  });

  final bool visible;
  final Widget? top;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final Color clear = colors.scrim.withValues(alpha: 0);
    final Widget? header = top;
    final Widget? footer = bottom;

    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.resolve(context, AppMotion.viewerControls),
          curve: AppMotion.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (header != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[colors.scrim, clear],
                    ),
                  ),
                  child: SafeArea(bottom: false, child: header),
                ),
              const Spacer(),
              if (footer != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[colors.scrim, clear],
                    ),
                  ),
                  child: SafeArea(top: false, child: footer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
