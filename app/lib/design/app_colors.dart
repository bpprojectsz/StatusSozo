import 'package:flutter/material.dart';

/// The only place colour literals exist. Every other file reads these tokens.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.accent,
    required this.accentDim,
    required this.accentOn,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.borderFocus,
    required this.error,
    required this.success,
    required this.warning,
    required this.scrim,
    required this.viewerBg,
    required this.onScrim,
  });

  /// Scaffold background.
  final Color bgPrimary;

  /// Cards, sheets, grouped rows.
  final Color bgSecondary;

  /// Chips, thumbnail placeholders, segmented track.
  final Color bgTertiary;

  /// Primary actions, active states, links.
  final Color accent;

  /// Pressed fill of accent surfaces.
  final Color accentDim;

  /// Text and icons on [accent].
  final Color accentOn;

  /// Tinted hero surface, selected tile wash.
  final Color accentSoft;

  /// Headlines and body.
  final Color textPrimary;

  /// Subtitles and secondary lines.
  final Color textSecondary;

  /// Footnotes and section headers. Never placed on [bgTertiary].
  final Color textTertiary;

  /// Hairline borders and dividers.
  final Color borderSubtle;

  /// Keyboard focus ring.
  final Color borderFocus;

  /// Errors and destructive actions.
  final Color error;

  /// Saved and connected states.
  final Color success;

  /// Attention.
  final Color warning;

  /// Overlays on media (black at 55%).
  final Color scrim;

  /// Viewer background.
  final Color viewerBg;

  /// Icons and text over media.
  final Color onScrim;

  static const AppColors light = AppColors(
    bgPrimary: Color(0xFFF2F2F7),
    bgSecondary: Color(0xFFFFFFFF),
    bgTertiary: Color(0xFFE9E9F0),
    accent: Color(0xFF4F46E5),
    accentDim: Color(0xFF4338CA),
    accentOn: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFECEBFF),
    textPrimary: Color(0xFF0E0E14),
    textSecondary: Color(0xFF55556A),
    textTertiary: Color(0xFF6B6B80),
    borderSubtle: Color(0xFFDCDCE6),
    borderFocus: Color(0xFF4F46E5),
    error: Color(0xFFC42B1F),
    success: Color(0xFF067647),
    warning: Color(0xFFB54708),
    scrim: Color(0x8C000000),
    viewerBg: Color(0xFF000000),
    onScrim: Color(0xFFFFFFFF),
  );

  static const AppColors dark = AppColors(
    bgPrimary: Color(0xFF0A0A0F),
    bgSecondary: Color(0xFF16161D),
    bgTertiary: Color(0xFF22222C),
    accent: Color(0xFF8B93FF),
    accentDim: Color(0xFF727AF5),
    accentOn: Color(0xFF0A0A12),
    accentSoft: Color(0xFF23244A),
    textPrimary: Color(0xFFF5F5FA),
    textSecondary: Color(0xFFB4B4C6),
    textTertiary: Color(0xFF8E8EA3),
    borderSubtle: Color(0xFF2A2A35),
    borderFocus: Color(0xFF8B93FF),
    error: Color(0xFFFF6B60),
    success: Color(0xFF3DD598),
    warning: Color(0xFFFFB020),
    scrim: Color(0x8C000000),
    viewerBg: Color(0xFF000000),
    onScrim: Color(0xFFFFFFFF),
  );

  /// Reads the active colours from the theme. Falls back to [light] when no
  /// theme extension is installed (for example above the MaterialApp).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgTertiary,
    Color? accent,
    Color? accentDim,
    Color? accentOn,
    Color? accentSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? borderSubtle,
    Color? borderFocus,
    Color? error,
    Color? success,
    Color? warning,
    Color? scrim,
    Color? viewerBg,
    Color? onScrim,
  }) {
    return AppColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgTertiary: bgTertiary ?? this.bgTertiary,
      accent: accent ?? this.accent,
      accentDim: accentDim ?? this.accentDim,
      accentOn: accentOn ?? this.accentOn,
      accentSoft: accentSoft ?? this.accentSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderFocus: borderFocus ?? this.borderFocus,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      scrim: scrim ?? this.scrim,
      viewerBg: viewerBg ?? this.viewerBg,
      onScrim: onScrim ?? this.onScrim,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      bgTertiary: Color.lerp(bgTertiary, other.bgTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      viewerBg: Color.lerp(viewerBg, other.viewerBg, t)!,
      onScrim: Color.lerp(onScrim, other.onScrim, t)!,
    );
  }
}
