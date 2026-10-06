// Test helper: wraps a widget in the real theme, localisation and direction.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';

Widget harness(
  Widget child, {
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double width = 360,
  bool disableAnimations = false,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? app) {
      final MediaQueryData base = MediaQuery.of(context);
      return MediaQuery(
        data: base.copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          viewInsets: viewInsets,
          padding: padding,
          viewPadding: padding,
        ),
        child: Directionality(textDirection: direction, child: app!),
      );
    },
    home: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

/// Sets a phone-sized surface for the test.
void useSurface(WidgetTester tester, {double width = 400, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
