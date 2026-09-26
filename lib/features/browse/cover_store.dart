import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

const coverAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

typedef CoverFetch = Future<Uint8List?> Function(String url);

class CoverStore extends ChangeNotifier {
  CoverStore({this.fetch, Future<Directory> Function()? folder}) : _folder = folder ?? getApplicationSupportDirectory;

  final CoverFetch? fetch;
  final Future<Directory> Function() _folder;
  final Map<String, Uint8List> _ready = {};
  final Set<String> _missed = {};
  final List<String> _queue = [];
  final Map<String, Completer<void>> _waiters = {};
  final Map<String, int> _pins = {};
  final Map<String, int> _tries = {};
  final Set<String> _working = {};
  var _generation = 0;
  String? _focus;
  Directory? _directory;
  Future<Directory?>? _directoryTask;
  HttpClient? _client;

  String? get focus => _focus;

  bool get busy => _working.isNotEmpty || _queue.isNotEmpty || _waiters.isNotEmpty;

  Uint8List? of(String? url) {
    if (url == null) {
      return null;
    }
    final bytes = _ready.remove(url);
    if (bytes == null) {
      return null;
    }
    _ready[url] = bytes;
    return bytes;
  }

  bool missed(String url) => _missed.contains(url);

  /// Yalnızca ekranda görünen kapak. Tüm katalog inmeden bekletilmez.
  Future<void> touch(String url) {
    if (url.isEmpty) {
      return Future<void>.value();
    }
    _pins[url] = (_pins[url] ?? 0) + 1;
    if (_ready.containsKey(url) || _missed.contains(url)) {
      return Future<void>.value();
    }
    final pending = _waiters[url];
    if (pending != null) {
      return pending.future;
    }
    final done = Completer<void>();
    _waiters[url] = done;
    _queue.add(url);
    scheduleMicrotask(_drain);
    return done.future;
  }

  void release(String url) {
    final left = (_pins[url] ?? 0) - 1;
    if (left > 0) {
      _pins[url] = left;
      return;
    }
    _pins.remove(url);
    _queue.remove(url);
    if (_working.contains(url)) {
      return;
    }
    final waiter = _waiters.remove(url);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  void _drain() {
    final generation = _generation;
    while (generation == _generation && _working.length < 12 && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      if ((_pins[url] ?? 0) < 1) {
        final waiter = _waiters.remove(url);
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete();
        }
        continue;
      }
      _working.add(url);
      _load(url, generation).then((retry) {
        _working.remove(url);
        if (generation != _generation) {
          return;
        }
        final still = (_pins[url] ?? 0) > 0;
        if (retry && still) {
          _queue.add(url);
        } else {
          final waiter = _waiters.remove(url);
          if (waiter != null && !waiter.isCompleted) {
            waiter.complete();
          }
          if (!retry) {
            _focus = url;
            notifyListeners();
          }
        }
        _drain();
      });
    }
  }

  Future<bool> _load(String url, int generation) async {
    final cached = await _readFile(url);
    if (generation != _generation) {
      return false;
    }
    if (cached != null && _looksLikeImage(cached)) {
      _keep(url, cached);
      return false;
    }
    if (cached != null) {
      await _deleteFile(url);
    }
    final pulled = await (fetch == null ? _download(url) : _pullCustom(url));
    if (generation != _generation) {
      return false;
    }
    final bytes = pulled.bytes;
    if (bytes != null && _looksLikeImage(bytes)) {
      _keep(url, bytes);
      await _writeFile(url, bytes);
      _tries.remove(url);
      return false;
    }
    if (pulled.gone) {
      _missed.add(url);
      _tries.remove(url);
      return false;
    }
    final tries = (_tries[url] ?? 0) + 1;
    _tries[url] = tries;
    if (tries < 3) {
      return true;
    }
    _missed.add(url);
    _tries.remove(url);
    return false;
  }

  Future<_Pull> _pullCustom(String url) async {
    try {
      final bytes = await fetch!(url);
      if (bytes == null) {
        return const _Pull(null, false);
      }
      return _Pull(bytes, false);
    } catch (_) {
      return const _Pull(null, false);
    }
  }

  void _keep(String url, Uint8List bytes) {
    _missed.remove(url);
    _ready.remove(url);
    _ready[url] = bytes;
    while (_ready.length > 240) {
      _ready.remove(_ready.keys.first);
    }
  }

  Future<_Pull> _download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return const _Pull(null, true);
    }
    final client = _client ??= HttpClient()
      ..maxConnectionsPerHost = 12
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = (certificate, host, port) => true;
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, coverAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8');
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode == 404 || response.statusCode == 410) {
        await response.drain<void>();
        return const _Pull(null, true);
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        return const _Pull(null, false);
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      return _Pull(bytes, false);
    } catch (_) {
      return const _Pull(null, false);
    }
  }

  Future<Directory?> _dir() {
    final ready = _directory;
    if (ready != null) {
      return Future<Directory?>.value(ready);
    }
    final pending = _directoryTask;
    if (pending != null) {
      return pending;
    }
    final task = _openDir();
    _directoryTask = task;
    return task;
  }

  Future<Directory?> _openDir() async {
    try {
      final wait = _folder();
      final base = Platform.environment.containsKey('FLUTTER_TEST')
          ? await wait.timeout(const Duration(seconds: 2))
          : await wait;
      final dir = Directory('${base.path}/kapaklar');
      await dir.create(recursive: true);
      _directory = dir;
      return dir;
    } catch (_) {
      _directoryTask = null;
      return null;
    }
  }

  Future<Uint8List?> _readFile(String url) async {
    final dir = await _dir();
    if (dir == null) {
      return null;
    }
    final file = File('${dir.path}/${_coverName(url)}');
    if (!file.existsSync()) {
      return null;
    }
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeFile(String url, Uint8List bytes) async {
    final dir = await _dir();
    if (dir == null) {
      return;
    }
    try {
      await File('${dir.path}/${_coverName(url)}').writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  Future<void> _deleteFile(String url) async {
    final dir = await _dir();
    if (dir == null) {
      return;
    }
    try {
      final file = File('${dir.path}/${_coverName(url)}');
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _generation += 1;
    _client?.close(force: true);
    super.dispose();
  }
}

class _Pull {
  const _Pull(this.bytes, this.gone);

  final Uint8List? bytes;
  final bool gone;
}

bool _looksLikeImage(Uint8List bytes) {
  if (bytes.length <= 32) {
    return false;
  }
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return true;
  }
  if (bytes[0] == 0x89 && bytes[1] == 0x50) {
    return true;
  }
  if (bytes[0] == 0x47 && bytes[1] == 0x49) {
    return true;
  }
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
    return true;
  }
  return bytes.length > 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[8] == 0x57 && bytes[9] == 0x45;
}

String _coverName(String url) {
  var hash = 0xcbf29ce484222325;
  for (final unit in url.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return '${hash.toRadixString(16)}_${url.length}.img';
}

class CoverScope extends InheritedNotifier<CoverStore> {
  const CoverScope({super.key, required CoverStore store, required super.child}) : super(notifier: store);

  static CoverStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CoverScope>();
    assert(scope != null, 'CoverScope yok');
    return scope!.notifier!;
  }

  static CoverStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<CoverScope>();
    assert(scope != null, 'CoverScope yok');
    return scope!.notifier!;
  }
}

class CoverImage extends StatefulWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.cacheWidth = 480,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit fit;
  final Widget? fallback;
  final int cacheWidth;
  final Alignment alignment;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  CoverStore? _store;
  String? _held;
  Uint8List? _bytes;
  var _missed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = CoverScope.read(context);
    if (!identical(store, _store)) {
      _store?.removeListener(_sync);
      if (_held != null) {
        _store?.release(_held!);
        _held = null;
      }
      _store = store;
      store.addListener(_sync);
    }
    _hold(store);
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final store = _store;
    if (store != null && oldWidget.url != widget.url) {
      _hold(store);
    }
  }

  void _hold(CoverStore store) {
    if (_held == widget.url) {
      _bytes = store.of(widget.url);
      _missed = store.missed(widget.url);
      return;
    }
    if (_held != null) {
      store.release(_held!);
    }
    _held = widget.url;
    _bytes = store.of(widget.url);
    _missed = store.missed(widget.url);
    store.touch(widget.url);
  }

  void _sync() {
    final focus = _store?.focus;
    if (focus != null && focus != widget.url) {
      return;
    }
    final next = _store?.of(widget.url);
    final missed = _store?.missed(widget.url) ?? false;
    if ((identical(next, _bytes) && missed == _missed) || !mounted) {
      return;
    }
    setState(() {
      _bytes = next;
      _missed = missed;
    });
  }

  @override
  void dispose() {
    if (_held != null) {
      _store?.release(_held!);
    }
    _store?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final broken = widget.fallback ?? const SizedBox.shrink();
    if (bytes == null) {
      return _missed ? broken : const SizedBox.shrink();
    }
    return Image.memory(
      bytes,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => broken,
    );
  }
}
