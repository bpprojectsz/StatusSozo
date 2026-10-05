import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_services.dart';

/// Gives the widget tree access to the services container. The container
/// itself never changes; providers notify on their own, so this never asks
/// dependents to rebuild.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  /// The services of the nearest scope. Asserts that one exists.
  static AppServices of(BuildContext context) {
    final AppServices? found = maybeOf(context);
    assert(found != null, 'No AppScope found above this context.');
    return found!;
  }

  /// The services of the nearest scope, or null.
  static AppServices? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
