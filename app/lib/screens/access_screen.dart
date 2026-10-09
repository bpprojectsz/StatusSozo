import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/screens/screen_text.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';
import 'package:statussozo/widgets/layout/screen_scaffold.dart';
import 'package:statussozo/widgets/primitives/app_chip.dart';
import 'package:statussozo/widgets/primitives/app_group.dart';
import 'package:statussozo/widgets/primitives/primary_button.dart';
import 'package:statussozo/widgets/primitives/secondary_button.dart';

/// Why the access screen is showing.
enum AccessMode {
  /// First run: nothing is connected yet.
  first,

  /// Every connected source lost its access.
  renewal,

  /// Pushed from Settings to choose a folder again.
  reconnect,
}

/// Connect a folder. A fixed layout: a compact hero card, three numbered steps,
/// and a pinned "Choose folder" button above the safe area. It scrolls only
/// when the text is too large to fit. No wordmark here.
///
/// In [AccessMode.first] and [AccessMode.renewal] the app gate swaps this
/// screen for Home as soon as a source works; in [AccessMode.reconnect] the
/// screen closes itself after a successful connection.
class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key, this.mode = AccessMode.first, this.source});

  final AccessMode mode;

  /// The source to connect. Defaults to the selected source.
  final StatusSource? source;

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  StatusSource? _target;

  StatusSource _resolveTarget() {
    final StatusSource? current = _target;
    if (current != null) {
      return current;
    }
    final StatusSource initial =
        widget.source ?? AppScope.of(context).source.value;
    _target = initial;
    return initial;
  }

  StatusSource _other(StatusSource source) => source == StatusSource.standard
      ? StatusSource.business
      : StatusSource.standard;

  Future<void> _choose() async {
    final services = AppScope.of(context);
    final StatusSource target = _resolveTarget();
    final AppError? error = await services.folderAccess.connect(target);
    if (error != null) {
      services.toasts.show(toastForError(error.kind));
      return;
    }
    services.toasts.show(ToastCode.folderConnected);
    if (widget.mode == AccessMode.reconnect && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _useOther() {
    final services = AppScope.of(context);
    final StatusSource other = _other(_resolveTarget());
    if (services.folderAccess.value.statusOf(other) ==
        AccessStatus.connected) {
      unawaited(services.source.select(other));
    } else {
      setState(() => _target = other); // ui-local
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final StatusSource target = _resolveTarget();
    final StatusSource other = _other(target);

    final String title = switch (widget.mode) {
      AccessMode.first => l10n.accessTitleFirst,
      AccessMode.renewal => l10n.accessTitleRenewal,
      AccessMode.reconnect => l10n.accessTitleReconnect,
    };

    return ListenableBuilder(
      listenable: services.folderAccess,
      builder: (BuildContext context, Widget? _) {
        final bool connecting = services.folderAccess.value.connecting != null;
        final bool showOther = widget.mode != AccessMode.reconnect;
        return ScreenScaffold(
          navBar: widget.mode == AccessMode.reconnect
              ? AppNavBar.pushed(
                  title: l10n.settingsTitle,
                  onBack: () => Navigator.of(context).pop(),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Hero(
                        title: title,
                        body: l10n.accessBody(l10n.appName),
                        sourceLabel: sourceName(l10n, target),
                        colors: colors,
                        styles: styles,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppGroup(
                        dividerInset: AppSpacing.md + _Step.numeral + AppSpacing.md,
                        children: <Widget>[
                          _Step(number: 1, text: l10n.accessStep1),
                          _Step(number: 2, text: l10n.accessStep2),
                          _Step(number: 3, text: l10n.accessStep3),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PrimaryButton(
                      label: l10n.accessChooseFolder,
                      icon: AppIcons.folder,
                      loading: connecting,
                      onPressed: connecting ? null : _choose,
                    ),
                    if (showOther) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        label: l10n.accessUseOther(sourceName(l10n, other)),
                        onPressed: connecting ? null : _useOther,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.accessPrivacyNote,
                      textAlign: TextAlign.center,
                      style: styles.footnote.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.body,
    required this.sourceLabel,
    required this.colors,
    required this.styles,
  });

  final String title;
  final String body;
  final String sourceLabel;
  final AppColors colors;
  final AppTextStyles styles;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: AppRadii.heroRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: AppSizes.heroIconChip,
                  height: AppSizes.heroIconChip,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: AppRadii.cardRadius,
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.folderLink,
                        size: AppSpacing.xl,
                        color: colors.accentOn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: AppChip(label: sourceLabel)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(title, style: styles.headline),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: styles.body),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  /// Diameter of the numeral circle.
  static const double numeral = AppSpacing.xl - AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: numeral,
              height: numeral,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: styles.tabular.copyWith(color: colors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text, style: styles.body)),
          ],
        ),
      ),
    );
  }
}
