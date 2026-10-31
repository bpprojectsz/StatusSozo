import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/app/error_handling.dart';
import 'package:statussozo/app/statussozo_app.dart';

void main() {
  runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final AppServices services = await AppServices.create();
    await services.settings.load();
    installGlobalErrorHandling(services);
    runApp(StatusSozoApp(services: services));
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      unawaited(services.bootstrap());
    });
  });
}
