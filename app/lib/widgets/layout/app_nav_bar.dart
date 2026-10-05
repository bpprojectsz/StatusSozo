import 'package:flutter/widgets.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/nav_icon_button.dart';

/// The nav bar: at least 56 px tall, brand or back chip on the start edge, the
/// title, and actions on the end edge as 40 x 40 chips. Marked as a header for
/// screen readers and mirrored in right-to-left layouts.
///
/// The wordmark exists only in [AppNavBar.home], so the brand appears once per
/// screen.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const <Widget>[],
  });

  /// Home: the wordmark on the start edge, [actions] on the end edge.
  factory AppNavBar.home({
    required List<Widget> actions,
    Key? key,
  }) => AppNavBar(key: key, leading: const _Wordmark(), actions: actions);

  /// A pushed screen: back chip, title, optional [actions].
  factory AppNavBar.pushed({
    required String title,
    required VoidCallback onBack,
    Key? key,
    List<Widget> actions = const <Widget>[],
  }) => AppNavBar(
    key: key,
    leading: _BackChip(onBack: onBack),
    title: _PushedTitle(title),
    actions: actions,
  );

  /// Selection mode: close chip, "{n} selected", [actions].
  factory AppNavBar.selection({
    required int count,
    required VoidCallback onClose,
    required List<Widget> actions,
    Key? key,
  }) => AppNavBar(
    key: key,
    leading: _CloseChip(onClose: onClose),
    title: _SelectionTitle(count),
    actions: actions,
  );

  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Widget? start = leading;
    final Widget? middle = title;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.navBar),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: Row(
          children: <Widget>[
            if (start != null) start,
            if (middle != null && start != null)
              const SizedBox(width: AppSpacing.sm),
            Expanded(child: middle ?? const SizedBox.shrink()),
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0 || middle != null || start != null)
                const SizedBox(width: AppSpacing.sm),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    final String name = AppLocalizations.of(context).appName;
    return Semantics(
      header: true,
      child: Text(name, style: styles.wordmark),
    );
  }
}

class _PushedTitle extends StatelessWidget {
  const _PushedTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    return Semantics(
      header: true,
      child: Text(text, style: styles.title1),
    );
  }
}

class _SelectionTitle extends StatelessWidget {
  const _SelectionTitle(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppTextStyles styles = AppTextStyles.of(context);
    return Semantics(
      header: true,
      child: Text(
        AppLocalizations.of(context).selectedCount(count),
        style: styles.title2,
      ),
    );
  }
}

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return NavIconButton(
      icon: AppIcons.back,
      semanticLabel: AppLocalizations.of(context).commonBack,
      mirrorInRtl: true,
      onPressed: onBack,
    );
  }
}

class _CloseChip extends StatelessWidget {
  const _CloseChip({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return NavIconButton(
      icon: AppIcons.close,
      semanticLabel: AppLocalizations.of(context).commonClose,
      onPressed: onClose,
    );
  }
}
