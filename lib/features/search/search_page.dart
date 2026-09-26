import 'package:flutter/material.dart';

import '../browse/cover_art.dart';
import '../library/user_library.dart';
import '../playback/media_entry.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.library, required this.onPlay});

  final UserLibrary library;
  final ValueChanged<MediaEntry> onPlay;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.library, _query]),
      builder: (context, _) {
        final text = _query.text.trim().toLowerCase();
        final matches = widget.library.entries.where((entry) {
          return text.isNotEmpty &&
              (entry.title.toLowerCase().contains(text) ||
                  entry.group.toLowerCase().contains(text));
        }).take(80).toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Arama', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _query,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Kendi kaynağında ara',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.library.items.isEmpty)
              Text(
                'Henüz kaynak yok. Arama, senin eklediğin listede çalışır.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (text.isEmpty)
              Text(
                'Bir ad yaz. Sonuçlar yalnızca senin kaynaklarından gelir.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else if (matches.isEmpty)
              Text('Eşleşme yok.', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final entry in matches)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: ArtworkThumb(
                    artwork: entry.artwork,
                    width: 56,
                    height: 80,
                  ),
                  title: Text(entry.title),
                  subtitle: Text(entry.group),
                  onTap: () => widget.onPlay(entry),
                ),
          ],
        );
      },
    );
  }
}
