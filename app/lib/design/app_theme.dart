import 'package:flutter/material.dart';
import 'package:statussozo/design/app_colors.dart';
import 'package:statussozo/design/app_typography.dart';

/// Builds [ThemeData] from tokens. Material is only the invisible scaffolding
/// layer: every Material surface is overridden or unused.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final AppTextStyles styles = AppTextStyles.fromColors(colors);
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.accentOn,
      secondary: colors.accent,
      onSecondary: colors.accentOn,
      error: colors.error,
      onError: colors.accentOn,
      surface: colors.bgSecondary,
      onSurface: colors.textPrimary,
      surfaceTint: Colors.transparent,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.bgPrimary,
      canvasColor: colors.bgPrimary,
      fontFamily: 'Inter',
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      dividerColor: colors.borderSubtle,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
          TargetPlatform.fuchsia: _NoTransitionsBuilder(),
          TargetPlatform.linux: _NoTransitionsBuilder(),
          TargetPlatform.macOS: _NoTransitionsBuilder(),
          TargetPlatform.windows: _NoTransitionsBuilder(),
        },
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbVisibility: WidgetStatePropertyAll<bool>(false),
        trackVisibility: WidgetStatePropertyAll<bool>(false),
        thickness: WidgetStatePropertyAll<double>(0),
      ),
      extensions: <ThemeExtension<dynamic>>[colors, styles],
    );
  }
}

/// Applies no transition: motion is owned by `AppPageRoute`.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
