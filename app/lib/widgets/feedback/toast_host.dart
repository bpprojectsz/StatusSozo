import 'package:flutter/widgets.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/icons/app_icon.dart';
import 'package:statussozo/widgets/icons/app_icons.dart';
import 'package:statussozo/widgets/primitives/app_chip.dart';

/// The localised text of a toast message.
String toastText(AppLocalizations l10n, ToastMessage message) {
  final int count = message.count ?? 1;
  return switch (message.code) {
    ToastCode.saved => l10n.toastSaved(count),
    ToastCode.savedPartial => l10n.toastSavedPartial(
      message.count ?? 0,
      message.secondCount ?? 0,
    ),
    ToastCode.alreadySaved => l10n.toastAlreadySaved,
    ToastCode.saveFailed => l10n.toastSaveFailed,
    ToastCode.deleted => l10n.toastDeleted(count),
    ToastCode.deleteFailed => l10n.toastDeleteFailed,
    ToastCode.shareFailed => l10n.toastShareFailed,
    ToastCode.folderConnected => l10n.toastFolderConnected,
    ToastCode.folderDisconnected => l10n.toastFolderDisconnected,
    ToastCode.wrongFolder => l10n.toastWrongFolder,
    ToastCode.pickerCancelled => l10n.toastPickerCancelled,
    ToastCode.accessLost => l10n.toastAccessLost,
    ToastCode.settingsRecovered => l10n.toastSettingsRecovered,
    ToastCode.persistenceWarning => l10n.toastPersistenceWarning,
    ToastCode.linkFailed => l10n.toastLinkFailed,
    ToastCode.ioError => l10n.toastIoError,
    ToastCode.unexpected => l10n.toastUnexpected,
  };
}

/// Where toasts appear. Place it above all routes.
///
/// One pill is anchored below the top safe area. It shows an icon plus text,
/// so colour is never the only cue. It slides and fades in over 300 ms
/// (instantly under reduce motion), is announced as a live region, and
/// dismisses on tap.
class ToastHost extends StatelessWidget {
  const ToastHost({required this.provider, required this.child, super.key});

  final ToastProvider provider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: ListenableBuilder(
            listenable: provider,
            builder: (BuildContext context, Widget? _) {
              return _ToastLayer(message: provider.value, provider: provider);
            },
          ),
        ),
      ],
    );
  }
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.message, required this.provider});

  final ToastMessage? message;
  final ToastProvider provider;

  @override
  Widget build(BuildContext context) {
    final ToastMessage? current = message;
    final double top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: top,
        start: AppSpacing.gutter,
        end: AppSpacing.gutter,
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.resolve(context, AppMotion.toast),
        switchInCurve: AppMotion.easeOut,
        switchOutCurve: AppMotion.easeOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: current == null
            ? const SizedBox.shrink(key: ValueKey<int>(0))
            : _ToastPill(
                key: ValueKey<int>(current.id),
                message: current,
                provider: provider,
              ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({
    required this.message,
    required this.provider,
    super.key,
  });

  final ToastMessage message;
  final ToastProvider provider;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.of(context);
    final AppTextStyles styles = AppTextStyles.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String text = toastText(l10n, message);
    final VoidCallback? retry = message.retry;

    final (AppIconData icon, Color tint) = switch (message.kind) {
      ToastKind.success => (AppIcons.checkCircle, colors.success),
      ToastKind.info => (AppIcons.info, colors.textSecondary),
      ToastKind.warning => (AppIcons.warning, colors.warning),
      ToastKind.error => (AppIcons.error, colors.error),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          liveRegion: true,
          container: true,
          label: text,
          excludeSemantics: retry == null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.dismiss(id: message.id),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.bgSecondary,
                borderRadius: AppRadii.pillRadius,
                border: Border.all(
                  color: colors.borderSubtle,
                  width: AppSizes.hairline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppIcon(icon, size: AppSizes.iconNav, color: tint),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: Text(text, style: styles.footnote)),
                    if (retry != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: l10n.toastRetry,
                        onPressed: () {
                          provider.dismiss(id: message.id);
                          retry();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
