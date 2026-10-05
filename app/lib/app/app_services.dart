import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:statussozo/core/contracts/haptics_service.dart';
import 'package:statussozo/core/contracts/link_launcher.dart';
import 'package:statussozo/core/contracts/saved_repository.dart';
import 'package:statussozo/core/contracts/settings_store.dart';
import 'package:statussozo/core/contracts/share_service.dart';
import 'package:statussozo/core/contracts/status_repository.dart';
import 'package:statussozo/core/contracts/thumbnail_source.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/providers/folder_access_provider.dart';
import 'package:statussozo/core/providers/save_provider.dart';
import 'package:statussozo/core/providers/saved_library_provider.dart';
import 'package:statussozo/core/providers/selection_provider.dart';
import 'package:statussozo/core/providers/settings_provider.dart';
import 'package:statussozo/core/providers/source_provider.dart';
import 'package:statussozo/core/providers/status_list_provider.dart';
import 'package:statussozo/core/providers/theme_provider.dart';
import 'package:statussozo/core/providers/toast_provider.dart';
import 'package:statussozo/core/services/save_coordinator.dart';
import 'package:statussozo/platform/media_store_saved_repository.dart';
import 'package:statussozo/platform/native_thumbnail_source.dart';
import 'package:statussozo/platform/plus_share_service.dart';
import 'package:statussozo/platform/prefs_settings_store.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/platform/saf_status_repository.dart';
import 'package:statussozo/platform/system_haptics.dart';
import 'package:statussozo/platform/url_link_launcher.dart';
import 'package:statussozo/platform/video_player_session.dart';

/// The dependency container and wiring. This file (and the temporary spike) is
/// the only place platform classes are constructed; everything else receives
/// contracts.
class AppServices {
  AppServices._({
    required this.statusRepository,
    required this.savedRepository,
    required this.thumbnails,
    required this.share,
    required this.links,
    required this.haptics,
    required this.videoFactory,
    required this.appVersion,
    required this.settings,
    required this.theme,
    required this.source,
    required this.folderAccess,
    required this.statusList,
    required this.savedLibrary,
    required this.homeSelection,
    required this.savedSelection,
    required this.save,
    required this.toasts,
  });

  /// Builds the real platform implementations.
  static Future<AppServices> create() async {
    final SafChannel channel = SafChannel();
    final PackageInfo info = await PackageInfo.fromPlatform();
    return _assemble(
      statusRepository: SafStatusRepository(channel),
      savedRepository: MediaStoreSavedRepository(channel),
      thumbnails: NativeThumbnailSource(channel),
      share: PlusShareService(channel),
      settingsStore: PrefsSettingsStore(),
      links: UrlLinkLauncher(),
      haptics: const SystemHaptics(),
      videoFactory: const VideoPlayerSessionFactory(),
      appVersion: '${info.version} (${info.buildNumber})',
    );
  }

  /// Builds the container from fakes.
  factory AppServices.forTesting({
    required StatusRepository statusRepository,
    required SavedRepository savedRepository,
    required ThumbnailSource thumbnails,
    required ShareService share,
    required SettingsStore settingsStore,
    required LinkLauncher links,
    required HapticsService haptics,
    required VideoSessionFactory videoFactory,
    String appVersion = '1.0.0 (1)',
  }) => _assemble(
    statusRepository: statusRepository,
    savedRepository: savedRepository,
    thumbnails: thumbnails,
    share: share,
    settingsStore: settingsStore,
    links: links,
    haptics: haptics,
    videoFactory: videoFactory,
    appVersion: appVersion,
  );

  static AppServices _assemble({
    required StatusRepository statusRepository,
    required SavedRepository savedRepository,
    required ThumbnailSource thumbnails,
    required ShareService share,
    required SettingsStore settingsStore,
    required LinkLauncher links,
    required HapticsService haptics,
    required VideoSessionFactory videoFactory,
    required String appVersion,
  }) {
    final SettingsProvider settings = SettingsProvider(settingsStore);
    final ThemeProvider theme = ThemeProvider(settings);
    final SourceProvider source = SourceProvider(settings);
    final FolderAccessProvider folderAccess = FolderAccessProvider(
      repository: statusRepository,
      settings: settings,
      source: source,
    );
    final StatusListProvider statusList = StatusListProvider(
      repository: statusRepository,
      settings: settings,
      source: source,
    );
    final SavedLibraryProvider savedLibrary = SavedLibraryProvider(
      savedRepository,
    );
    final ToastProvider toasts = ToastProvider();
    final SaveProvider save = SaveProvider(
      coordinator: SaveCoordinator(savedRepository),
      library: savedLibrary,
      haptics: haptics,
      toasts: toasts,
    );
    final AppServices services = AppServices._(
      statusRepository: statusRepository,
      savedRepository: savedRepository,
      thumbnails: thumbnails,
      share: share,
      links: links,
      haptics: haptics,
      videoFactory: videoFactory,
      appVersion: appVersion,
      settings: settings,
      theme: theme,
      source: source,
      folderAccess: folderAccess,
      statusList: statusList,
      savedLibrary: savedLibrary,
      homeSelection: SelectionProvider(),
      savedSelection: SelectionProvider(),
      save: save,
      toasts: toasts,
    );
    services._wire();
    return services;
  }

  // Contracts.
  final StatusRepository statusRepository;
  final SavedRepository savedRepository;
  final ThumbnailSource thumbnails;
  final ShareService share;
  final LinkLauncher links;
  final HapticsService haptics;
  final VideoSessionFactory videoFactory;

  /// The version string shown in Settings, loaded once at startup so screens
  /// never import a plugin.
  final String appVersion;

  // Providers.
  final SettingsProvider settings;
  final ThemeProvider theme;
  final SourceProvider source;
  final FolderAccessProvider folderAccess;
  final StatusListProvider statusList;
  final SavedLibraryProvider savedLibrary;
  final SelectionProvider homeSelection;
  final SelectionProvider savedSelection;
  final SaveProvider save;
  final ToastProvider toasts;

  bool _warningShown = false;
  AccessStatus _lastSourceStatus = AccessStatus.unknown;
  StatusSource? _lastSource;
  bool _disposed = false;

  /// Connects the providers to each other. Called once by the factories.
  void _wire() {
    _lastSource = source.value;
    // A list that fails because access was lost re-checks every grant.
    statusList.onAccessLost = () => unawaited(folderAccess.verifyAll());
    settings.addListener(_onSettingsChanged);
    statusList.addListener(_onListChanged);
    savedLibrary.addListener(_onSavedChanged);
    source.addListener(_onSourceChanged);
    folderAccess.addListener(_onAccessChanged);
  }

  void _onSettingsChanged() {
    if (settings.consumeRecovered()) {
      toasts.show(ToastCode.settingsRecovered);
    }
    final bool warning = settings.value.persistenceWarning;
    if (warning && !_warningShown) {
      toasts.show(ToastCode.persistenceWarning, sticky: true);
    }
    _warningShown = warning;
  }

  // A refresh can remove items, so selected ids that vanished are dropped.
  void _onListChanged() {
    homeSelection.retainOnly(
      statusList.value.items.map((StatusItem i) => i.id),
    );
  }

  void _onSavedChanged() {
    savedSelection.retainOnly(
      savedLibrary.value.items.map((SavedItem i) => i.id),
    );
  }

  // Switching source leaves selection mode.
  void _onSourceChanged() {
    if (source.value != _lastSource) {
      _lastSource = source.value;
      homeSelection.clear();
      _lastSourceStatus = folderAccess.value.statusOf(source.value);
    }
  }

  // When the selected source gains or loses a working grant (connect or
  // disconnect), reload its list. The very first verification at startup is
  // left to bootstrap().
  void _onAccessChanged() {
    final AccessStatus now = folderAccess.value.statusOf(source.value);
    final AccessStatus before = _lastSourceStatus;
    _lastSourceStatus = now;
    if (before != AccessStatus.unknown &&
        before != now &&
        (now == AccessStatus.connected || now == AccessStatus.notConnected)) {
      unawaited(statusList.refresh());
    }
  }

  /// Runs after the first frame: verify grants, load the list, load the saved
  /// library, prune the share cache.
  Future<void> bootstrap() async {
    await folderAccess.verifyAll();
    await statusList.refresh();
    await savedLibrary.refresh();
    await share.pruneCache();
  }

  /// The resume handler: re-verify grants, then silently refresh. The old list
  /// stays on screen until the new one arrives.
  Future<void> refreshAll() async {
    await folderAccess.verifyAll();
    await statusList.refresh(silent: true);
    await savedLibrary.refresh();
  }

  /// Releases every notifier. Call once.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    settings.removeListener(_onSettingsChanged);
    statusList.removeListener(_onListChanged);
    savedLibrary.removeListener(_onSavedChanged);
    source.removeListener(_onSourceChanged);
    folderAccess.removeListener(_onAccessChanged);
    save.dispose();
    homeSelection.dispose();
    savedSelection.dispose();
    statusList.dispose();
    savedLibrary.dispose();
    folderAccess.dispose();
    source.dispose();
    theme.dispose();
    toasts.dispose();
    settings.dispose();
  }
}
