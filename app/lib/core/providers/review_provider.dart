import 'dart:async';

import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/review_service.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';
import 'package:statussozo/utils/app_log.dart';

/// Decides when to ask for a store review, and counts toward it.
///
/// The prompt is requested once, after [AppConfig.reviewMinSaves] saved items
/// on at least [AppConfig.reviewMinDays] different days, and never while an
/// interstitial is showing or just after one. The system itself decides whether
/// the prompt appears. A person who taps the Rate row has reviewed, so the
/// prompt is never requested after that.
class ReviewProvider {
  ReviewProvider({
    required SettingsProvider settings,
    required ReviewService service,
    required bool Function() adBusy,
    DateTime Function()? now,
  }) : _settings = settings,
       _service = service,
       _adBusy = adBusy,
       _now = now ?? DateTime.now;

  final SettingsProvider _settings;
  final ReviewService _service;

  /// True while an interstitial is showing or was shown moments ago.
  final bool Function() _adBusy;
  final DateTime Function() _now;

  bool _requesting = false;

  /// The person went to the store to review on their own, so never ask again.
  Future<void> markAsked() => _settings.update(
    (AppSettings s) => s.copyWith(reviewAsked: true),
  );

  /// [items] items were just saved successfully.
  Future<void> onSaved(int items) async {
    if (items <= 0) {
      return;
    }
    final String today = dayKey(_now());
    await _settings.update((AppSettings s) {
      final bool newDay = s.reviewLastDay != today;
      return s.copyWith(
        reviewSaves: s.reviewSaves + items,
        reviewDays: newDay ? s.reviewDays + 1 : s.reviewDays,
        reviewLastDay: today,
      );
    });
    await _maybeAsk();
  }

  Future<void> _maybeAsk() async {
    final AppSettings s = _settings.settings;
    if (_requesting ||
        s.reviewAsked ||
        s.reviewSaves < AppConfig.reviewMinSaves ||
        s.reviewDays < AppConfig.reviewMinDays ||
        _adBusy()) {
      return;
    }
    _requesting = true;
    try {
      if (!await _service.isAvailable()) {
        return;
      }
      // Marked before asking, so a crash or a failure never leads to asking
      // again and again.
      await _settings.update(
        (AppSettings current) => current.copyWith(reviewAsked: true),
      );
      await _service.requestReview();
    } on Object catch (error) {
      AppLog.warn('review', 'The review prompt failed', error);
    } finally {
      _requesting = false;
    }
  }
}
