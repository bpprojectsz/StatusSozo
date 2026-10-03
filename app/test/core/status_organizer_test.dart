import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/services/status_organizer.dart';

import '../fakes/fakes.dart';

void main() {
  group('newestFirst', () {
    test('orders by modified time, newest first', () {
      final List<StatusItem> sorted = StatusOrganizer.newestFirst(<StatusItem>[
        statusItem('old.jpg', modifiedMs: 100),
        statusItem('new.jpg', modifiedMs: 300),
        statusItem('mid.jpg', modifiedMs: 200),
      ]);
      expect(sorted.map((StatusItem i) => i.name), <String>[
        'new.jpg',
        'mid.jpg',
        'old.jpg',
      ]);
    });

    test('ties are ordered by name descending', () {
      final List<StatusItem> sorted = StatusOrganizer.newestFirst(<StatusItem>[
        statusItem('a.jpg', modifiedMs: 5),
        statusItem('c.jpg', modifiedMs: 5),
        statusItem('b.jpg', modifiedMs: 5),
      ]);
      expect(sorted.map((StatusItem i) => i.name), <String>[
        'c.jpg',
        'b.jpg',
        'a.jpg',
      ]);
    });

    test('is deterministic for identical time and name', () {
      final StatusItem first = statusItem('x.jpg', uri: 'content://a');
      final StatusItem second = statusItem('x.jpg', uri: 'content://b');
      final List<StatusItem> one = StatusOrganizer.newestFirst(<StatusItem>[
        second,
        first,
      ]);
      final List<StatusItem> two = StatusOrganizer.newestFirst(<StatusItem>[
        first,
        second,
      ]);
      expect(one, two);
      expect(one.first.uri, 'content://a');
    });

    test('does not change the input list', () {
      final List<StatusItem> input = <StatusItem>[
        statusItem('a.jpg', modifiedMs: 1),
        statusItem('b.jpg', modifiedMs: 2),
      ];
      StatusOrganizer.newestFirst(input);
      expect(input.first.name, 'a.jpg');
    });

    test('empty list', () {
      expect(StatusOrganizer.newestFirst(<StatusItem>[]), isEmpty);
    });
  });

  group('tab split', () {
    final List<StatusItem> items = <StatusItem>[
      statusItem('a.jpg'),
      statusItem('b.mp4', mime: 'video/mp4'),
      statusItem('c.png', mime: 'image/png'),
      statusItem('d.mp4', mime: 'video/mp4'),
    ];

    test('photos', () {
      expect(StatusOrganizer.photos(items).map((StatusItem i) => i.name), <String>[
        'a.jpg',
        'c.png',
      ]);
    });

    test('videos', () {
      expect(StatusOrganizer.videos(items).map((StatusItem i) => i.name), <String>[
        'b.mp4',
        'd.mp4',
      ]);
    });

    test('the two tabs together cover every item', () {
      expect(
        StatusOrganizer.photos(items).length +
            StatusOrganizer.videos(items).length,
        items.length,
      );
    });
  });

  group('savedNames', () {
    test('collects distinct names', () {
      final Set<String> names = StatusOrganizer.savedNames(<SavedItem>[
        savedItem('a.jpg'),
        savedItem('b.mp4', mime: 'video/mp4'),
        savedItem('a.jpg', uri: 'content://saved/other'),
      ]);
      expect(names, <String>{'a.jpg', 'b.mp4'});
    });

    test('empty list', () {
      expect(StatusOrganizer.savedNames(<SavedItem>[]), isEmpty);
    });
  });
}
