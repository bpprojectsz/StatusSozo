import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/core/models/status_item.dart';

import '../fakes/fakes.dart';

void main() {
  late FakeReviewService review;
  late FakeSettingsStore store;
  late DateTime clock;
  late AppServices services;

  setUp(() async {
    review = FakeReviewService();
    store = FakeSettingsStore();
    clock = DateTime(2026, 11, 3, 12);
    services = AppServices.forTesting(
      statusRepository: FakeStatusRepository(),
      savedRepository: FakeSavedRepository(),
      thumbnails: FakeThumbnailSource(),
      share: FakeShareService(),
      settingsStore: store,
      links: FakeLinkLauncher(),
      haptics: FakeHapticsService(),
      videoFactory: FakeVideoSessionFactory(),
      reviewService: review,
      now: () => clock,
    );
    await services.settings.load();
  });
  tearDown(() => services.dispose());

  List<StatusItem> items(String prefix, int n) => <StatusItem>[
    for (int i = 0; i < n; i++) statusItem('$prefix$i.jpg'),
  ];

  test('every finished save counts toward the review prompt', () async {
    await services.save.save(items('a', 4));
    clock = clock.add(const Duration(days: 1));
    await services.save.save(items('b', 3));
    expect(services.settings.settings.reviewSaves, 7);
    expect(services.settings.settings.reviewDays, 2);
    expect(review.requestCalls, 0);
  });

  test('the prompt is requested after ten saves on three days', () async {
    await services.save.save(items('a', 4));
    clock = clock.add(const Duration(days: 1));
    await services.save.save(items('b', 3));
    clock = clock.add(const Duration(days: 1));
    await services.save.save(items('c', 3));
    await Future<void>.delayed(Duration.zero);
    expect(review.requestCalls, 1);
  });

  test('a save that saved nothing new is not counted', () async {
    await services.save.save(items('a', 2));
    await services.save.save(items('a', 2));
    expect(services.settings.settings.reviewSaves, 2);
  });
}
