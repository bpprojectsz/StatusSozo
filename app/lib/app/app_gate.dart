import 'package:flutter/widgets.dart';
import 'package:statussozo/app/app_scope.dart';
import 'package:statussozo/app/app_services.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/design/design.dart';
import 'package:statussozo/screens/access_screen.dart';
import 'package:statussozo/screens/home_screen.dart';

/// Chooses the first screen.
///
/// Optimistic: when a grant is stored it shows Home straight away, and the
/// verification that runs after the first frame corrects it if the access is
/// gone, so there is no loading flash. No grants means the first-run access
/// screen. Grants that are all verified as lost mean the renewal screen. A
/// usable source next to a lost one is handled inside Home.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        services.settings,
        services.folderAccess,
      ]),
      builder: (BuildContext context, Widget? _) {
        if (!services.settings.value.loaded) {
          return ColoredBox(color: AppColors.of(context).bgPrimary);
        }
        final Set<StatusSource> granted =
            services.settings.settings.grants.keys.toSet();
        if (granted.isEmpty) {
          return const AccessScreen(key: ValueKey<String>('gate-first'));
        }
        final FolderAccessState access = services.folderAccess.value;
        final bool pending = granted.any(
          (StatusSource s) => access.statusOf(s) == AccessStatus.unknown,
        );
        if (services.folderAccess.hasUsableSource || pending) {
          return const HomeScreen(key: ValueKey<String>('gate-home'));
        }
        return const AccessScreen(
          key: ValueKey<String>('gate-renewal'),
          mode: AccessMode.renewal,
        );
      },
    );
  }
}
