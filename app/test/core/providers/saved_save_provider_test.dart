import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/errors/app_error.dart';
import 'package:statussozo/core/models/save_summary.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/providers/save_provider.dart';
import 'package:statussozo/core/providers/saved_library_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/services/save_coordinator.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeSavedRepository repository;
  late SavedLibraryProvider library;
  late FakeHapticsService haptics;
  late ToastProvider toasts;
  late SaveProvider save;
  late List<ToastCode> shown;

  setUp(() {
    repository = FakeSavedRepository();
    library = SavedLibraryProvider(repository);
    haptics = FakeHapticsService();
    toasts = ToastProvider();
    shown = <ToastCode>[];
    toasts.addListener(() {
      final ToastMessage? message = toasts.value;
      if (message != null) {
        shown.add(message.code);
      }
    });
    save = SaveProvider(
      coordinator: SaveCoordinator(repository),
      library: library,
      haptics: haptics,
      toasts: toasts,
    );
  });
  tearDown(() {
    save.dispose();
    toasts.dispose();
    library.dispose();
  });

  List<StatusItem> batch(List<String> names) =>
      names.map((String n) => statusItem(n)).toList();

  group('SavedLibraryProvider', () {
    test('starts idle and empty', () {
      expect(library.value.phase, ListPhase.idle);
      expect(library.value.items, isEmpty);
      expect(library.value.names, isEmpty);
    });

    test('refresh lists newest first and builds the name set', () async {
      repository.items
        ..add(savedItem('a.jpg', savedAtMs: 100))
        ..add(savedItem('b.jpg', savedAtMs: 300))
        ..add(savedItem('c.mp4', mime: 'video/mp4', savedAtMs: 200));
      await library.refresh();
      expect(library.value.phase, ListPhase.ready);
      expect(library.value.items.map((SavedItem i) => i.name), <String>[
        'b.jpg',
        'c.mp4',
        'a.jpg',
      ]);
      expect(library.value.names, <String>{'a.jpg', 'b.jpg', 'c.mp4'});
    });

    test('refresh failure shows the error and keeps the list', () async {
      repository.items.add(savedItem('a.jpg'));
      await library.refresh();
      repository.listError = const AppError(AppErrorKind.io);
      await library.refresh();
      expect(library.value.phase, ListPhase.error);
      expect(library.value.error?.kind, AppErrorKind.io);
      expect(library.value.items, hasLength(1));
    });

    test('onSaved merges without querying the gallery again', () async {
      library.onSaved(<SavedItem>[savedItem('a.jpg', savedAtMs: 5)]);
      library.onSaved(<SavedItem>[savedItem('b.jpg', savedAtMs: 9)]);
      expect(repository.listCalls, 0);
      expect(library.value.items.map((SavedItem i) => i.name), <String>[
        'b.jpg',
        'a.jpg',
      ]);
      expect(library.value.names, <String>{'a.jpg', 'b.jpg'});
      expect(library.value.phase, ListPhase.ready);
    });

    test('onSaved ignores an empty list and de-duplicates by uri', () async {
      library.onSaved(<SavedItem>[]);
      expect(library.value.phase, ListPhase.idle);
      library.onSaved(<SavedItem>[savedItem('a.jpg')]);
      library.onSaved(<SavedItem>[savedItem('a.jpg')]);
      expect(library.value.items, hasLength(1));
    });

    test('a save during a slow refresh is not lost', () async {
      repository.delay = const Duration(milliseconds: 20);
      final Future<void> refreshing = library.refresh();
      library.onSaved(<SavedItem>[savedItem('new.jpg')]);
      await refreshing;
      expect(library.value.items.map((SavedItem i) => i.name), <String>[
        'new.jpg',
      ]);
    });

    test('a delete during a slow refresh is not undone', () async {
      final SavedItem item = savedItem('gone.jpg');
      repository.items.add(item);
      await library.refresh();
      repository.delay = const Duration(milliseconds: 20);
      final Future<void> refreshing = library.refresh();
      repository.delay = Duration.zero;
      await library.delete(<SavedItem>[item]);
      await refreshing;
      expect(library.value.items, isEmpty);
    });

    test('delete removes items one by one and reports the outcome', () async {
      final SavedItem a = savedItem('a.jpg');
      final SavedItem b = savedItem('b.jpg');
      final SavedItem c = savedItem('c.jpg');
      repository.items.addAll(<SavedItem>[a, b, c]);
      await library.refresh();
      repository.deleteErrors[b.uri] = const AppError(
        AppErrorKind.permissionLost,
      );

      final DeleteOutcome outcome = await library.delete(<SavedItem>[a, b, c]);
      expect(outcome.deleted, 2);
      expect(outcome.failed, 1);
      expect(outcome.firstError?.kind, AppErrorKind.permissionLost);
      expect(library.value.items.map((SavedItem i) => i.name), <String>['b.jpg']);
      expect(library.value.names, <String>{'b.jpg'});
    });
  });

  group('SaveProvider', () {
    test('starts idle', () {
      expect(save.value.saving, isFalse);
      expect(save.value.last, isNull);
    });

    test('saving updates the library and the badge set', () async {
      final SaveSummary? summary = await save.save(
        batch(<String>['a.jpg', 'b.jpg']),
      );
      expect(summary?.saved, hasLength(2));
      expect(library.value.names, <String>{'a.jpg', 'b.jpg'});
      expect(library.value.items, hasLength(2));
      expect(repository.listCalls, 0);
      expect(save.value.saving, isFalse);
      expect(save.value.last, same(summary));
      expect(haptics.successCount, 1);
    });

    test('success emits one saved toast with the count', () async {
      await save.save(batch(<String>['a.jpg', 'b.jpg', 'c.jpg']));
      expect(shown, <ToastCode>[ToastCode.saved]);
      expect(toasts.value?.count, 3);
      expect(toasts.value?.kind, ToastKind.success);
    });

    test('names already saved are skipped', () async {
      await save.save(batch(<String>['a.jpg']));
      toasts.dismiss();
      shown.clear();
      repository.saveCalls = 0;

      final SaveSummary? summary = await save.save(
        batch(<String>['a.jpg', 'b.jpg']),
      );
      expect(summary?.skippedDuplicates, 1);
      expect(summary?.saved, hasLength(1));
      expect(repository.saveCalls, 1);
    });

    test('everything already saved emits alreadySaved and no haptic', () async {
      await save.save(batch(<String>['a.jpg']));
      toasts.dismiss();
      shown.clear();
      final int hapticsBefore = haptics.successCount;

      await save.save(batch(<String>['a.jpg']));
      expect(shown, <ToastCode>[ToastCode.alreadySaved]);
      expect(haptics.successCount, hapticsBefore);
    });

    test('a partial result emits savedPartial with both counts', () async {
      repository.saveErrors['b.jpg'] = const AppError(AppErrorKind.io);
      await save.save(batch(<String>['a.jpg', 'b.jpg', 'c.jpg']));
      expect(shown, <ToastCode>[ToastCode.savedPartial]);
      expect(toasts.value?.count, 2);
      expect(toasts.value?.secondCount, 1);
    });

    test('total failure emits saveFailed', () async {
      repository.saveErrors['a.jpg'] = const AppError(AppErrorKind.io);
      await save.save(batch(<String>['a.jpg']));
      expect(shown, <ToastCode>[ToastCode.saveFailed]);
      expect(haptics.successCount, 0);
    });

    test('lost folder access emits accessLost', () async {
      repository.saveErrors['a.jpg'] = const AppError(
        AppErrorKind.accessLost,
      );
      await save.save(batch(<String>['a.jpg']));
      expect(shown, <ToastCode>[ToastCode.accessLost]);
    });

    test('an empty batch is refused and emits nothing', () async {
      expect(await save.save(<StatusItem>[]), isNull);
      expect(shown, isEmpty);
    });

    test('a second save while one runs is refused', () async {
      repository.delay = const Duration(milliseconds: 20);
      final Future<SaveSummary?> first = save.save(batch(<String>['a.jpg']));
      expect(save.value.saving, isTrue);
      final SaveSummary? second = await save.save(batch(<String>['b.jpg']));
      expect(second, isNull);
      await first;
      expect(repository.saveCalls, 1);
    });

    test('reports progress while saving', () async {
      repository.delay = const Duration(milliseconds: 5);
      final List<String> seen = <String>[];
      save.addListener(() {
        if (save.value.saving) {
          seen.add('${save.value.done}/${save.value.total}');
        }
      });
      await save.save(batch(<String>['a.jpg', 'b.jpg']));
      expect(seen, containsAllInOrder(<String>['0/2', '1/2', '2/2']));
      expect(save.value.saving, isFalse);
      expect(save.value.done, 2);
    });
  });
}
