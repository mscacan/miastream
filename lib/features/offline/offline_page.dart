import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../browse/cover_art.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';
import '../playback/playback_bus.dart';
import '../playback/player_page.dart';
import 'download_store.dart';

class OfflinePage extends StatefulWidget {
  const OfflinePage({
    super.key,
    required this.downloads,
    required this.library,
    required this.bus,
  });

  final DownloadStore downloads;
  final UserLibrary library;
  final PlaybackBus bus;

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage> {
  @override
  void initState() {
    super.initState();
    widget.downloads.ensureLoaded();
  }

  void _play(SavedCopy item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          library: widget.library,
          bus: widget.bus,
          cues: [
            PlaybackCue(
              id: item.id,
              title: item.title,
              url: item.path,
              artwork: item.artwork,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.downloads,
      builder: (context, _) {
        final saved = widget.downloads.items;
        final pending = widget.downloads.pendingTitle.entries.toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('İndirilenler', style: MiaType.outfit(28, 650, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Film ve dizi sayfasındaki İndir, kaydı bu listeye alır. Sonra buradan açılır.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (saved.isEmpty && pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Henüz indirilen yok.'),
              ),
            for (final row in pending)
              ListTile(
                leading: const Icon(Icons.downloading),
                title: Text(row.value),
                subtitle: Text('%${((widget.downloads.fraction(row.key) ?? 0) * 100).round()}'),
              ),
            for (final item in saved)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ArtworkThumb(artwork: item.artwork, width: 56, height: 80),
                title: Text(item.title),
                trailing: IconButton(
                  tooltip: 'Sil',
                  onPressed: () => widget.downloads.remove(item.id),
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () => _play(item),
              ),
          ],
        );
      },
    );
  }
}
