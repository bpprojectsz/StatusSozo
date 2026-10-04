// THROWAWAY harness for the E1 device check. Excluded from tool/check_forbidden.sh
// and deleted in batch 12. It talks to the platform layer directly so the
// native code can be proven on a real phone before any UI exists.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:statussozo/core/contracts/video_playback.dart';
import 'package:statussozo/core/models/app_settings.dart';
import 'package:statussozo/core/models/folder_grant.dart';
import 'package:statussozo/core/models/saved_item.dart';
import 'package:statussozo/core/models/status_item.dart';
import 'package:statussozo/core/models/status_source.dart';
import 'package:statussozo/core/result.dart';
import 'package:statussozo/core/services/status_organizer.dart';
import 'package:statussozo/platform/media_store_saved_repository.dart';
import 'package:statussozo/platform/native_thumbnail_source.dart';
import 'package:statussozo/platform/prefs_settings_store.dart';
import 'package:statussozo/platform/saf_channel.dart';
import 'package:statussozo/platform/saf_status_repository.dart';
import 'package:statussozo/platform/video_player_session.dart';

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SpikeScreen(),
    );
  }
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final SafChannel _channel = SafChannel();
  late final SafStatusRepository _status = SafStatusRepository(_channel);
  late final MediaStoreSavedRepository _saved = MediaStoreSavedRepository(
    _channel,
  );
  late final NativeThumbnailSource _thumbs = NativeThumbnailSource(_channel);
  final PrefsSettingsStore _store = PrefsSettingsStore();
  final VideoPlayerSessionFactory _videoFactory =
      const VideoPlayerSessionFactory();

  AppSettings _settings = AppSettings.defaults();
  List<StatusItem> _items = <StatusItem>[];
  List<SavedItem> _savedItems = <SavedItem>[];
  final List<Uint8List?> _thumbnails = <Uint8List?>[];
  VideoSession? _video;
  final List<String> _log = <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _say(String line) {
    if (!mounted) {
      return;
    }
    setState(() => _log.insert(0, line));
  }

  Future<void> _load() async {
    final stored = await _store.load();
    _settings = stored.settings;
    _say(
      'settings loaded: recovered=${stored.recovered} '
      'persistence=${stored.persistenceAvailable} '
      'grants=${_settings.grants.keys.map((s) => s.id).toList()} '
      'source=${_settings.lastSource.id}',
    );
  }

  Future<void> _connect(StatusSource source) async {
    final result = await _status.pickFolder(source);
    switch (result) {
      case Err<FolderGrant>(:final error):
        _say('connect ${source.id}: ERROR ${error.kind.name} ${error.detail}');
      case Ok<FolderGrant>(:final value):
        _settings = _settings.copyWith(
          lastSource: source,
          grants: <StatusSource, FolderGrant>{
            ..._settings.grants,
            source: value,
          },
        );
        final saved = await _store.save(_settings);
        _say('connect ${source.id}: OK ${value.treeUri} (settings saved=$saved)');
    }
  }

  FolderGrant? get _grant => _settings.grants[_settings.lastSource];

  Future<void> _checkAccess() async {
    if (_settings.grants.isEmpty) {
      _say('check access: no grants stored');
      return;
    }
    for (final grant in _settings.grants.values) {
      final ok = await _status.hasAccess(grant);
      _say('hasAccess ${grant.source.id}: $ok');
    }
  }

  Future<void> _list() async {
    final grant = _grant;
    if (grant == null) {
      _say('list: ${_settings.lastSource.id} is not connected');
      return;
    }
    final watch = Stopwatch()..start();
    final result = await _status.list(grant);
    watch.stop();
    switch (result) {
      case Err<List<StatusItem>>(:final error):
        _say('list: ERROR ${error.kind.name} ${error.detail}');
      case Ok<List<StatusItem>>(:final value):
        final sorted = StatusOrganizer.newestFirst(value);
        setState(() {
          _items = sorted;
          _thumbnails.clear();
        });
        _say(
          'list ${grant.source.id}: ${value.length} items '
          '(${StatusOrganizer.photos(value).length} photos, '
          '${StatusOrganizer.videos(value).length} videos) in '
          '${watch.elapsedMilliseconds} ms. First: '
          '${sorted.take(3).map((i) => i.name).join(', ')}',
        );
    }
  }

  Future<void> _loadThumbnails() async {
    if (_items.isEmpty) {
      _say('thumbnails: list first');
      return;
    }
    final watch = Stopwatch()..start();
    final loaded = <Uint8List?>[];
    for (final item in _items.take(6)) {
      loaded.add(await _thumbs.thumbnail(item, 256));
    }
    watch.stop();
    setState(() {
      _thumbnails
        ..clear()
        ..addAll(loaded);
    });
    _say(
      'thumbnails: ${loaded.where((b) => b != null).length} of '
      '${loaded.length} decoded in ${watch.elapsedMilliseconds} ms',
    );
  }

  Future<void> _saveFirst({required bool video}) async {
    StatusItem? target;
    for (final item in _items) {
      if (item.kind.isVideo == video) {
        target = item;
        break;
      }
    }
    if (target == null) {
      _say('save: no ${video ? 'video' : 'photo'} in the list');
      return;
    }
    final watch = Stopwatch()..start();
    final result = await _saved.save(target);
    watch.stop();
    switch (result) {
      case Err<SavedItem>(:final error):
        _say('save ${target.name}: ERROR ${error.kind.name} ${error.detail}');
      case Ok<SavedItem>(:final value):
        _say(
          'save ${target.name}: OK -> ${value.uri} as ${value.name} '
          'in ${watch.elapsedMilliseconds} ms',
        );
    }
  }

  Future<void> _listSaved() async {
    final result = await _saved.list();
    switch (result) {
      case Err<List<SavedItem>>(:final error):
        _say('list saved: ERROR ${error.kind.name} ${error.detail}');
      case Ok<List<SavedItem>>(:final value):
        setState(() => _savedItems = value);
        _say(
          'list saved: ${value.length} items: '
          '${value.take(5).map((i) => i.name).join(', ')}',
        );
    }
  }

  Future<void> _deleteFirstSaved() async {
    if (_savedItems.isEmpty) {
      _say('delete: list saved first');
      return;
    }
    final target = _savedItems.first;
    final result = await _saved.delete(target);
    switch (result) {
      case Err<void>(:final error):
        _say('delete ${target.name}: ERROR ${error.kind.name} ${error.detail}');
      case Ok<void>():
        _say('delete ${target.name}: OK');
        await _listSaved();
    }
  }

  Future<void> _playFirstVideo() async {
    StatusItem? target;
    for (final item in _items) {
      if (item.kind.isVideo) {
        target = item;
        break;
      }
    }
    if (target == null) {
      _say('play: no video in the list');
      return;
    }
    _video?.dispose();
    final session = _videoFactory.create(target.uri);
    setState(() => _video = session);
    final watch = Stopwatch()..start();
    await session.initialise();
    watch.stop();
    final state = session.state.value;
    _say(
      'play ${target.name}: initialised=${state.initialised} '
      'error=${state.hasError} duration=${state.duration} '
      'in ${watch.elapsedMilliseconds} ms',
    );
    if (state.initialised) {
      await session.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      appBar: AppBar(title: const Text('StatusSozo spike (E1)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text('Source: ${_settings.lastSource.id}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () => unawaited(_connect(StatusSource.standard)),
                  child: const Text('1 Connect Standard'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_connect(StatusSource.business)),
                  child: const Text('2 Connect Business'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_checkAccess()),
                  child: const Text('3 Check access'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_list()),
                  child: const Text('4 List'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_loadThumbnails()),
                  child: const Text('5 Thumbnails'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_saveFirst(video: false)),
                  child: const Text('6 Save first photo'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_saveFirst(video: true)),
                  child: const Text('7 Save first video'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_listSaved()),
                  child: const Text('8 List saved'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_deleteFirstSaved()),
                  child: const Text('9 Delete first saved'),
                ),
                ElevatedButton(
                  onPressed: () => unawaited(_playFirstVideo()),
                  child: const Text('10 Play first video'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_thumbnails.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final bytes in _thumbnails)
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: bytes == null
                          ? const ColoredBox(
                              color: Color(0xFFCCCCCC),
                              child: Center(child: Text('null')),
                            )
                          : Image.memory(bytes, fit: BoxFit.cover),
                    ),
                ],
              ),
            if (video != null) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ColoredBox(
                  color: const Color(0xFF000000),
                  child: ValueListenableBuilder<VideoState>(
                    valueListenable: video.state,
                    builder: (context, state, _) {
                      if (state.hasError) {
                        return const Center(
                          child: Text(
                            'video error',
                            style: TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                        );
                      }
                      return state.initialised
                          ? video.buildSurface()
                          : const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Log (newest first)'),
            for (final line in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText(line, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
