import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'lounge_link.dart';

/// Aynı Wi-Fi içinde kaynak, favori ve izleme yeri. Dışarı hesap yok.
class DeviceSync {
  ServerSocket? _server;
  String code = '';
  String address = '';
  Map<String, dynamic>? _bag;

  Future<String?> host({
    required List<Map<String, String>> sources,
    required Map<String, dynamic> marks,
  }) async {
    await close();
    code = _pin();
    address = await localAddress();
    _bag = {'sources': sources, 'marks': marks};
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 47322);
    } catch (_) {
      return 'Bu ağda kapı dolu';
    }
    _server!.listen((socket) {
      final buffer = StringBuffer();
      socket.listen(
        (data) {
          buffer.write(utf8.decode(data));
          final text = buffer.toString();
          if (!text.contains('\n')) {
            return;
          }
          final line = text.split('\n').first.trim();
          if (line == 'JOIN $code' && _bag != null) {
            socket.write('${jsonEncode(_bag)}\n');
          }
          socket.close();
        },
        onError: (_) => socket.close(),
      );
    });
    return null;
  }

  Future<Map<String, dynamic>?> join(String host, String room) async {
    final secret = room.trim().toUpperCase();
    final trimmed = host.trim();
    if (trimmed.isEmpty || secret.length < 4) {
      return null;
    }
    try {
      final socket = await Socket.connect(trimmed, 47322, timeout: const Duration(seconds: 4));
      socket.write('JOIN $secret\n');
      final text = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      socket.destroy();
      final decoded = jsonDecode(text.trim());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close();
  }
}

String _pin() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(4, (_) => alphabet[random.nextInt(alphabet.length)]).join();
}
