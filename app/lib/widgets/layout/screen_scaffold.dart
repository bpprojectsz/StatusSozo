import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';

/// The standard shape of every screen: nav bar, primary content, optional
/// bottom embed.
///
/// * Background is `bgPrimary` and the safe area is protected on every edge.
/// * The layout is fixed. Chrome stays put and only content lists scroll.
/// * [floating] is an overlay slot at the bottom of the content, used by the
///   selection bar. It sits above the bottom embed.
/// * While the keyboard is open the whole bottom embed (gap, border and
///   reserved height) is removed, so the layout is stable under the keyboard.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.body,
    super.key,
    this.navBar,
    this.bottomEmbed,
    this.floating,
  });

  final Widget? navBar;
  final Widget body;
  final Widget? bottomEmbed;
  final Widget? floating;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final Widget? header = navBar;
    final Widget? floatingBar = floating;
    final Widget? embed = bottomEmbed;

    return ColoredBox(
      color: colors.bgPrimary,
      child: DefaultTextStyle(
        style: styles.body,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (header != null) header,
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: body),
                    if (floatingBar != null)
                      Positioned.fill(
                        child: Align(
                          alignment: AlignmentDirectional.bottomCenter,
                          child: floatingBar,
                        ),
                      ),
                  ],
                ),
              ),
              if (embed != null && !keyboardOpen) embed,
            ],
          ),
        ),
      ),
    );
  }
}
