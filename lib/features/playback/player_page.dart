import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/device.dart';
import '../../core/look.dart';
import '../../core/theme.dart';
import '../../core/web_full.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../library/user_source.dart';
import '../library/keep_store.dart';
import '../sync/lounge_link.dart';
import 'data_save.dart';
import 'media_entry.dart';
import 'outside_window.dart';
import 'screen_share.dart';
import 'playback_bus.dart';
import 'stalker_api.dart';
import 'track_labels.dart';
import 'xtream_api.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.cues,
    this.start = 0,
    this.live = false,
    this.library,
    this.bus,
    this.keeps,
    this.link,
    this.adoptedPlayer,
    this.adoptedVideo,
  });

  final List<PlaybackCue> cues;
  final int start;
  final bool live;
  final UserLibrary? library;
  final PlaybackBus? bus;
  final KeepStore? keeps;
  final LoungeLink? link;
  final Player? adoptedPlayer;
  final VideoController? adoptedVideo;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = widget.adoptedPlayer ?? Player();
  late final VideoController _controller = widget.adoptedVideo ?? VideoController(_player);
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late int _index = widget.start.clamp(0, widget.cues.length - 1);
  bool _playing = false;
  bool _failed = false;
  bool _controls = true;
  bool _locked = false;
  bool _full = false;
  bool _muted = false;
  bool _parked = false;
  bool _salon = false;
  bool _perde = false;
  bool _restored = false;
  bool _prefsApplied = false;
  bool _echo = false;
  bool _buffering = false;
  double _rate = 1;
  double _subDelay = 0;
  double _volume = 100;
  double _brightness = 1;

  /// Konum saniyede birkaç kez gelir; yalnızca süre çubuğu yeniden çizilir.
  final _positionNote = ValueNotifier(Duration.zero);
  Duration get _position => _positionNote.value;
  set _position(Duration value) => _positionNote.value = value;
  Duration _duration = Duration.zero;
  final _keysNode = FocusNode(debugLabel: 'Oynatıcı tuşları');
  final _playNode = FocusNode(debugLabel: 'Oynat düğmesi');
  Tracks _tracks = const Tracks();
  Track _selected = const Track();
  VideoParams _videoParams = const VideoParams();
  var _dataNoted = false;
  AudioParams _audioParams = const AudioParams();
  _Stage _stage = _Stage.fit;
  String? _stageHint;
  Timer? _hideTimer;
  Timer? _cursorTimer;
  var _cursorGone = false;
  Timer? _stageTimer;
  Timer? _sleep;
  int? _sleepMinutes;
  DateTime _announced = DateTime.fromMillisecondsSinceEpoch(0);

  PlaybackCue get _cue => widget.cues[_index];
  bool get _hasNext => _index < widget.cues.length - 1;
  bool get _hasPrev => _index > 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    OutsideWindow.bars(true);
    OutsideWindow.watchLeave(() {
      if (!mounted) {
        return;
      }
      _cursorTimer?.cancel();
      setState(() {
        _full = false;
        _cursorGone = false;
      });
    });
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (!mounted) {
          return;
        }
        setState(() {
          _playing = playing;
          if (!playing) {
            _controls = true;
          }
        });
        if (playing) {
          _armHide();
          _restoreOnce();
        } else {
          _hideTimer?.cancel();
          _remember();
        }
        _broadcast(force: true);
      }),
    );
    widget.link?.addListener(_onRemote);
    watchWebFull((on) {
      if (mounted && on != _full) setState(() => _full = on);
    });
    _subscriptions.add(
      _player.stream.position.listen((position) {
        if (!mounted) {
          return;
        }
        _position = position;
        _broadcast();
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
    );
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        if (mounted) setState(() => _tracks = tracks);
        _applyPrefs();
      }),
    );
    _subscriptions.add(
      _player.stream.track.listen((track) {
        if (mounted) setState(() => _selected = track);
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((message) {
        if (message.isEmpty || !mounted) {
          return;
        }
        setState(() => _failed = true);
      }),
    );
    _subscriptions.add(
      _player.stream.videoParams.listen((params) {
        if (mounted) setState(() => _videoParams = params);
        _noteDataSize(params.h);
      }),
    );
    _subscriptions.add(
      _player.stream.audioParams.listen((params) {
        if (mounted) setState(() => _audioParams = params);
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((buffering) {
        if (mounted && buffering != _buffering) setState(() => _buffering = buffering);
      }),
    );
    _subscriptions.add(
      _player.stream.volume.listen((volume) {
        if (mounted) setState(() => _volume = volume);
      }),
    );
    if (widget.adoptedPlayer == null) {
      _open();
    }
    _armHide();
  }

  Future<void> _open() async {
    _prefsApplied = false;
    _dataNoted = false;
    try {
      final url = await _playableUrl();
      if (url == null || url.isEmpty) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      await _play(url);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _play(String url) async {
    await _applyDataSave();
    await _player.open(Media(url, httpHeaders: const {'User-Agent': 'MiaStream'}));
  }

  Future<void> _applyDataSave() async {
    if (!mounted) {
      return;
    }
    final platform = _player.platform;
    if (platform == null) {
      return;
    }
    try {
      await (platform as dynamic).setProperty('hls-bitrate', hlsBitrateFor(LookScope.of(context).dataSave));
    } catch (_) {}
  }

  void _noteDataSize(int? height) {
    if (_dataNoted || !mounted) {
      return;
    }
    final pixels = height ?? 0;
    if (pixels <= 0) {
      return;
    }
    final cap = dataSaveWarnAbove(LookScope.of(context).dataSave);
    if (cap == null || pixels <= cap) {
      return;
    }
    _dataNoted = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu kayıt tek boy. Kaynak küçük görüntü sunmuyor, indirme aynı kalır.')),
    );
  }

  Future<String?> _playableUrl() async {
    final cue = _cue;
    if (cue.playCmd != null && widget.library != null) {
      final source = widget.library!.sourceById(cue.sourceId ?? '');
      if (source != null) {
        try {
          return await resolveStalkerLink(source, cue.playCmd!, kind: cue.linkKind);
        } catch (_) {
          return null;
        }
      }
    }
    return cue.url;
  }

  Future<void> _toggleFull() async {
    final on = await OutsideWindow.full();
    if (!mounted) {
      return;
    }
    setState(() => _full = on);
    if (on) {
      _nudgeCursor();
    } else {
      _cursorTimer?.cancel();
      setState(() => _cursorGone = false);
      OutsideWindow.cursor(false);
    }
  }

  void _nudgeCursor() {
    _cursorTimer?.cancel();
    if (_cursorGone) {
      setState(() => _cursorGone = false);
      OutsideWindow.cursor(false);
    }
    if (!_full) {
      return;
    }
    _cursorTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_full) {
        return;
      }
      setState(() => _cursorGone = true);
      OutsideWindow.cursor(true);
    });
  }

  @override
  void dispose() {
    if (_full) {
      OutsideWindow.full();
    }
    OutsideWindow.bars(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    widget.link?.removeListener(_onRemote);
    _hideTimer?.cancel();
    _cursorTimer?.cancel();
    OutsideWindow.cursor(false);
    OutsideWindow.watchLeave(null);
    watchWebFull(null);
    _stageTimer?.cancel();
    _sleep?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (!_parked) {
      _player.dispose();
    }
    _positionNote.dispose();
    _keysNode.dispose();
    _playNode.dispose();
    super.dispose();
  }

  void _armHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: MiaDevice.isTv ? 5 : 4), () {
      if (mounted && _playing) _hideControls();
    });
  }

  /// Kontroller kalkınca odak oynatıcıda kalır; yoksa kumanda tuşları boşa gider.
  void _hideControls() {
    setState(() => _controls = false);
    _keysNode.requestFocus();
  }

  void _reveal({bool focusPlay = false}) {
    setState(() => _controls = true);
    if (_playing) {
      _armHide();
    }
    if (focusPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playNode.context != null) {
          _playNode.requestFocus();
        }
      });
    }
  }

  static final _okKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  static final _arrowKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  };

  /// Kumanda: kontroller kapalıyken OK oynat/duraklat, sol/sağ sar,
  /// canlıda yukarı/aşağı kanal. Kontroller açıkken odak düğmeler arasında gezer.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (!repeat) {
      if (key == LogicalKeyboardKey.mediaPlayPause) {
        _player.playOrPause();
        _reveal();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaPlay) {
        _player.play();
        _reveal();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaPause) {
        _player.pause();
        _reveal();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaStop) {
        Navigator.maybePop(context);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.channelUp || key == LogicalKeyboardKey.mediaTrackNext) {
        _step(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.channelDown || key == LogicalKeyboardKey.mediaTrackPrevious) {
        _step(-1);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.mediaFastForward || key == LogicalKeyboardKey.mediaRewind) {
      if (!widget.live) {
        _nudge(key == LogicalKeyboardKey.mediaFastForward ? 30 : -30);
      }
      return KeyEventResult.handled;
    }
    if (_locked) {
      return KeyEventResult.ignored;
    }
    final ok = _okKeys.contains(key);
    if (!ok && !_arrowKeys.contains(key)) {
      return KeyEventResult.ignored;
    }
    if (_perde) {
      if (ok) {
        setState(() {
          _perde = false;
          _salon = true;
          _controls = true;
        });
      }
      return KeyEventResult.handled;
    }
    final loose = !_controls || FocusManager.instance.primaryFocus == _keysNode;
    if (!loose) {
      if (_playing) {
        _armHide();
      }
      return KeyEventResult.ignored;
    }
    if (ok) {
      if (!repeat) {
        _player.playOrPause();
        _reveal(focusPlay: true);
      }
      return KeyEventResult.handled;
    }
    if (widget.live) {
      if (repeat) {
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _step(1);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _step(-1);
      } else {
        _reveal(focusPlay: true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _nudge(-10);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _nudge(10);
    } else {
      _reveal(focusPlay: true);
    }
    return KeyEventResult.handled;
  }

  void _sleepFor(int? minutes) {
    _sleep?.cancel();
    if (minutes == null) {
      setState(() => _sleepMinutes = null);
      return;
    }
    setState(() => _sleepMinutes = minutes);
    _sleep = Timer(Duration(minutes: minutes), () {
      if (!mounted) {
        return;
      }
      _player.pause();
      setState(() => _sleepMinutes = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uyku zamanı doldu. Yayın durdu.')));
    });
  }

  Future<void> _sleepSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xF0141418),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Uyku zamanı')),
              ListTile(title: const Text('Kapalı'), onTap: () => Navigator.pop(context, 0)),
              ListTile(title: const Text('30 dakika'), onTap: () => Navigator.pop(context, 30)),
              ListTile(title: const Text('60 dakika'), onTap: () => Navigator.pop(context, 60)),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) {
      return;
    }
    _sleepFor(picked == 0 ? null : picked);
  }

  void _cycleStage() {
    _stageTimer?.cancel();
    setState(() {
      _stage = _stage.next;
      _stageHint = _stage.label;
    });
    _stageTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _stageHint = null);
    });
    _reveal();
  }

  void _toggleControls() {
    if (_locked) {
      return;
    }
    if (_controls && _playing) {
      _hideControls();
      _hideTimer?.cancel();
      return;
    }
    _reveal();
  }

  Future<void> _step(int delta) async {
    final next = _index + delta;
    if (next < 0 || next >= widget.cues.length) {
      return;
    }
    setState(() {
      _index = next;
      _failed = false;
      _restored = false;
      _prefsApplied = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _tracks = const Tracks();
    });
    await _open();
    _reveal();
  }

  Future<void> _setVolume(double value) async {
    final next = value.clamp(0, 100).toDouble();
    setState(() {
      _volume = next;
      _muted = next == 0;
    });
    await _player.setVolume(next);
    _reveal();
  }

  Future<void> _toggleMute() async {
    if (_muted || _volume == 0) {
      await _setVolume(_volume == 0 ? 80 : _volume);
      return;
    }
    setState(() => _muted = true);
    await _player.setVolume(0);
    _reveal();
  }

  var _outside = false;

  Future<void> _pip() async {
    if (_outside) {
      await OutsideWindow.exit();
      _outside = false;
      await _player.play();
      return;
    }
    final url = await _playableUrl();
    if (url == null || url.isEmpty) {
      return;
    }
    final mode = await OutsideWindow.enter(url);
    if (!mounted) {
      return;
    }
    if (mode == 'panel' || mode == 'pip') {
      _outside = true;
      await _player.pause();
      return;
    }
    if (mode == 'activity') {
      return;
    }
    final bus = widget.bus;
    if (bus == null) {
      return;
    }
    bus.park(
      player: _player,
      video: _controller,
      cues: widget.cues,
      index: _index,
      live: widget.live,
      library: widget.library,
    );
    _parked = true;
    Navigator.pop(context);
  }

  Future<void> _replay() async {
    final hours = _cue.archiveHours ?? 0;
    final stream = _cue.streamId;
    final sourceId = _cue.sourceId;
    final library = widget.library;
    if (hours <= 0 || stream == null || sourceId == null || library == null) {
      return;
    }
    final source = library.sourceById(sourceId);
    if (source == null || source.kind != UserSourceKind.xtream) {
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.mia.surface,
      builder: (context) {
        final options = [30, 60, 120].where((minutes) => minutes <= hours * 60).toList();
        final shown = options.isEmpty ? [30] : options;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('Geri al')),
              for (final minutes in shown)
                ListTile(title: Text('$minutes dakika önce'), onTap: () => Navigator.pop(context, minutes)),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    final url = xtreamTimeshiftUrl(
      xtreamBase(source.value),
      source.username,
      source.password,
      stream,
      DateTime.now().subtract(Duration(minutes: picked)),
      picked,
    );
    try {
      _dataNoted = false;
      await _play(url);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toggleFavorite() {
    final id = _cue.id;
    if (id == null) {
      return;
    }
    final keeps = widget.keeps;
    if (keeps != null) {
      keeps.toggleFavorite(id);
    } else {
      widget.library?.toggleFavorite(id);
    }
    setState(() {});
    _reveal();
  }

  bool _marked() {
    final id = _cue.id;
    if (id == null) {
      return false;
    }
    final keeps = widget.keeps;
    if (keeps != null) {
      return keeps.isFavorite(id);
    }
    return widget.library?.isFavorite(id) ?? false;
  }

  Future<void> _restoreOnce() async {
    if (_restored || widget.live) {
      return;
    }
    final id = _cue.spotId;
    final keeps = widget.keeps;
    if (id == null || keeps == null) {
      return;
    }
    _restored = true;
    final resume = keeps.spotOf(id)?.ms ?? 0;
    final intro = keeps.introOf(id) ?? 0;
    if (resume > 8000) {
      await _player.seek(Duration(milliseconds: resume));
      return;
    }
    if (intro > 3000) {
      await _player.seek(Duration(milliseconds: intro));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Jenerik atlandı'),
          action: SnackBarAction(label: 'Geri al', onPressed: () => _player.seek(Duration.zero)),
        ),
      );
    }
  }

  Future<void> _remember() async {
    if (widget.live) {
      return;
    }
    final id = _cue.spotId;
    final keeps = widget.keeps;
    if (id == null || keeps == null || _position.inSeconds < 5) {
      return;
    }
    final done = creditFinished(_position.inMilliseconds, _duration.inMilliseconds);
    final label = _cue.detail ?? _cue.title;
    keeps.keepSpot(id, title: label, ms: _position.inMilliseconds, done: done);
    final seriesId = _cue.id;
    if (done && !_hasNext && seriesId != null && seriesId != id) {
      keeps.keepSpot(seriesId, title: _cue.headline, ms: _position.inMilliseconds, done: true);
    }
    try {
      final bytes = await _player.screenshot();
      if (bytes != null && bytes.isNotEmpty) {
        await keeps.keepFrame(id, title: _cue.headline, bytes: bytes);
      }
    } catch (_) {}
  }

  void _markIntro() {
    final id = _cue.spotId;
    final keeps = widget.keeps;
    if (id == null || keeps == null || widget.live) {
      return;
    }
    keeps.keepIntro(id, _position.inMilliseconds);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Jenerik kaydedildi. Sonraki açılışta atlanır.')));
  }

  void _broadcast({bool force = false}) {
    final link = widget.link;
    if (link == null || link.role != LoungeRole.host || _echo) {
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_announced).inMilliseconds < 2000) {
      return;
    }
    _announced = now;
    link.announce(LoungeSignal(playing: _playing, ms: _position.inMilliseconds, url: _cue.url, title: _cue.headline));
  }

  void _onRemote() {
    final link = widget.link;
    final signal = link?.incoming;
    if (link == null || link.role != LoungeRole.guest || signal == null || !mounted) {
      return;
    }
    final url = signal.url;
    if (url != null && url.isNotEmpty && url != _cue.url) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => PlayerPage(
            library: widget.library,
            bus: widget.bus,
            keeps: widget.keeps,
            link: link,
            cues: [PlaybackCue(title: signal.title ?? 'Birlikte', url: url)],
          ),
        ),
      );
      return;
    }
    _echo = true;
    if (signal.playing) {
      _player.play();
    } else {
      _player.pause();
    }
    _player.seek(Duration(milliseconds: signal.ms));
    _echo = false;
  }

  Future<void> _stageTools() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0141418),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.weekend_outlined, color: Colors.white),
                title: const Text('Salon'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _salon = true;
                    _perde = false;
                    _controls = true;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined, color: Colors.white),
                title: const Text('Perdeyi kapat'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _perde = true;
                    _salon = true;
                    _controls = false;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.fast_forward, color: Colors.white),
                title: const Text('Jenerik burası'),
                onTap: () {
                  Navigator.pop(context);
                  _markIntro();
                },
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined, color: Colors.white),
                title: const Text('Söyle'),
                subtitle: const Text('sesi kıs, sonraki, perde'),
                onTap: () {
                  Navigator.pop(context);
                  _ask();
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.white),
                title: const Text('Birlikte izle'),
                onTap: () {
                  Navigator.pop(context);
                  _together();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_search, color: Colors.white),
                title: const Text('Bu kim'),
                onTap: () {
                  Navigator.pop(context);
                  _who();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _who() {
    MediaEntry? entry;
    final id = _cue.id;
    final library = widget.library;
    if (id != null && library != null) {
      for (final item in library.entries) {
        if (item.id == id) {
          entry = item;
        }
      }
    }
    final answer = whoAnswers('bu kim', cast: entry?.cast, director: entry?.director) ?? 'Bu kayıtta oyuncu yazmıyor.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(answer)));
  }

  Widget _salonRemote() {
    return Column(
      children: [
        const Spacer(),
        Text('Salon', style: MiaType.outfit(28, 650, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Görüntü perdede. Kumanda burada.', style: MiaType.manrope(13, 500, color: Colors.white70)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: widget.live ? (_hasPrev ? () => _step(-1) : null) : () => _nudge(-10),
              icon: Icon(widget.live ? Icons.skip_previous : Icons.replay_10, color: Colors.white),
            ),
            IconButton(
              iconSize: 56,
              onPressed: () => _player.playOrPause(),
              icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, color: Colors.white),
            ),
            IconButton(
              onPressed: widget.live ? (_hasNext ? () => _step(1) : null) : () => _nudge(10),
              icon: Icon(widget.live ? Icons.skip_next : Icons.forward_10, color: Colors.white),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _edgeSlider(
              icon: _brightness < 0.7 ? Icons.wb_sunny_outlined : Icons.wb_sunny,
              value: ((_brightness - 0.35) / 1.25).clamp(0, 1).toDouble(),
              onChanged: (value) {
                setState(() => _brightness = 0.35 + value * 1.25);
                _reveal();
              },
              onIcon: () {
                setState(() => _brightness = _brightness < 0.7 ? 1 : 0.4);
                _reveal();
              },
            ),
            _edgeSlider(
              icon: _muted || _volume == 0 ? Icons.volume_off : Icons.volume_up,
              value: (_muted ? 0.0 : _volume / 100).clamp(0.0, 1.0).toDouble(),
              onChanged: (value) => _setVolume(value * 100),
              onIcon: _toggleMute,
            ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() {
            _perde = true;
            _controls = false;
          }),
          child: const Text('Perdeyi kapat'),
        ),
        TextButton(onPressed: () => setState(() => _salon = false), child: const Text('Kumandayı kapat')),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _shiftSubtitle(double seconds) async {
    setState(() => _subDelay = seconds);
    final platform = _player.platform;
    if (platform == null) {
      return;
    }
    try {
      await (platform as dynamic).setProperty('sub-delay', seconds.toString());
    } catch (_) {}
  }

  Future<void> _runCommand(String raw) async {
    final command = parseCommand(raw);
    if (command == null) {
      final answer = whoAnswers(raw);
      if (answer != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(answer)));
      }
      return;
    }
    switch (command) {
      case PlayCommand.quieter:
        await _setVolume(_volume - 10);
      case PlayCommand.louder:
        await _setVolume(_volume + 10);
      case PlayCommand.mute:
        await _toggleMute();
      case PlayCommand.next:
        if (widget.live) {
          await _step(1);
        } else {
          await _nudge(10);
        }
      case PlayCommand.previous:
        if (widget.live) {
          await _step(-1);
        } else {
          await _nudge(-10);
        }
      case PlayCommand.pause:
        await _player.pause();
      case PlayCommand.play:
        await _player.play();
      case PlayCommand.curtain:
        setState(() {
          _perde = true;
          _salon = true;
          _controls = false;
        });
      case PlayCommand.salon:
        setState(() {
          _salon = true;
          _perde = false;
          _controls = true;
        });
      case PlayCommand.intro:
        _markIntro();
    }
  }

  Future<void> _ask() async {
    final field = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Söyle'),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'sesi kıs, sonraki, perde, bu kim'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('Uygula')),
          ],
        );
      },
    );
    field.dispose();
    if (text == null || text.trim().isEmpty) {
      return;
    }
    final answer = whoAnswers(text);
    if (answer != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(answer)));
      return;
    }
    await _runCommand(text);
  }

  Future<void> _together() async {
    final link = widget.link;
    if (link == null) {
      return;
    }
    final hostField = TextEditingController();
    final codeField = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Birlikte izle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aynı ev ağı. Bu ekran perdeyi tutar, diğeri ona kilitlenir.'),
              const SizedBox(height: 12),
              TextField(
                controller: hostField,
                decoration: const InputDecoration(hintText: 'Karşı adres'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codeField,
                decoration: const InputDecoration(hintText: 'Oda kodu'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                final error = await link.host();
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                messenger.showSnackBar(SnackBar(content: Text('${link.address}  ·  ${link.code}')));
                _broadcast(force: true);
              },
              child: const Text('Perdeyi aç'),
            ),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                final error = await link.join(hostField.text, codeField.text);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                if (error != null) {
                  messenger.showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text('Katıl'),
            ),
          ],
        );
      },
    );
    hostField.dispose();
    codeField.dispose();
  }

  Future<void> _nudge(int seconds) async {
    var next = _position + Duration(seconds: seconds);
    if (next < Duration.zero) {
      next = Duration.zero;
    }
    if (_duration > Duration.zero && next > _duration) {
      next = _duration;
    }
    await _player.seek(next);
    _reveal();
  }

  bool get _quietSubtitle {
    final look = LookScope.of(context);
    if (!look.skipSubtitleWhenAudioMatches) {
      return false;
    }
    final audio = _selected.audio;
    return matchesPreference(audio.language, audio.title, look.audioPrimary);
  }

  void _applyPrefs() {
    if (_prefsApplied || !mounted) {
      return;
    }
    if (_audioChoices.isEmpty && _subtitleChoices.isEmpty) {
      return;
    }
    final look = LookScope.of(context);
    final audio = pickPreferred(
      _audioChoices,
      look.audioPrimary,
      look.audioSecondary,
      (track) => track.language,
      (track) => track.title,
    );
    _prefsApplied = true;
    if (audio != null) {
      _player.setAudioTrack(audio);
    }
    final spoken = audio ?? (_audioChoices.isEmpty ? null : _audioChoices.first);
    final sameVoice = spoken != null && matchesPreference(spoken.language, spoken.title, look.audioPrimary);
    if ((look.skipSubtitleWhenAudioMatches && sameVoice) || look.subtitlePrimary == 'Kapalı') {
      _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    final subtitle = pickPreferred(
      _subtitleChoices,
      look.subtitlePrimary,
      look.subtitleSecondary,
      (track) => track.language,
      (track) => track.title,
    );
    _player.setSubtitleTrack(subtitle ?? SubtitleTrack.no());
  }

  List<AudioTrack> get _audioChoices {
    return turkishFirst(
      _tracks.audio.where((track) => track.id != 'auto' && track.id != 'no'),
      (track) => prefersTurkish(track.language, track.title),
    );
  }

  String _audioName(AudioTrack track, int index) {
    if (prefersTurkish(track.language, track.title)) {
      final count = _audioChoices.take(index + 1).where((item) => prefersTurkish(item.language, item.title)).length;
      return count <= 1 ? 'Türkçe' : 'Türkçe $count';
    }
    final title = track.title?.trim();
    if (title != null && title.isNotEmpty && title.toLowerCase() != 'unknown') {
      return title;
    }
    final language = track.language?.trim();
    if (language != null && language.isNotEmpty && language.toLowerCase() != 'und') {
      return language.toUpperCase();
    }
    return 'Ses ${index + 1}';
  }

  String _videoName(VideoTrack track, int index) {
    if (track.id == 'auto') {
      return 'Otomatik';
    }
    if (track.id == 'no') {
      return 'Kapalı';
    }
    final height = track.h;
    if (height != null && height > 0) {
      return '${height}p';
    }
    final codec = track.codec?.trim();
    if (codec != null && codec.isNotEmpty) {
      return codec;
    }
    return 'Görüntü ${index + 1}';
  }

  Future<void> _panel(List<Widget> Function(BuildContext sheet) body) async {
    _hideTimer?.cancel();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0141418),
      builder: (sheet) {
        return SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 12, 8, 20), children: body(sheet)),
        );
      },
    );
    if (_playing) {
      _armHide();
    }
  }

  Future<void> _subtitleSheet() {
    return _panel((sheet) {
      final tracks = _subtitleChoices;
      return [
        const _SheetTitle('Altyazı'),
        if (_quietSubtitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ses ${LookScope.of(context).audioPrimary}. Altyazı önerilmiyor.',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ListTile(
          title: const Text('Kapalı'),
          trailing: _selected.subtitle.id == 'no' ? const Icon(Icons.check, color: Colors.white) : null,
          onTap: () {
            _player.setSubtitleTrack(SubtitleTrack.no());
            Navigator.pop(sheet);
          },
        ),
        if (tracks.isEmpty)
          const _SheetEmpty('Bu yayında altyazı yok')
        else
          for (var i = 0; i < tracks.length; i++)
            ListTile(
              title: Text(_subtitleName(tracks[i], i)),
              trailing: tracks[i].id == _selected.subtitle.id ? const Icon(Icons.check, color: Colors.white) : null,
              onTap: () {
                _player.setSubtitleTrack(tracks[i]);
                Navigator.pop(sheet);
              },
            ),
        ListTile(
          title: const Text('Altyazı kaydır'),
          subtitle: Text('${_subDelay.toStringAsFixed(1)} sn'),
          onTap: () async {
            var next = _subDelay;
            await showDialog<void>(
              context: sheet,
              builder: (dialog) {
                return AlertDialog(
                  title: const Text('Altyazı kaydır'),
                  content: StatefulBuilder(
                    builder: (context, setLocal) {
                      return Slider(min: -5, max: 5, value: next, onChanged: (value) => setLocal(() => next = value));
                    },
                  ),
                  actions: [FilledButton(onPressed: () => Navigator.pop(dialog), child: const Text('Uygula'))],
                );
              },
            );
            await _shiftSubtitle(next);
            if (sheet.mounted) {
              Navigator.pop(sheet);
            }
          },
        ),
      ];
    });
  }

  Future<void> _audioSheet() {
    final audio = _audioChoices;
    return _panel((sheet) {
      return [
        const _SheetTitle('Ses'),
        if (audio.isEmpty)
          const _SheetEmpty('Bu yayında ses seçeneği yok')
        else
          for (var i = 0; i < audio.length; i++)
            ListTile(
              title: Text(_audioName(audio[i], i)),
              trailing: audio[i].id == _selected.audio.id ? const Icon(Icons.check, color: Colors.white) : null,
              onTap: () {
                _player.setAudioTrack(audio[i]);
                Navigator.pop(sheet);
              },
            ),
      ];
    });
  }

  Future<void> _settings() {
    final video = _tracks.video.where((track) => track.id != 'no').toList();
    return _panel((sheet) {
      return [
        ListTile(
          leading: const Icon(Icons.bedtime_outlined, color: Colors.white),
          title: Text(_sleepMinutes == null ? 'Uyku zamanı' : 'Uyku $_sleepMinutes dk'),
          onTap: () async {
            Navigator.pop(sheet);
            await _sleepSheet();
          },
        ),
        ListTile(
          leading: const Icon(Icons.cast, color: Colors.white),
          title: const Text('Ekrana yansıt'),
          onTap: () async {
            Navigator.pop(sheet);
            final url = await _playableUrl();
            if (!mounted) {
              return;
            }
            showCastSheet(context, url: url, live: widget.live);
          },
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome, color: Colors.white),
          title: const Text('Perde'),
          onTap: () {
            Navigator.pop(sheet);
            _stageTools();
          },
        ),
        const _SheetTitle('Veri'),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Kaynak birkaç boy sunuyorsa küçük olan seçilir. Tek dosyaysa indirme aynı kalır.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        for (final choice in dataSaveChoices)
          ListTile(
            title: Text(choice),
            trailing: LookScope.of(sheet).dataSave == choice ? const Icon(Icons.check, color: Colors.white) : null,
            onTap: () async {
              LookScope.of(sheet).setDataSave(choice);
              Navigator.pop(sheet);
              final pos = _position;
              await _open();
              if (!widget.live && pos.inSeconds > 2) {
                await _player.seek(pos);
              }
            },
          ),
        const _SheetTitle('Görüntü'),
        if (video.isEmpty)
          const _SheetEmpty('Görüntü seçeneği yok')
        else
          for (var i = 0; i < video.length; i++)
            ListTile(
              title: Text(_videoName(video[i], i)),
              trailing: video[i].id == _selected.video.id ? const Icon(Icons.check, color: Colors.white) : null,
              onTap: () {
                _player.setVideoTrack(video[i]);
                Navigator.pop(sheet);
              },
            ),
      ];
    });
  }

  String _subtitleName(SubtitleTrack track, int index) {
    if (prefersTurkish(track.language, track.title)) {
      return 'Türkçe';
    }
    final title = track.title?.trim();
    if (title != null && title.isNotEmpty && title.toLowerCase() != 'unknown') {
      return title;
    }
    final language = track.language?.trim();
    if (language != null && language.isNotEmpty && language.toLowerCase() != 'und') {
      return language.toUpperCase();
    }
    return 'Altyazı ${index + 1}';
  }

  List<SubtitleTrack> get _subtitleChoices {
    return turkishFirst(
      _tracks.subtitle.where((track) => track.id != 'auto' && track.id != 'no'),
      (track) => prefersTurkish(track.language, track.title),
    );
  }

  List<String> get _facts {
    final video = _videoTrack;
    final audio = _audioTrack;
    final facts = <String>[];
    final fps = video?.fps;
    if (fps != null && fps > 1) {
      facts.add('${fps.round()} fps');
    }
    final height = _videoParams.h ?? video?.h;
    if (height != null && height > 0) {
      facts.add('${height}p');
    }
    final videoCodec = video?.codec?.trim();
    if (videoCodec != null && videoCodec.isNotEmpty) {
      facts.add(videoCodec);
    }
    final channels = _audioParams.channelCount ?? audio?.audiochannels;
    if (channels != null && channels > 0) {
      facts.add(channels == 1 ? '1.0' : '$channels.0');
    }
    final audioCodec = audio?.codec?.trim();
    if (audioCodec != null && audioCodec.isNotEmpty) {
      facts.add(audioCodec);
    }
    return facts;
  }

  VideoTrack? get _videoTrack {
    for (final track in _tracks.video) {
      if (track.id == _selected.video.id && track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    for (final track in _tracks.video) {
      if (track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    return null;
  }

  AudioTrack? get _audioTrack {
    for (final track in _tracks.audio) {
      if (track.id == _selected.audio.id && track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    for (final track in _tracks.audio) {
      if (track.id != 'auto' && track.id != 'no') {
        return track;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final favorite = _marked();
    final line = widget.live ? 'Bilgi mevcut değil' : (_cue.detail ?? _cue.title);
    if (!_controls && !_keysNode.hasFocus && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_controls) _keysNode.requestFocus();
      });
    }
    return Focus(
      focusNode: _keysNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: _cursorGone ? SystemMouseCursors.none : MouseCursor.defer,
        onHover: (_) => _nudgeCursor(),
        onEnter: (_) => _nudgeCursor(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () {
              if (_perde) {
                setState(() {
                  _perde = false;
                  _salon = true;
                  _controls = true;
                });
                return;
              }
              _toggleControls();
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _bright(_stageView()),
                if (_stageHint != null)
                  IgnorePointer(
                    child: Align(
                      alignment: const Alignment(0, -0.22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Text(_stageHint!, style: MiaType.manrope(14, 700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                if (_controls && !_locked)
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xF2000000)],
                          stops: [0, 0.25, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                if (_buffering && !_failed)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(strokeWidth: 3.5, color: Color(0xFFE50914)),
                      ),
                    ),
                  ),
                if (!widget.live && _hasNext && !_locked)
                  ValueListenableBuilder<Duration>(
                    valueListenable: _positionNote,
                    builder: (context, position, _) {
                      final left = _duration - position;
                      if (_duration.inSeconds < 120 || left.inSeconds > 30 || left.isNegative) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        right: 32,
                        bottom: _controls ? 170 : 48,
                        child: _NextUp(
                          title: widget.cues[_index + 1].headline,
                          seconds: left.inSeconds,
                          onPlay: () => _step(1),
                        ),
                      );
                    },
                  ),
                if (!_perde && (_controls || _locked))
                  SafeArea(
                    child: _locked
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Kilidi aç',
                              onPressed: () => setState(() => _locked = false),
                              icon: const Icon(Icons.lock_open, color: Colors.white),
                            ),
                          )
                        : _salon
                        ? _salonRemote()
                        : _overlay(favorite, line),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bright(Widget child) {
    if (_brightness < 0.98) {
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: ColoredBox(color: Colors.black.withValues(alpha: (1 - _brightness).clamp(0, 0.85))),
          ),
        ],
      );
    }
    if (_brightness > 1.02) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(<double>[
          _brightness,
          0,
          0,
          0,
          0,
          0,
          _brightness,
          0,
          0,
          0,
          0,
          0,
          _brightness,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }
    return child;
  }

  Widget _overlay(bool favorite, String line) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final tv = MiaDevice.isTv;
    return Stack(
      children: [
        Column(
          children: [
            _topBar(favorite, wide),
            Expanded(child: Center(child: _centerControls(wide))),
            if (_failed)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xCCE50914), borderRadius: BorderRadius.circular(6)),
                child: Text('Yayın açılamadı', style: MiaType.manrope(14, 700, color: Colors.white)),
              ),
            if (!wide) _bottomTitle(line),
            if (widget.live)
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 0, wide ? 28 : 16, 6),
                child: Row(
                  children: [
                    const _LiveMark(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _seekBar(),
            if (wide) _wideRow(line) else _toolRow(),
            SizedBox(height: wide ? 14 : 6),
          ],
        ),
        if (!tv && !wide)
          Align(
            alignment: Alignment.centerLeft,
            child: _edgeSlider(
              icon: _brightness < 0.7 ? Icons.wb_sunny_outlined : Icons.wb_sunny,
              value: ((_brightness - 0.35) / 1.25).clamp(0, 1).toDouble(),
              onChanged: (value) {
                setState(() => _brightness = 0.35 + value * 1.25);
                _reveal();
              },
              onIcon: () {
                setState(() => _brightness = _brightness < 0.7 ? 1 : 0.4);
                _reveal();
              },
            ),
          ),
        if (!tv && !wide)
          Align(
            alignment: Alignment.centerRight,
            child: _edgeSlider(
              icon: _muted || _volume == 0 ? Icons.volume_off : Icons.volume_up,
              value: (_muted ? 0.0 : _volume / 100).clamp(0.0, 1.0).toDouble(),
              onChanged: (value) => _setVolume(value * 100),
              onIcon: _toggleMute,
            ),
          ),
      ],
    );
  }

  Widget _centerControls(bool wide) {
    final side = wide ? 64.0 : 54.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GlassButton(
          size: side,
          tooltip: widget.live ? 'Önceki kanal' : '10 saniye geri',
          icon: widget.live ? Icons.skip_previous_rounded : Icons.replay_10_rounded,
          onPressed: widget.live ? (_hasPrev ? () => _step(-1) : null) : () => _nudge(-10),
        ),
        SizedBox(width: wide ? 44 : 28),
        _GlassButton(
          size: wide ? 92 : 76,
          focusNode: _playNode,
          tooltip: _playing ? 'Duraklat' : 'Oynat',
          icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          strong: true,
          onPressed: () => _player.playOrPause(),
        ),
        SizedBox(width: wide ? 44 : 28),
        _GlassButton(
          size: side,
          tooltip: widget.live ? 'Sonraki kanal' : '10 saniye ileri',
          icon: widget.live ? Icons.skip_next_rounded : Icons.forward_10_rounded,
          onPressed: widget.live ? (_hasNext ? () => _step(1) : null) : () => _nudge(10),
        ),
      ],
    );
  }

  Widget _topBar(bool favorite, bool wide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 20 : 8, 8, wide ? 20 : 8, 0),
      child: Row(
        children: [
          _GlassButton(
            size: 44,
            tooltip: 'Geri',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          if (wide)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _cue.seriesTitle ?? _cue.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MiaType.outfit(20, 750, color: Colors.white),
                  ),
                  if (_facts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, children: [for (final fact in _facts) _Fact(fact)]),
                    ),
                ],
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final fact in _facts) ...[_Fact(fact), const SizedBox(width: 6)],
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (!wide)
            _barIcon(tooltip: 'Kilitle', onPressed: () => setState(() => _locked = true), icon: Icons.lock_outline),
          _barIcon(tooltip: 'Küçük pencere', onPressed: _pip, icon: Icons.picture_in_picture_alt_rounded),
          _barIcon(
            tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
            onPressed: _cue.id == null ? null : _toggleFavorite,
            icon: favorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: favorite ? const Color(0xFFFFC53D) : Colors.white,
          ),
          _barIcon(tooltip: 'Ayarlar', onPressed: _settings, icon: Icons.settings_rounded),
        ],
      ),
    );
  }

  Widget _wideRow(String line) {
    final tv = MiaDevice.isTv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Row(
        children: [
          _barIcon(
            tooltip: _playing ? 'Duraklat' : 'Oynat',
            onPressed: () => _player.playOrPause(),
            icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 32,
          ),
          if (!widget.live) ...[
            _barIcon(tooltip: '10 saniye geri', onPressed: () => _nudge(-10), icon: Icons.replay_10_rounded, size: 28),
            _barIcon(tooltip: '10 saniye ileri', onPressed: () => _nudge(10), icon: Icons.forward_10_rounded, size: 28),
          ],
          _barIcon(
            tooltip: _muted ? 'Sesi aç' : 'Sesi kapat',
            onPressed: _toggleMute,
            icon: _muted || _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            size: 28,
          ),
          if (!tv)
            SizedBox(
              width: 110,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: (_muted ? 0.0 : _volume / 100).clamp(0.0, 1.0).toDouble(),
                  onChanged: (value) => _setVolume(value * 100),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _cue.headline,
                    style: MiaType.manrope(15, 750, color: Colors.white),
                  ),
                  if (line != _cue.headline && line.isNotEmpty)
                    TextSpan(
                      text: '   $line',
                      style: MiaType.manrope(14, 500, color: const Color(0xFFB9B9C2)),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          if (!widget.live && _hasNext)
            _barIcon(tooltip: 'Sonraki bölüm', onPressed: () => _step(1), icon: Icons.skip_next_rounded, size: 30),
          if (_subtitleChoices.isNotEmpty || _audioChoices.length > 1)
            _barIcon(
              tooltip: 'Ses ve altyazı',
              onPressed: _subtitleChoices.isNotEmpty ? _subtitleSheet : _audioSheet,
              icon: Icons.subtitles_rounded,
              size: 28,
            ),
          if (_audioChoices.length > 1 && _subtitleChoices.isNotEmpty)
            _barIcon(tooltip: 'Ses parçası', onPressed: _audioSheet, icon: Icons.graphic_eq_rounded, size: 28),
          if (!widget.live)
            _barIcon(tooltip: 'Oynatma hızı', onPressed: _rateSheet, icon: Icons.speed_rounded, size: 28),
          if ((_cue.archiveHours ?? 0) > 0 && _cue.streamId != null)
            _barIcon(tooltip: 'Geri al', onPressed: _replay, icon: Icons.history_rounded, size: 28),
          _barIcon(tooltip: _stage.label, onPressed: _cycleStage, icon: _stage.icon, size: 26),
          if (!tv)
            _barIcon(
              tooltip: _full ? 'Tam ekrandan çık' : 'Tam ekran',
              onPressed: _toggleFull,
              icon: _full ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              size: 30,
            ),
        ],
      ),
    );
  }

  Future<void> _rateSheet() async {
    const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF15151B),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetTitle('Oynatma hızı'),
            for (final rate in rates)
              ListTile(
                autofocus: rate == _rate,
                title: Text(rate == 1 ? 'Normal' : '${rate}x'),
                trailing: rate == _rate ? const Icon(Icons.check_rounded, color: Color(0xFFE50914)) : null,
                onTap: () => Navigator.pop(context, rate),
              ),
          ],
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    await _player.setRate(picked);
    if (mounted) setState(() => _rate = picked);
  }

  Widget _barIcon({
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
    Color color = Colors.white,
    double size = 24,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, color: onPressed == null ? Colors.white38 : color, size: size),
    );
  }

  Widget _edgeSlider({
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback onIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _SideSlider(icon: icon, value: value, onChanged: onChanged, onIcon: onIcon),
    );
  }

  Widget _bottomTitle(String line) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (_cue.artwork != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _cue.artwork!,
                  width: 42,
                  height: 42,
                  fit: BoxFit.contain,
                  headers: const {'User-Agent': 'MiaStream'},
                  errorBuilder: (_, _, _) => const SizedBox(width: 42, height: 42),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cue.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MiaType.manrope(16, 700, color: Colors.white),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MiaType.manrope(12, 500, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seekBar() {
    return ValueListenableBuilder<Duration>(valueListenable: _positionNote, builder: (context, _, _) => _seekRow());
  }

  Widget _seekRow() {
    final left = _duration - _position;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        children: [
          Text(_clock(_position), style: MiaType.manrope(12, 700, color: Colors.white)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFE50914),
                inactiveTrackColor: const Color(0x40FFFFFF),
                thumbColor: const Color(0xFFE50914),
                overlayColor: const Color(0x33E50914),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: _sliderValue,
                max: _sliderMax,
                onChanged: (value) {
                  _player.seek(Duration(milliseconds: value.round()));
                  _reveal();
                },
              ),
            ),
          ),
          Text(
            _duration > Duration.zero ? '-${_clock(left.isNegative ? Duration.zero : left)}' : '--:--',
            style: MiaType.manrope(12, 700, color: const Color(0xFFCFCFD6)),
          ),
        ],
      ),
    );
  }

  Widget _toolRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_subtitleChoices.isNotEmpty)
            _barIcon(tooltip: 'Altyazı', onPressed: _subtitleSheet, icon: Icons.subtitles_outlined),
          if (_audioChoices.length > 1)
            _barIcon(tooltip: 'Ses parçası', onPressed: _audioSheet, icon: Icons.music_note),
          _barIcon(
            tooltip: _muted ? 'Sesi aç' : 'Sesi kapat',
            onPressed: _toggleMute,
            icon: _muted || _volume == 0 ? Icons.volume_off : Icons.volume_up,
          ),
          if ((_cue.archiveHours ?? 0) > 0 && _cue.streamId != null)
            _barIcon(tooltip: 'Geri al', onPressed: _replay, icon: Icons.history),
        ],
      ),
    );
  }

  double get _sliderMax {
    final max = _duration.inMilliseconds.toDouble();
    return max <= 0 ? 1 : max;
  }

  double get _sliderValue {
    final value = _position.inMilliseconds.toDouble();
    if (value < 0) {
      return 0;
    }
    if (value > _sliderMax) {
      return _sliderMax;
    }
    return value;
  }

  Widget _stageView() {
    final video = Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: _stage == _Stage.fit ? BoxFit.contain : BoxFit.cover,
    );
    return switch (_stage) {
      _Stage.fit => video,
      _Stage.cinema => ColoredBox(
        color: Colors.black,
        child: Center(child: AspectRatio(aspectRatio: 2.39, child: video)),
      ),
      _Stage.zoom => ClipRect(child: Transform.scale(scale: 1.34, child: video)),
    };
  }

  String _clock(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '${duration.inMinutes}:$seconds';
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white54),
      ),
      child: Text(text, style: MiaType.manrope(12, 600, color: Colors.white)),
    );
  }
}

class _SideSlider extends StatelessWidget {
  const _SideSlider({required this.icon, required this.value, required this.onChanged, required this.onIcon});

  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Aç / kapat',
          onPressed: onIcon,
          iconSize: 34,
          icon: Icon(icon, color: Colors.white, size: 34),
        ),
        SizedBox(
          height: 168,
          width: 48,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveMark extends StatelessWidget {
  const _LiveMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(4)),
      child: Text('CANLI', style: MiaType.outfit(13, 700, letterSpacing: 1.4, color: Colors.white)),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text, style: MiaType.outfit(16, 650, color: Colors.white)),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(text, style: const TextStyle(color: Colors.white54)),
    );
  }
}

enum _Stage {
  fit('Ekrana sığdır', Icons.fit_screen),
  cinema('Sinema', Icons.theaters),
  zoom('Yaklaştır', Icons.zoom_in);

  const _Stage(this.label, this.icon);

  final String label;
  final IconData icon;

  _Stage get next {
    return switch (this) {
      fit => cinema,
      cinema => zoom,
      zoom => fit,
    };
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.size,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.strong = false,
  });

  final double size;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: strong ? const Color(0x33FFFFFF) : const Color(0x26000000),
            shape: CircleBorder(
              side: BorderSide(color: strong ? const Color(0x80FFFFFF) : const Color(0x40FFFFFF), width: 1.5),
            ),
            child: InkWell(
              focusNode: focusNode,
              customBorder: const CircleBorder(),
              focusColor: const Color(0x80FFFFFF),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: size * 0.56, color: onPressed == null ? Colors.white30 : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.title, required this.seconds, required this.onPlay});

  final String title;
  final int seconds;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xB3141418),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SONRAKİ BÖLÜM',
                style: MiaType.manrope(11, 800, color: const Color(0xFFE50914)).copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MiaType.manrope(15, 750, color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                autofocus: true,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ).copyWith(side: MiaTheme.lightFocusRing),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Şimdi oynat · $seconds sn', style: MiaType.manrope(14, 800, color: Colors.black)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
