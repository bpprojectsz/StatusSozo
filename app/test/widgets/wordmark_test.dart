import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/core/app_config.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/widgets/layout/app_nav_bar.dart';

void main() {
  test('the two wordmark halves spell the app name', () {
    expect(
      AppConfig.wordmarkHead + AppConfig.wordmarkTail,
      AppConfig.appName,
    );
  });

  for (final bool dark in <bool>[false, true]) {
    testWidgets('the wordmark is split text colour and accent in '
        '${dark ? 'dark' : 'light'}', (WidgetTester tester) async {
      final ThemeData theme = dark ? AppTheme.dark() : AppTheme.light();
      final AppColors colors = dark ? AppColors.dark : AppColors.light;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: AppNavBar.home(actions: const <Widget>[]),
          ),
        ),
      );
      final RichText rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (Widget w) =>
              w is RichText && w.text.toPlainText() == AppConfig.appName,
        ),
      );
      // Text.rich wraps the given span in the ambient default style.
      final TextSpan root = (rich.text as TextSpan).children!.single as TextSpan;
      expect(root.style?.color, colors.textPrimary);
      expect(root.style?.fontSize, 26);
      expect(root.style?.fontWeight, FontWeight.w800);
      final List<TextSpan> parts = root.children!.cast<TextSpan>();
      expect(parts.map((TextSpan s) => s.text), <String?>[
        AppConfig.wordmarkHead,
        AppConfig.wordmarkTail,
      ]);
      expect(parts[0].style?.color, isNull);
      expect(parts[1].style?.color, colors.accent);
    });
  }
}
