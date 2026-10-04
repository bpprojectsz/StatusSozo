import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/providers/toast_provider.dart';

void main() {
  const Duration threeSeconds = Duration(seconds: 3);

  testWidgets('shows a message with its code, kind and counts', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    expect(toasts.value, isNull);
    toasts.show(ToastCode.savedPartial, count: 2, secondCount: 1);
    expect(toasts.value?.code, ToastCode.savedPartial);
    expect(toasts.value?.kind, ToastKind.warning);
    expect(toasts.value?.count, 2);
    expect(toasts.value?.secondCount, 1);
    expect(toasts.value?.sticky, isFalse);
    toasts.dispose();
  });

  testWidgets('auto-dismisses after three seconds', (WidgetTester tester) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 1);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(toasts.value, isNotNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('a sticky toast stays until dismissed', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.persistenceWarning, sticky: true);
    await tester.pump(const Duration(seconds: 30));
    expect(toasts.value?.code, ToastCode.persistenceWarning);
    toasts.dismiss();
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('only one is visible; the next waits its turn', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 1);
    toasts.show(ToastCode.deleted, count: 2);
    expect(toasts.value?.code, ToastCode.saved);
    await tester.pump(threeSeconds);
    expect(toasts.value?.code, ToastCode.deleted);
    await tester.pump(threeSeconds);
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('an identical message within one second is dropped', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    int shown = 0;
    toasts.addListener(() {
      if (toasts.value != null) {
        shown++;
      }
    });
    toasts.show(ToastCode.saveFailed);
    toasts.show(ToastCode.saveFailed);
    await tester.pump(const Duration(milliseconds: 500));
    toasts.show(ToastCode.saveFailed);
    expect(shown, 1);
    await tester.pump(threeSeconds);
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('the same message is allowed again after the window', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saveFailed);
    await tester.pump(const Duration(milliseconds: 1100));
    toasts.show(ToastCode.saveFailed);
    await tester.pump(threeSeconds);
    expect(toasts.value?.code, ToastCode.saveFailed);
    await tester.pump(threeSeconds);
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('different counts are different messages', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 1);
    toasts.show(ToastCode.saved, count: 2);
    expect(toasts.value?.count, 1);
    await tester.pump(threeSeconds);
    expect(toasts.value?.count, 2);
    await tester.pump(threeSeconds);
    toasts.dispose();
  });

  testWidgets('a new message replaces a sticky one, which returns afterwards', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.persistenceWarning, sticky: true);
    toasts.show(ToastCode.saved, count: 1);
    expect(toasts.value?.code, ToastCode.saved);
    await tester.pump(threeSeconds);
    expect(toasts.value?.code, ToastCode.persistenceWarning);
    expect(toasts.value?.sticky, isTrue);
    await tester.pump(const Duration(seconds: 30));
    expect(toasts.value?.code, ToastCode.persistenceWarning);
    toasts.dismiss();
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('dismiss with a stale id does nothing', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 1);
    final int id = toasts.value!.id;
    toasts.dismiss(id: id + 99);
    expect(toasts.value, isNotNull);
    toasts.dismiss(id: id);
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('dismiss shows the next queued message', (
    WidgetTester tester,
  ) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 1);
    toasts.show(ToastCode.deleted, count: 1);
    toasts.dismiss();
    expect(toasts.value?.code, ToastCode.deleted);
    await tester.pump(threeSeconds);
    expect(toasts.value, isNull);
    toasts.dispose();
  });

  testWidgets('the queue is capped', (WidgetTester tester) async {
    final ToastProvider toasts = ToastProvider();
    toasts.show(ToastCode.saved, count: 0);
    for (int i = 1; i <= 10; i++) {
      toasts.show(ToastCode.saved, count: i);
    }
    int visible = 1;
    while (toasts.value != null) {
      await tester.pump(threeSeconds);
      if (toasts.value != null) {
        visible++;
      }
    }
    expect(visible, 1 + ToastProvider.maxQueue);
    toasts.dispose();
  });

  testWidgets('carries a retry callback', (WidgetTester tester) async {
    final ToastProvider toasts = ToastProvider();
    int retried = 0;
    toasts.show(ToastCode.saveFailed, retry: () => retried++);
    toasts.value?.retry?.call();
    expect(retried, 1);
    toasts.dispose();
  });

  test('every code has a default kind', () {
    for (final ToastCode code in ToastCode.values) {
      expect(ToastKind.values, contains(defaultToastKind(code)));
    }
    expect(defaultToastKind(ToastCode.saved), ToastKind.success);
    expect(defaultToastKind(ToastCode.alreadySaved), ToastKind.info);
    expect(defaultToastKind(ToastCode.persistenceWarning), ToastKind.warning);
    expect(defaultToastKind(ToastCode.saveFailed), ToastKind.error);
  });

  test('the code list matches the specification', () {
    expect(ToastCode.values, hasLength(17));
    expect(ToastCode.saved.name, 'saved');
  });
}
