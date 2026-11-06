import 'package:in_app_review/in_app_review.dart';
import 'package:statussozo/core/contracts/review_service.dart';
import 'package:statussozo/utils/app_log.dart';

/// The Google Play in-app review prompt. Nothing here throws.
class InAppReviewService implements ReviewService {
  @override
  Future<bool> isAvailable() async {
    try {
      return await InAppReview.instance.isAvailable();
    } on Object catch (error) {
      AppLog.warn('review', 'Could not check the review prompt', error);
      return false;
    }
  }

  @override
  Future<void> requestReview() async {
    try {
      await InAppReview.instance.requestReview();
    } on Object catch (error) {
      AppLog.warn('review', 'Could not request the review prompt', error);
    }
  }
}
