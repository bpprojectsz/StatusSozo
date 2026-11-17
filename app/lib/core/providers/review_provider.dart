import 'dart:async';

import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/core/contracts/review_service.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/services/interstitial_policy.dart';
import 'package:statussozo/utils/app_log.dart';

/// Decides when to ask for a store review, and counts toward it.
///
/// The first request comes after [AppConfig.reviewMinSaves] saved items on at
/// least [AppConfig.reviewMinDays] different days. After that only time counts:
/// [AppConfig.reviewCooldowns] sets the wait before the next request (30 days,
/// then 90, then 180 for every later one), and a request is only ever made
/// right after a save. Never while an interstitial is showing or within
/// [AppConfig.reviewQuietAfterInterstitial] of one. The system itself decides
/// whether the prompt appears. Tapping the Rate row in Settings opens the store
/// page and changes nothing here.
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

  /// How long to wait after the [asks]th request before the next one.
  static Duration cooldownAfter(int asks) {
    if (asks <= 0) {
      return Duration.zero;
    }
    const List<Duration> steps = AppConfig.reviewCooldowns;
    return steps[(asks - 1).clamp(0, steps.length - 1)];
  }

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
    if (_requesting || _adBusy()) {
      return;
    }
    final AppSettings s = _settings.settings;
    final int nowMs = _now().millisecondsSinceEpoch;
    if (s.reviewAskCount == 0) {
      if (s.reviewSaves < AppConfig.reviewMinSaves ||
          s.reviewDays < AppConfig.reviewMinDays) {
        return;
      }
    } else {
      final int? last = s.reviewLastAskedMs;
      if (last == null) {
        // Settings from before the cooldowns: the wait starts now.
        await _settings.update(
          (AppSettings current) => current.copyWith(reviewLastAskedMs: nowMs),
        );
        return;
      }
      if (nowMs - last < cooldownAfter(s.reviewAskCount).inMilliseconds) {
        return;
      }
    }
    _requesting = true;
    try {
      if (!await _service.isAvailable()) {
        return;
      }
      // Counted before asking, so a crash or a failure never leads to asking
      // again and again.
      await _settings.update(
        (AppSettings current) => current.copyWith(
          reviewAskCount: current.reviewAskCount + 1,
          reviewLastAskedMs: nowMs,
        ),
      );
      await _service.requestReview();
    } on Object catch (error) {
      AppLog.warn('review', 'The review prompt failed', error);
    } finally {
      _requesting = false;
    }
  }
}
