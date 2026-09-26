import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../library/user_library.dart';
import 'media_entry.dart';

/// Oynatıcı küçültülünce pencere kapanmadan görüntü köşede kalır.
class PlaybackBus extends ChangeNotifier {
  Player? player;
  VideoController? video;
  List<PlaybackCue> cues = const [];
  var index = 0;
  var live = false;
  UserLibrary? library;

  bool get showing => player != null && video != null;

  void park({
    required Player player,
    required VideoController video,
    required List<PlaybackCue> cues,
    required int index,
    required bool live,
    required UserLibrary? library,
  }) {
    this.player = player;
    this.video = video;
    this.cues = cues;
    this.index = index;
    this.live = live;
    this.library = library;
    notifyListeners();
  }

  PlaybackHandoff? take() {
    final current = player;
    final view = video;
    if (current == null || view == null) {
      return null;
    }
    final handoff = PlaybackHandoff(
      player: current,
      video: view,
      cues: cues,
      index: index,
      live: live,
      library: library,
    );
    player = null;
    video = null;
    notifyListeners();
    return handoff;
  }

  void close() {
    player?.dispose();
    player = null;
    video = null;
    notifyListeners();
  }
}

class PlaybackHandoff {
  const PlaybackHandoff({
    required this.player,
    required this.video,
    required this.cues,
    required this.index,
    required this.live,
    required this.library,
  });

  final Player player;
  final VideoController video;
  final List<PlaybackCue> cues;
  final int index;
  final bool live;
  final UserLibrary? library;
}
