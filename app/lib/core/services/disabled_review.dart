import 'package:statussozo/core/contracts/review_service.dart';

/// A review service that never shows anything. Used in tests.
class DisabledReviewService implements ReviewService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}
}
