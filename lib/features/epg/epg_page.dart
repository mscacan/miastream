import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../library/user_library.dart';
import '../library/user_source.dart';
import '../playback/media_entry.dart';
import '../playback/source_loader.dart';
import '../playback/xtream_api.dart';
import '../shell/shell_section.dart';
import 'guide.dart';

export '../playback/screen_share.dart' show showCastSheet;

class EpgPage extends StatefulWidget {
  const EpgPage({super.key, this.library});

  final UserLibrary? library;

  @override
  State<EpgPage> createState() => _EpgPageState();
}

class _EpgPageState extends State<EpgPage> {
  var _loading = true;
  String? _error;
  final List<_GuideRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library = widget.library;
    if (library == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Kaynak yok.';
        });
      }
      return;
    }
    final live = library.entriesFor(ShellSection.live);
    final guides = <String, List<GuideSlot>>{};
    for (final source in library.items) {
      if (source.kind != UserSourceKind.xtream) {
        continue;
      }
      try {
        final url = xtreamGuideUrl(xtreamBase(source.value), source.username, source.password);
        guides[url] = parseXmltv(await fetchText(Uri.parse(url)));
      } on SourceLoadException catch (error) {
        _error ??= error.message;
      } catch (_) {
        _error ??= 'Rehber okunamadı';
      }
    }
    for (final entry in live) {
      final url = entry.guideUrl;
      if (url == null || guides.containsKey(url)) {
        continue;
      }
      try {
        guides[url] = parseXmltv(await fetchText(Uri.parse(url)));
      } catch (_) {
        _error ??= 'Rehber okunamadı';
      }
    }
    final now = DateTime.now();
    for (final entry in live) {
      final id = entry.epgId;
      if (id == null) {
        continue;
      }
      GuideSlot? current;
      GuideSlot? next;
      for (final slots in guides.values) {
        for (final slot in slots) {
          if (slot.channelId.toLowerCase() != id.toLowerCase() || !slot.end.isAfter(now)) {
            continue;
          }
          if (!slot.start.isAfter(now)) {
            current = slot;
          } else {
            next ??= slot;
          }
        }
      }
      _rows.add(_GuideRow(entry.title, current?.title, next?.title));
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _rows.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Bu kaynakta rehber kimliği yok.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = _rows[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.channel),
                subtitle: Text(
                  [
                    if (row.now != null) 'Şimdi: ${row.now}',
                    if (row.next != null) 'Sonra: ${row.next}',
                  ].join('\n'),
                ),
              );
            },
          );
    return Scaffold(
      backgroundColor: context.mia.background,
      appBar: AppBar(title: const Text('EPG')),
      body: body,
    );
  }
}

class _GuideRow {
  const _GuideRow(this.channel, this.now, this.next);

  final String channel;
  final String? now;
  final String? next;
}
