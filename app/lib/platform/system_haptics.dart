import 'dart:async';

import 'package:flutter/services.dart';
import 'package:statussozo/core/contracts/haptics_service.dart';

/// [HapticsService] over `HapticFeedback`. Fire-and-forget; failures are ignored.
class SystemHaptics implements HapticsService {
  const SystemHaptics();

  void _fire(Future<void> feedback) {
    unawaited(feedback.catchError((Object _) {}));
  }

  @override
  void selection() => _fire(HapticFeedback.selectionClick());

  @override
  void light() => _fire(HapticFeedback.lightImpact());

  @override
  void success() => _fire(HapticFeedback.mediumImpact());
}
