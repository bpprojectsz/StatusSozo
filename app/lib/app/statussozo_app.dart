import 'package:flutter/material.dart';
import 'package:statussozo/app/app_gate.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/app/error_handling.dart';
import 'package:statussozo/app/lifecycle_refresher.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/l10n/gen/app_localizations.dart';
import 'package:statussozo/widgets/feedback/toast_host.dart';

/// The application widget.
class StatusSozoApp extends StatefulWidget {
  const StatusSozoApp({required this.services, super.key});

  final AppServices services;

  @override
  State<StatusSozoApp> createState() => _StatusSozoAppState();
}

class _StatusSozoAppState extends State<StatusSozoApp>
    with WidgetsBindingObserver {
  late final LifecycleRefresher _refresher = LifecycleRefresher(
    widget.services,
  );

  static const bool _perfOverlay = bool.fromEnvironment('PERF_OVERLAY');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresher.start();
  }

  @override
  void dispose() {
    _refresher.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {}); // ui-local
  }

  static ThemeMode _modeFor(ThemePreference preference) => switch (preference) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  @override
  Widget build(BuildContext context) {
    final AppServices services = widget.services;
    final bool reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    return ValueListenableBuilder<int>(
      valueListenable: AppRestart.signal,
      builder: (BuildContext context, int generation, Widget? _) {
        return KeyedSubtree(
          key: ValueKey<int>(generation),
          child: AppScope(
            services: services,
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                services.theme,
                services.locale,
              ]),
              builder: (BuildContext context, Widget? _) {
                final ThemePreference pref = services.theme.value;
                final String? language = services.locale.value;
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  showPerformanceOverlay: _perfOverlay,
                  onGenerateTitle: (BuildContext c) =>
                      AppLocalizations.of(c).appName,
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: _modeFor(pref),
                  locale: language == null ? null : Locale(language),
                  themeAnimationDuration: reduceMotion
                      ? Duration.zero
                      : AppMotion.theme,
                  themeAnimationCurve: AppMotion.linear,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  scrollBehavior: const AppScrollBehavior(),
                  builder: (BuildContext context, Widget? app) =>
                      ToastHost(provider: services.toasts, child: app!),
                  home: const AppGate(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
