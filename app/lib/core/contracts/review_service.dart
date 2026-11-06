/// Port for the store's in-app review prompt. **No method may throw.**
abstract interface class ReviewService {
  /// Whether the system can show the review prompt on this device.
  Future<bool> isAvailable();

  /// Asks the system to show the review prompt. The system decides whether it
  /// actually appears, and limits how often.
  Future<void> requestReview();
}
