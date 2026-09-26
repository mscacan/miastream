import 'package:flutter/material.dart';

import '../../core/mia_mark.dart';
import '../../core/theme.dart';
import 'user_library.dart';
import 'user_source.dart';

Future<void> addUserSource(BuildContext context, UserLibrary library) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => AddSourcePage(library: library),
    ),
  );
}

class AddSourcePage extends StatefulWidget {
  const AddSourcePage({super.key, required this.library});

  final UserLibrary library;

  @override
  State<AddSourcePage> createState() => _AddSourcePageState();
}

class _AddSourcePageState extends State<AddSourcePage> {
  UserSourceKind? _kind;

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    return Scaffold(
      backgroundColor: context.mia.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (kind != null) {
              setState(() => _kind = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(kind == null ? 'Kaynak ekle' : _title(kind)),
      ),
      body: kind == null
          ? _KindPicker(onPick: (value) => setState(() => _kind = value))
              : _SourceForm(
              kind: kind,
              library: widget.library,
              onSave: (source) async {
                final error = await widget.library.tryAdd(source);
                if (!context.mounted) {
                  return error ?? 'Kaynak yanıt vermedi';
                }
                if (error == null) {
                  Navigator.pop(context);
                }
                return error;
              },
            ),
    );
  }
}

class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.onPick});

  final ValueChanged<UserSourceKind> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          'Kendi hesabın',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Liste bizden gelmez. Bağlantı bilgin sende kalır.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        _KindCard(
          icon: Icons.playlist_play,
          title: 'M3U / M3U8 Oynatma Listesi',
          body: 'Liste adresini yapıştır.',
          onTap: () => onPick(UserSourceKind.m3u),
        ),
        _KindCard(
          icon: Icons.dns_outlined,
          title: 'Xtream Codes',
          body: 'Ad, sunucu, kullanıcı adı ve şifre.',
          onTap: () => onPick(UserSourceKind.xtream),
        ),
        _KindCard(
          icon: Icons.router_outlined,
          title: 'Stalker Portalı',
          body: 'Sağlayıcının portal adresi ve cihaz MAC adresi. Portal bizden gelmez.',
          onTap: () => onPick(UserSourceKind.stalker),
        ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: mia.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mia.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: mia.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: mia.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: MiaType.manrope(15, 700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(body, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: mia.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceForm extends StatefulWidget {
  const _SourceForm({required this.kind, required this.library, required this.onSave});

  final UserSourceKind kind;
  final UserLibrary library;
  final Future<String?> Function(UserSource source) onSave;

  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> with SingleTickerProviderStateMixin {
  final _label = TextEditingController();
  final _primary = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _mac = TextEditingController();
  String? _error;
  var _busy = false;
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void dispose() {
    _motion.dispose();
    _label.dispose();
    _primary.dispose();
    _username.dispose();
    _password.dispose();
    _mac.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) {
      return;
    }
    final source = UserSource(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: _label.text,
      kind: widget.kind,
      value: _primary.text,
      username: _username.text,
      password: _password.text,
      mac: _mac.text,
    );
    if (!source.isComplete) {
      setState(() => _error = 'Eksik alan var.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    _motion.repeat(reverse: true);
    final error = await widget.onSave(source);
    if (!mounted) {
      return;
    }
    _motion.stop();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return ListenableBuilder(
        listenable: widget.library,
        builder: (context, _) {
          final count = widget.library.loadCount;
          final label = widget.library.loadLabel;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
            child: Column(
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.08).animate(
                    CurvedAnimation(parent: _motion, curve: Curves.easeInOut),
                  ),
                  child: const MiaWord(size: 36),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 78,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (context, _) {
                        return Transform.translate(
                          offset: Offset((_motion.value * 2 - 1) * 70, 0),
                          child: OverflowBox(
                            maxWidth: 520,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Container(
                                    width: 46,
                                    height: 68,
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color.lerp(miaRed, const Color(0xFF5A1020), i / 6)!,
                                          const Color(0xFF1A1A1A),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('İçerikler yükleniyor', style: MiaType.outfit(26, 700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(label, style: MiaType.manrope(15, 600, color: const Color(0xFFB3B3B3))),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    color: miaRed,
                    backgroundColor: Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  count == 0 ? 'Sunucu sayılıyor' : '$count içerik geldi',
                  style: MiaType.manrope(18, 700, color: Colors.white),
                ),
              ],
            ),
          );
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (widget.kind == UserSourceKind.stalker) ...[
          Text(
            'Stalker, bazı sağlayıcıların kullandığı portaldır. Portal adresini ve cihazının MAC adresini yazarsın. Biz portal vermeyiz.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _label,
          decoration: const InputDecoration(labelText: 'Ad'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _primary,
          decoration: InputDecoration(labelText: _primaryLabel(widget.kind)),
        ),
        if (widget.kind == UserSourceKind.xtream) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Şifre'),
          ),
        ],
        if (widget.kind == UserSourceKind.stalker) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _mac,
            decoration: const InputDecoration(labelText: 'MAC adresi'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: MiaType.manrope(13, 600, color: context.mia.accent)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}

String _title(UserSourceKind kind) {
  return switch (kind) {
    UserSourceKind.m3u => 'M3U / M3U8',
    UserSourceKind.xtream => 'Xtream Codes',
    UserSourceKind.stalker => 'Stalker Portalı',
  };
}

String _primaryLabel(UserSourceKind kind) {
  return switch (kind) {
    UserSourceKind.m3u => 'Liste adresi',
    UserSourceKind.xtream => 'Sunucu',
    UserSourceKind.stalker => 'Portal adresi',
  };
}
