import 'package:cast/cast.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'outside_window.dart';

Future<void> showCastSheet(BuildContext context, {String? url, bool live = false}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.mia.surface,
    isScrollControlled: true,
    builder: (context) {
      return _CastSheet(url: url, live: live);
    },
  );
}

class _CastSheet extends StatefulWidget {
  const _CastSheet({required this.url, required this.live});

  final String? url;
  final bool live;

  @override
  State<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends State<_CastSheet> {
  var _busy = false;
  String? _note;
  List<CastDevice> _devices = const [];

  bool get _hasUrl {
    final url = widget.url;
    return url != null && (url.startsWith('http://') || url.startsWith('https://'));
  }

  Future<void> _float() async {
    final url = widget.url;
    if (url == null) {
      return;
    }
    final mode = await OutsideWindow.enter(url);
    if (!mounted) {
      return;
    }
    setState(() {
      _note = mode == 'none'
          ? 'Bu sistemde yüzen pencere açılamadı.'
          : 'Küçük pencere diğer uygulamaların üstünde. AirPlay, pencerenin oynatıcısından seçilir.';
    });
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final found = await CastDiscoveryService().search();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = found;
        _busy = false;
        _note = found.isEmpty ? 'Bu ağda Chromecast görünmedi.' : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = 'Chromecast aranamadı.';
      });
    }
  }

  Future<void> _load(CastDevice device) async {
    final url = widget.url;
    if (url == null) {
      return;
    }
    setState(() => _note = '${device.name} açılıyor');
    try {
      final session = await CastSessionManager().startSession(device);
      var sent = false;
      session.stateStream.listen((state) {
        if (state == CastSessionState.connected) {
          session.sendMessage(CastSession.kNamespaceReceiver, {
            'type': 'LAUNCH',
            'requestId': 1,
            'appId': 'CC1AD845',
          });
        }
      });
      session.messageStream.listen((message) {
        if (sent) {
          return;
        }
        final type = message['type']?.toString();
        final status = message['status'];
        final apps = status is Map ? status['applications'] : null;
        if (type == 'RECEIVER_STATUS' && apps is List && apps.isNotEmpty) {
          sent = true;
          Future<void>.delayed(const Duration(seconds: 1), () {
            session.sendMessage(CastSession.kNamespaceMedia, {
              'type': 'LOAD',
              'autoPlay': true,
              'currentTime': 0,
              'media': {
                'contentId': url,
                'contentType': _contentType(url),
                'streamType': widget.live ? 'LIVE' : 'BUFFERED',
              },
            });
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _note = 'Chromecast oturumu açılmadı.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ekran paylaş', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _hasUrl
                ? 'Küçük pencere uygulamanın dışında kalır. AirPlay o pencerenin oynatıcısından, Chromecast ise aşağıdaki cihazdan gider.'
                : 'Önce bir yayın aç.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          if (_hasUrl)
            FilledButton(
              onPressed: _float,
              child: const Text('Küçük pencere'),
            ),
          if (_hasUrl) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _search,
              child: Text(_busy ? 'Aranıyor' : 'Chromecast ara'),
            ),
          ],
          for (final device in _devices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cast),
              title: Text(device.name),
              onTap: () => _load(device),
            ),
        ],
      ),
    );
  }
}

String _contentType(String url) {
  final path = url.toLowerCase();
  if (path.contains('.mp4')) {
    return 'video/mp4';
  }
  if (path.contains('.mkv')) {
    return 'video/x-matroska';
  }
  if (path.contains('.ts')) {
    return 'video/mp2t';
  }
  return 'application/x-mpegURL';
}
