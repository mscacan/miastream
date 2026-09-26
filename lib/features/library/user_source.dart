enum UserSourceKind { m3u, xtream, stalker }

/// Kullanıcının eklediği kaynak.
class UserSource {
  const UserSource({
    required this.id,
    required this.label,
    required this.kind,
    required this.value,
    this.username = '',
    this.password = '',
    this.mac = '',
  });

  final String id;
  final String label;

  /// M3U adres, Xtream sunucu veya Stalker portal adresi.
  final String value;
  final UserSourceKind kind;
  final String username;
  final String password;
  final String mac;

  bool get isComplete {
    if (label.trim().isEmpty || value.trim().isEmpty) {
      return false;
    }
    return switch (kind) {
      UserSourceKind.m3u => true,
      UserSourceKind.xtream => username.trim().isNotEmpty && password.isNotEmpty,
      UserSourceKind.stalker => mac.trim().isNotEmpty,
    };
  }

  String get kindLabel {
    return switch (kind) {
      UserSourceKind.m3u => 'M3U',
      UserSourceKind.xtream => 'Xtream',
      UserSourceKind.stalker => 'Stalker',
    };
  }
}
