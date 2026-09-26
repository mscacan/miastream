import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';
import '../../core/look.dart';
import '../../core/theme.dart';
import '../browse/home_page.dart';
import '../browse/language_page.dart';
import '../playback/media_entry.dart';
import '../library/user_library.dart';
import '../library/user_source.dart';
import '../lounge/seat_store.dart';
import '../playback/data_save.dart';
import '../playback/track_labels.dart';
import '../shell/shell_section.dart';
import '../sync/device_sync.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onAdd,
    required this.library,
    required this.seat,
    required this.onPlay,
  });

  final VoidCallback onAdd;
  final UserLibrary library;
  final SeatStore seat;
  final ValueChanged<MediaEntry> onPlay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text('Ayarlar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(Brand.storeSubtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        _Group(
          children: [
            _NavRow(
              icon: Icons.translate,
              title: 'Dillere Göre Gözat',
              onTap: () => _open(
                context,
                LanguageBrowsePage(library: library, onPlay: onPlay),
              ),
            ),
            _NavRow(
              icon: Icons.tune,
              title: 'Kişiselleştirme',
              onTap: () => _open(context, const _PersonalPage()),
            ),
            _NavRow(
              icon: Icons.smart_display_outlined,
              title: 'Video oynatıcı ayarları',
              onTap: () => _open(context, const _PlayerPage()),
            ),
            _NavRow(
              icon: Icons.calendar_view_day,
              title: 'EPG',
              onTap: () => _open(context, const _EpgSettingsPage()),
            ),
            _NavRow(
              icon: Icons.palette_outlined,
              title: 'Tema',
              onTap: () => _open(context, const _ThemePage()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Group(
          children: [
            _NavRow(
              icon: Icons.devices,
              title: 'Diğer cihazlarda kullanma',
              onTap: () => _open(context, _DevicesPage(library: library, seat: seat)),
            ),
            _NavRow(
              icon: Icons.ios_share,
              title: 'Uygulamayı paylaş',
              onTap: () => _share(context),
            ),
            _NavRow(
              icon: Icons.star_outline,
              title: 'Uygulamayı değerlendir',
              onTap: () => _open(context, const _RatePage()),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: library,
          builder: (context, _) {
            final saved = library.savedLabel;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final source in library.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(source.label),
                    subtitle: Text(source.kindLabel),
                    trailing: TextButton(
                      onPressed: () => _confirmDrop(context, source),
                      child: const Text('Kaldır'),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: onAdd, child: const Text('Kaynak ekle')),
                ),
                const SizedBox(height: 8),
                Text('Liste güncelleme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Kaynak ve kapaklar telefonda kalır. Aralık dolunca liste yenilenir.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _Choice(
                  values: [for (final label in sourceRefreshLabels.values) label],
                  selected: sourceRefreshLabels[library.refreshEvery] ?? 'Haftalık',
                  onSelect: (label) {
                    final code = sourceRefreshLabels.entries
                        .where((item) => item.value == label)
                        .map((item) => item.key)
                        .firstOrNull;
                    if (code != null) {
                      library.setRefreshEvery(code);
                    }
                  },
                ),
                if (saved != null) ...[
                  const SizedBox(height: 10),
                  Text('Son kayıt: $saved', style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: library.items.isEmpty || library.isLoading ? null : () => library.refreshNow(),
                  child: Text(library.isLoading ? 'Güncelleniyor' : 'Şimdi güncelle'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmDrop(BuildContext context, UserSource source) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaynağı kaldır'),
        content: Text('${source.label} ve kayıtlı liste silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaldır')),
        ],
      ),
    );
    if (yes == true) {
      await library.drop(source.id);
    }
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: 'Mia Stream — kişisel medya oynatıcı'),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paylaşım metni kopyalandı')),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    return Material(
      color: mia.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mia.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 58, color: mia.line),
            children[i],
          ],
        ],
      ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mia = context.mia;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: mia.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: MiaType.manrope(15, 650, color: Colors.white)),
            ),
            Icon(Icons.chevron_right, color: mia.muted),
          ],
        ),
      ),
    );
  }
}

class _Subpage extends StatelessWidget {
  const _Subpage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mia.background,
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _PersonalPage extends StatelessWidget {
  const _PersonalPage();

  @override
  Widget build(BuildContext context) {
    final look = LookScope.of(context);
    return _Subpage(
      title: 'Kişiselleştirme',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sonrakini otomatik oynat'),
            subtitle: const Text('Bölüm bitince sıradaki senin içeriğine geçer.'),
            value: look.autoplayNext,
            onChanged: look.setAutoplay,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kaldığın yerden devam'),
            value: look.resumeWatching,
            onChanged: look.setResume,
          ),
          const SizedBox(height: 16),
          Text('Açılış sayfası', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(
            values: [
              for (final section in ShellSection.values)
                if (section != ShellSection.menu) section.label,
            ],
            selected: look.openingPage,
            onSelect: look.setOpeningPage,
          ),
          const SizedBox(height: 20),
          const HomeRailEditor(),
        ],
      ),
    );
  }
}

class _PlayerPage extends StatelessWidget {
  const _PlayerPage();

  @override
  Widget build(BuildContext context) {
    final look = LookScope.of(context);
    return _Subpage(
      title: 'Video oynatıcı ayarları',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('En boy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(
            values: const ['Otomatik', '16:9', 'Doldur'],
            selected: look.aspect,
            onSelect: look.setAspect,
          ),
          const SizedBox(height: 20),
          Text('Veri', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Kaynak birkaç boy sunuyorsa Düşük en küçüğünü, Orta yaklaşık 720p sınırını, Yüksek en büyüğünü seçer. Tek dosyaysa indirme aynı kalır.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          _Choice(
            values: dataSaveChoices,
            selected: look.dataSave,
            onSelect: look.setDataSave,
          ),
          const SizedBox(height: 20),
          Text('Altyazı boyutu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(
            values: const ['Küçük', 'Orta', 'Büyük'],
            selected: look.subtitleSize,
            onSelect: look.setSubtitleSize,
          ),
          const SizedBox(height: 20),
          Text('Varsayılan ses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(values: spokenLanguages, selected: look.audioPrimary, onSelect: look.setAudioPrimary),
          const SizedBox(height: 16),
          Text('İkinci ses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(values: spokenLanguages, selected: look.audioSecondary, onSelect: look.setAudioSecondary),
          const SizedBox(height: 20),
          Text('Varsayılan altyazı', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(
            values: subtitleLanguages,
            selected: look.subtitlePrimary,
            onSelect: look.setSubtitlePrimary,
          ),
          const SizedBox(height: 16),
          Text('İkinci altyazı', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _Choice(
            values: subtitleLanguages,
            selected: look.subtitleSecondary,
            onSelect: look.setSubtitleSecondary,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Ses ${look.audioPrimary} ise altyazı önerme'),
            subtitle: const Text('Ses zaten bu dildeyse altyazı kapalı başlar. İstersen oynatıcıdan yine açarsın.'),
            value: look.skipSubtitleWhenAudioMatches,
            onChanged: look.setSkipSubtitle,
          ),
          const SizedBox(height: 12),
          Text(
            'Oynatıcı, senin eklediğin kaynağı oynatır.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EpgSettingsPage extends StatelessWidget {
  const _EpgSettingsPage();

  @override
  Widget build(BuildContext context) {
    final look = LookScope.of(context);
    return _Subpage(
      title: 'EPG',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('24 saat'),
            value: look.clock24,
            onChanged: look.setClock24,
          ),
          const SizedBox(height: 8),
          Text(
            'Program rehberi, senin kaynağının rehber adresinden okunur. Gömülü rehber yok.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ThemePage extends StatelessWidget {
  const _ThemePage();

  @override
  Widget build(BuildContext context) {
    final look = LookScope.of(context);
    return _Subpage(
      title: 'Tema',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final mood in MiaMood.values)
            _MoodTile(
              mood: mood,
              selected: look.mood == mood,
              onTap: () => look.setMood(mood),
            ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({required this.mood, required this.selected, required this.onTap});

  final MiaMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = switch (mood) {
      MiaMood.sinema => MiaPalette.sinema,
      MiaMood.gece => MiaPalette.gece,
      MiaMood.kum => MiaPalette.kum,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.accent : context.mia.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [palette.glow, palette.accent]),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    palette.label,
                    style: MiaType.outfit(18, 580, color: Colors.white),
                  ),
                ),
                if (selected) Icon(Icons.check, color: palette.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevicesPage extends StatefulWidget {
  const _DevicesPage({required this.library, required this.seat});

  final UserLibrary library;
  final SeatStore seat;

  @override
  State<_DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<_DevicesPage> {
  final _sync = DeviceSync();
  final _address = TextEditingController();
  final _code = TextEditingController();
  String? _note;

  @override
  void dispose() {
    _sync.close();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _host() async {
    final error = await _sync.host(sources: widget.library.sourceBag(), marks: widget.seat.carryBag());
    if (!mounted) {
      return;
    }
    setState(() {
      _note = error ?? 'Kod ${_sync.code}. Adres ${_sync.address}. Aynı Wi-Fi’deki diğer Mia Stream’den katıl.';
    });
  }

  Future<void> _join() async {
    final bag = await _sync.join(_address.text, _code.text);
    if (!mounted) {
      return;
    }
    if (bag == null) {
      setState(() => _note = 'Eşleşme olmadı. Adres ve kod aynı ağda olmalı.');
      return;
    }
    final sources = <UserSource>[];
    final rawSources = bag['sources'];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is! Map) {
          continue;
        }
        final kindName = item['kind']?.toString();
        UserSourceKind? kind;
        for (final value in UserSourceKind.values) {
          if (value.name == kindName) {
            kind = value;
          }
        }
        if (kind == null) {
          continue;
        }
        sources.add(
          UserSource(
            id: item['id']?.toString() ?? '',
            label: item['label']?.toString() ?? 'Kaynak',
            kind: kind,
            value: item['value']?.toString() ?? '',
            username: item['username']?.toString() ?? '',
            password: item['password']?.toString() ?? '',
            mac: item['mac']?.toString() ?? '',
          ),
        );
      }
    }
    await widget.library.takeSources(sources);
    final marks = bag['marks'];
    if (marks is Map) {
      widget.seat.absorbBag(marks);
    }
    if (!mounted) {
      return;
    }
    setState(() => _note = 'Kaynak, favori ve izleme yeri bu cihaza geldi.');
  }

  @override
  Widget build(BuildContext context) {
    return _Subpage(
      title: 'Diğer cihazlarda kullanma',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Aynı Wi-Fi’de kaynak, favori ve izleme yeri gider. Dışarı hesap yok.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _host, child: const Text('Bu ağı aç')),
          const SizedBox(height: 16),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Adres'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Kod'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _join, child: const Text('Katıl')),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(_note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          const _DeviceRow(icon: Icons.smartphone, title: 'Telefon'),
          const _DeviceRow(icon: Icons.computer, title: 'Bilgisayar'),
          const _DeviceRow(icon: Icons.tv, title: 'TV'),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.mia.accent),
      title: Text(title),
    );
  }
}

class _RatePage extends StatelessWidget {
  const _RatePage();

  @override
  Widget build(BuildContext context) {
    return _Subpage(
      title: 'Uygulamayı değerlendir',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Mağaza yayını açılınca değerlendirme bu ekrandan gider.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.values, required this.selected, required this.onSelect});

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(value),
            selected: value == selected,
            onSelected: (_) => onSelect(value),
          ),
      ],
    );
  }
}
