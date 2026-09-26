import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

class LoungeSignal {
  const LoungeSignal({
    required this.playing,
    required this.ms,
    this.url,
    this.title,
  });

  final bool playing;
  final int ms;
  final String? url;
  final String? title;

  Map<String, dynamic> toJson() {
    return {
      'playing': playing,
      'ms': ms,
      'url': ?url,
      'title': ?title,
    };
  }

  static LoungeSignal? parse(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return null;
      }
      return LoungeSignal(
        playing: decoded['playing'] == true,
        ms: int.tryParse('${decoded['ms']}') ?? 0,
        url: decoded['url']?.toString(),
        title: decoded['title']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

enum LoungeRole { idle, host, guest }

/// Aynı ev ağında perde. Dışarı sunucu yok. Adres kayda yazılmaz.
class LoungeLink extends ChangeNotifier {
  ServerSocket? _server;
  var _alive = true;
  final List<Socket> _guests = [];
  Socket? _upstream;
  LoungeRole role = LoungeRole.idle;
  String code = '';
  String address = '';
  LoungeSignal? incoming;

  Future<String?> host() async {
    await close();
    code = _code();
    address = await localAddress();
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 47321);
    } catch (_) {
      return 'Bu ağda kapı dolu';
    }
    role = LoungeRole.host;
    _server!.listen((socket) {
      final buffer = StringBuffer();
      var accepted = false;
      socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
          final text = buffer.toString();
          final lines = text.split('\n');
          buffer
            ..clear()
            ..write(lines.last);
          for (final raw in lines.take(lines.length - 1)) {
            final line = raw.trim();
            if (line.isEmpty) {
              continue;
            }
            if (!accepted) {
              if (line == 'JOIN $code') {
                accepted = true;
                _guests.add(socket);
                notifyListeners();
              } else {
                socket.close();
              }
              continue;
            }
          }
        },
        onDone: () => _guests.remove(socket),
        onError: (_) => _guests.remove(socket),
      );
    });
    notifyListeners();
    return null;
  }

  Future<String?> join(String host, String room) async {
    await close();
    final trimmed = host.trim();
    final secret = room.trim().toUpperCase();
    if (trimmed.isEmpty || secret.length < 4) {
      return 'Adres ve kod gerekli';
    }
    try {
      final socket = await Socket.connect(trimmed, 47321, timeout: const Duration(seconds: 4));
      _upstream = socket;
      socket.write('JOIN $secret\n');
      role = LoungeRole.guest;
      code = secret;
      address = trimmed;
      var pending = '';
      socket.listen((data) {
        pending += utf8.decode(data);
        while (pending.contains('\n')) {
          final cut = pending.indexOf('\n');
          final line = pending.substring(0, cut).trim();
          pending = pending.substring(cut + 1);
          final signal = LoungeSignal.parse(line);
          if (signal != null) {
            incoming = signal;
            notifyListeners();
          }
        }
      }, onDone: close);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Odaya bağlanılamadı';
    }
  }

  void announce(LoungeSignal signal) {
    if (role != LoungeRole.host) {
      return;
    }
    final line = '${jsonEncode(signal.toJson())}\n';
    final bytes = utf8.encode(line);
    for (final guest in [..._guests]) {
      try {
        guest.add(bytes);
      } catch (_) {
        _guests.remove(guest);
      }
    }
  }

  Future<void> close() async {
    role = LoungeRole.idle;
    incoming = null;
    final guests = [..._guests];
    _guests.clear();
    final upstream = _upstream;
    _upstream = null;
    final server = _server;
    _server = null;
    if (_alive) {
      notifyListeners();
    }
    for (final guest in guests) {
      guest.destroy();
    }
    await upstream?.close();
    await server?.close();
  }

  @override
  void dispose() {
    _alive = false;
    role = LoungeRole.idle;
    for (final guest in _guests) {
      guest.destroy();
    }
    _guests.clear();
    _upstream?.destroy();
    _upstream = null;
    _server?.close();
    _server = null;
    super.dispose();
  }
}

Future<String> localAddress() async {
  try {
    for (final interface in await NetworkInterface.list()) {
      for (final address in interface.addresses) {
        if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
          return address.address;
        }
      }
    }
  } catch (_) {}
  return '127.0.0.1';
}

String _code() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(4, (_) => alphabet[random.nextInt(alphabet.length)]).join();
}
