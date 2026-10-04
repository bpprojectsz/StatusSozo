import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/providers/selection_provider.dart';

void main() {
  late SelectionProvider selection;
  setUp(() => selection = SelectionProvider());
  tearDown(() => selection.dispose());

  test('starts inactive and empty', () {
    expect(selection.value.active, isFalse);
    expect(selection.value.ids, isEmpty);
    expect(selection.value.count, 0);
  });

  test('the first toggle enters selection mode', () {
    selection.toggle('a');
    expect(selection.value.active, isTrue);
    expect(selection.value.ids, <String>{'a'});
    expect(selection.value.isSelected('a'), isTrue);
    expect(selection.value.isSelected('b'), isFalse);
  });

  test('toggle adds and removes', () {
    selection
      ..toggle('a')
      ..toggle('b');
    expect(selection.value.count, 2);
    selection.toggle('a');
    expect(selection.value.ids, <String>{'b'});
    expect(selection.value.active, isTrue);
  });

  test('removing the last id leaves selection mode', () {
    selection
      ..toggle('a')
      ..toggle('a');
    expect(selection.value.active, isFalse);
    expect(selection.value.ids, isEmpty);
  });

  test('selectAll selects everything and activates', () {
    selection.selectAll(<String>['a', 'b', 'c']);
    expect(selection.value.active, isTrue);
    expect(selection.value.ids, <String>{'a', 'b', 'c'});
  });

  test('selectAll with nothing stays inactive', () {
    selection.selectAll(<String>[]);
    expect(selection.value.active, isFalse);
  });

  test('clear leaves selection mode and notifies once', () {
    selection.selectAll(<String>['a', 'b']);
    int notifications = 0;
    selection.addListener(() => notifications++);
    selection.clear();
    selection.clear();
    expect(selection.value.active, isFalse);
    expect(selection.value.ids, isEmpty);
    expect(notifications, 1);
  });

  group('retainOnly', () {
    test('drops ids that no longer exist', () {
      selection.selectAll(<String>['a', 'b', 'c']);
      selection.retainOnly(<String>['b', 'c', 'd']);
      expect(selection.value.ids, <String>{'b', 'c'});
      expect(selection.value.active, isTrue);
    });

    test('leaves selection mode when nothing remains', () {
      selection.selectAll(<String>['a']);
      selection.retainOnly(<String>['z']);
      expect(selection.value.active, isFalse);
      expect(selection.value.ids, isEmpty);
    });

    test('does not notify when nothing changes', () {
      selection.selectAll(<String>['a', 'b']);
      int notifications = 0;
      selection.addListener(() => notifications++);
      selection.retainOnly(<String>['a', 'b', 'c']);
      expect(notifications, 0);
    });

    test('does nothing while inactive', () {
      selection.retainOnly(<String>['a']);
      expect(selection.value.active, isFalse);
    });
  });

  test('the id set is unmodifiable', () {
    selection.toggle('a');
    expect(() => selection.value.ids.add('b'), throwsUnsupportedError);
  });

  test('two instances are independent', () {
    final SelectionProvider other = SelectionProvider();
    selection.toggle('a');
    expect(other.value.active, isFalse);
    other.dispose();
  });
}
