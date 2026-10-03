/// Port for touch feedback. Fire-and-forget.
abstract interface class HapticsService {
  void selection();

  void light();

  void success();
}
