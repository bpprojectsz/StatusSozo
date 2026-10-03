import 'package:flutter/widgets.dart';
import 'package:statussozo/design/app_motion.dart';

/// The one route type. Push 350 ms, pop 280 ms, ease-in-out, fade plus a 20 px
/// slide from the end edge (direction-aware). Under reduce motion the page
/// appears with no movement.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
         pageBuilder: (
           BuildContext context,
           Animation<double> animation,
           Animation<double> secondaryAnimation,
         ) => builder(context),
         transitionDuration: AppMotion.push,
         reverseTransitionDuration: AppMotion.pop,
         transitionsBuilder: _transition,
       );

  static const double _slideDistance = 20;

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) {
      return child;
    }
    final Animation<double> eased = animation.drive(
      CurveTween(curve: AppMotion.easeInOut),
    );
    final double direction =
        Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return FadeTransition(
      opacity: eased,
      child: AnimatedBuilder(
        animation: eased,
        builder: (BuildContext context, Widget? child) {
          return Transform.translate(
            offset: Offset((1 - eased.value) * _slideDistance * direction, 0),
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}
