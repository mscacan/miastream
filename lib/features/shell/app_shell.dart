import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/brand.dart';
import '../../core/look.dart';
import '../../core/mia_mark.dart';
import '../../core/theme.dart';
import '../assist/bot_page.dart';
import '../browse/catalog_page.dart';
import '../browse/home_page.dart';
import '../browse/title_page.dart';
import '../epg/epg_page.dart';
import '../library/add_source_page.dart';
import '../assist/library_mind.dart';
import '../library/user_library.dart';
import '../library/keep_store.dart';
import '../playback/media_entry.dart';
import '../playback/playback_bus.dart';
import '../playback/player_page.dart';
import '../playback/series_page.dart';
import '../offline/download_store.dart';
import '../offline/offline_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import '../sync/lounge_link.dart';
import 'shell_section.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.library,
    required this.bus,
    required this.downloads,
    required this.keeps,
    required this.link,
  });

  final UserLibrary library;
  final PlaybackBus bus;
  final DownloadStore downloads;
  final KeepStore keeps;
  final LoungeLink link;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _section = ShellSection.live;
  var _sharedUrl = '';
  var _openingApplied = false;

  @override
  void initState() {
    super.initState();
    widget.link.addListener(_onLink);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openingApplied) {
      return;
    }
    _openingApplied = true;
    _section = ShellSection.byLabel(LookScope.of(context).openingPage);
  }

  @override
  void dispose() {
    widget.link.removeListener(_onLink);
    super.dispose();
  }

  void _onLink() {
    if (!mounted || widget.link.role != LoungeRole.guest) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final signal = widget.link.incoming;
    final url = signal?.url;
    if (url == null || url.isEmpty || url == _sharedUrl) {
      return;
    }
    _sharedUrl = url;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          library: widget.library,
          bus: widget.bus,
          keeps: widget.keeps,
          link: widget.link,
          cues: [
            PlaybackCue(
              title: signal?.title ?? 'Birlikte',
              url: url,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() => addUserSource(context, widget.library);

  void _openEntry(MediaEntry entry) {
    if (entry.playCmd != null || (entry.url != null && entry.section == ShellSection.live)) {
      _playListed(entry);
      return;
    }
    if (entry.section == ShellSection.movies || entry.section == ShellSection.series) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => TitlePage(
            entry: entry,
            library: widget.library,
            bus: widget.bus,
            downloads: widget.downloads,
            keeps: widget.keeps,
            link: widget.link,
            similar: _similar(entry),
            onOpen: _openEntry,
          ),
        ),
      );
      return;
    }
    if (entry.url != null) {
      _playListed(entry);
      return;
    }
    final source = widget.library.sourceById(entry.sourceId);
    final seriesId = entry.seriesId;
    if (source == null || seriesId == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SeriesPage(
          loader: widget.library.loader,
          source: source,
          seriesId: seriesId,
          title: entry.title,
          artwork: entry.artwork,
          entryId: entry.id,
          library: widget.library,
          bus: widget.bus,
          keeps: widget.keeps,
        ),
      ),
    );
  }

  void _playListed(MediaEntry entry) {
    final siblings = [
      for (final item in widget.library.entriesFor(entry.section))
        if (item.url != null || item.playCmd != null) item,
    ];
    final start = siblings.indexWhere((item) => item.id == entry.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          live: entry.section == ShellSection.live,
          start: start < 0 ? 0 : start,
          library: widget.library,
          bus: widget.bus,
          keeps: widget.keeps,
          link: widget.link,
          cues: [for (final item in siblings) item.toCue()],
        ),
      ),
    );
  }

  Future<void> _openEpisode(MediaEntry entry, int? season, int? number) async {
    final source = widget.library.sourceById(entry.sourceId);
    final seriesId = entry.seriesId;
    if (source == null || seriesId == null) {
      _openEntry(entry);
      return;
    }
    try {
      final episodes = await widget.library.loader.episodes(source, seriesId);
      if (!mounted) {
        return;
      }
      final index = episodes.indexWhere((item) => item.season == season && item.number == number);
      if (index < 0) {
        _openEntry(entry);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => PlayerPage(
            start: index,
            library: widget.library,
            bus: widget.bus,
            keeps: widget.keeps,
            link: widget.link,
            cues: [
              for (final item in episodes)
                PlaybackCue(
                  id: entry.id,
                  title: item.title,
                  url: item.url,
                  artwork: item.artwork ?? entry.artwork,
                  seriesTitle: entry.title,
                  season: item.season,
                  number: item.number,
                ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _openEntry(entry);
      }
    }
  }

  List<MediaEntry> _similar(MediaEntry entry) {
    final pool = [
      for (final item in widget.library.entriesFor(entry.section))
        if (item.id != entry.id) item,
    ];
    final ranked = [...pool]..sort((a, b) => kinship(entry, b).compareTo(kinship(entry, a)));
    final close = ranked.where((item) => kinship(entry, item) > 0).toList();
    final picked = close.isNotEmpty ? close : ranked;
    if (picked.length <= 18) {
      return picked;
    }
    return picked.sublist(0, 18);
  }

  void _resume(PlaybackHandoff handoff) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlayerPage(
          cues: handoff.cues,
          start: handoff.index,
          live: handoff.live,
          library: handoff.library,
          bus: widget.bus,
          keeps: widget.keeps,
          link: widget.link,
          adoptedPlayer: handoff.player,
          adoptedVideo: handoff.video,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = miaIsPhone(context);
    return Scaffold(
      key: _scaffoldKey,
      extendBody: phone,
      backgroundColor: context.mia.background,
      drawer: ListenableBuilder(
        listenable: widget.keeps,
        builder: (context, _) => _AppDrawer(
          onAdd: _add,
          favoriteCount: widget.keeps.favoriteCount,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _body()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              phone: phone,
              section: _section,
              onSelect: (section) => setState(() => _section = section),
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onCast: () => showCastSheet(context),
              onEpg: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => EpgPage(library: widget.library)),
                );
              },
              onSearch: () => setState(() => _section = ShellSection.search),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: ListenableBuilder(
              listenable: widget.bus,
              builder: (context, _) {
                if (!widget.bus.showing) {
                  return const SizedBox.shrink();
                }
                final cues = widget.bus.cues;
                final index = widget.bus.index.clamp(0, cues.isEmpty ? 0 : cues.length - 1);
                final cue = cues.isEmpty ? null : cues[index];
                return _MiniPlayer(
                  title: cue?.headline ?? '',
                  video: widget.bus.video!,
                  onOpen: () {
                    final handoff = widget.bus.take();
                    if (handoff == null) {
                      return;
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _resume(handoff);
                    });
                  },
                  onClose: widget.bus.close,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: phone
          ? _PhoneNav(
              section: _section,
              onSelect: (section) => setState(() => _section = section),
            )
          : null,
    );
  }

  Widget _body() {
    final catalog = _section == ShellSection.live || _section == ShellSection.series || _section == ShellSection.movies;
    final page = switch (_section) {
      ShellSection.home => HomePage(
          library: widget.library,
          keeps: widget.keeps,
          onPlay: _openEntry,
          onResume: _openEpisode,
          onAdd: _add,
        ),
      ShellSection.live || ShellSection.series || ShellSection.movies => CatalogPage(
          section: _section,
          library: widget.library,
          keeps: widget.keeps,
          onAdd: _add,
          onPlay: _openEntry,
          onFilter: (section) => setState(() => _section = section),
        ),
      ShellSection.offline => OfflinePage(
          downloads: widget.downloads,
          library: widget.library,
          bus: widget.bus,
        ),
      ShellSection.search => SearchPage(library: widget.library, onPlay: _openEntry),
      ShellSection.bot => BotPage(library: widget.library, onPlay: _openEntry),
      ShellSection.menu => SettingsPage(
          onAdd: _add,
          library: widget.library,
          keeps: widget.keeps,
          onPlay: _openEntry,
        ),
    };
    if (catalog) {
      return page;
    }
    final phone = miaIsPhone(context);
    final chips = phone && _section != ShellSection.search && _section != ShellSection.menu;
    final top = MediaQuery.paddingOf(context).top + (phone ? (chips ? 100 : 56) : 62);
    return Padding(padding: EdgeInsets.only(top: top), child: page);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.phone,
    required this.section,
    required this.onSelect,
    required this.onMenu,
    required this.onCast,
    required this.onEpg,
    required this.onSearch,
  });

  final bool phone;
  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;
  final VoidCallback onMenu;
  final VoidCallback onCast;
  final VoidCallback onEpg;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final browse = phone && section != ShellSection.search && section != ShellSection.menu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: phone ? const Color(0xFF141414) : null,
        gradient: phone
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6000000), Color(0x66000000), Color(0x00000000)],
                stops: [0, 0.55, 1],
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: phone ? 48 : 62,
              child: Row(
                children: [
                  if (phone)
                    GestureDetector(
                      onTap: onMenu,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: const MiaWord(size: 22, compact: true),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: GestureDetector(
                        onTap: () => onSelect(ShellSection.home),
                        child: const MiaWord(size: 22),
                      ),
                    ),
                  if (phone)
                    Expanded(
                      child: Text(
                        _phoneTitle(section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MiaType.outfit(20, 650, color: Colors.white),
                      ),
                    )
                  else ...[
                    const SizedBox(width: 28),
                    for (final item in const [
                      ShellSection.home,
                      ShellSection.live,
                      ShellSection.series,
                      ShellSection.movies,
                      ShellSection.bot,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 18),
                        child: InkWell(
                          onTap: () => onSelect(item),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              item.label,
                              style: MiaType.manrope(
                                14,
                                item == section ? 700 : 500,
                                color: item == section ? Colors.white : const Color(0xFFE5E5E5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                  ],
                  if (phone) ...[
                    IconButton(
                      onPressed: () => onSelect(ShellSection.offline),
                      tooltip: 'İndirilenler',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.download_outlined),
                    ),
                    IconButton(
                      onPressed: onSearch,
                      tooltip: 'Arama',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      onPressed: onEpg,
                      tooltip: 'EPG',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.notifications_none),
                    ),
                  ] else ...[
                    IconButton(
                      onPressed: onSearch,
                      tooltip: 'Arama',
                      icon: const Icon(Icons.search, size: 26),
                    ),
                    IconButton(
                      onPressed: onEpg,
                      tooltip: 'EPG',
                      icon: const Icon(Icons.notifications_none, size: 26),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 28),
                      child: PopupMenuButton<String>(
                        tooltip: 'Menü',
                        offset: const Offset(0, 42),
                        color: const Color(0xFF181818),
                        onSelected: (value) {
                          switch (value) {
                            case 'offline':
                              onSelect(ShellSection.offline);
                            case 'menu':
                              onSelect(ShellSection.menu);
                            case 'cast':
                              onCast();
                            case 'rails':
                              homeRailEdit.value?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'menu', child: Text('Menü', style: MiaType.manrope(14, 600, color: Colors.white))),
                          if (section == ShellSection.home && homeRailEdit.value != null)
                            PopupMenuItem(
                              value: 'rails',
                              child: Text('Rafları düzenle', style: MiaType.manrope(14, 600, color: Colors.white)),
                            ),
                          PopupMenuItem(value: 'offline', child: Text('Çevrimdışı', style: MiaType.manrope(14, 600, color: Colors.white))),
                          PopupMenuItem(value: 'cast', child: Text('Ekran paylaş', style: MiaType.manrope(14, 600, color: Colors.white))),
                        ],
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (phone) const SizedBox(width: 6),
                ],
              ),
            ),
            if (phone && browse)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final item in [
                      ShellSection.live,
                      ShellSection.series,
                      ShellSection.movies,
                      ShellSection.bot,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.label),
                          selected: item == section,
                          showCheckmark: false,
                          onSelected: (_) => onSelect(item),
                          labelStyle: MiaType.manrope(13, 650, color: Colors.white),
                          selectedColor: const Color(0xFF3A3A3A),
                          backgroundColor: const Color(0xFF2A2A2A),
                          side: const BorderSide(color: Color(0xFF3A3A3A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _phoneTitle(ShellSection section) {
  return switch (section) {
    ShellSection.home => 'Ana Sayfa',
    ShellSection.live => 'Canlı TV',
    ShellSection.series => 'Diziler',
    ShellSection.movies => 'Filmler',
    ShellSection.offline => 'İndirilenler',
    ShellSection.search => 'Ara',
    ShellSection.bot => 'Bot',
    ShellSection.menu => 'Menü',
  };
}

class _PhoneNav extends StatelessWidget {
  const _PhoneNav({required this.section, required this.onSelect});

  final ShellSection section;
  final ValueChanged<ShellSection> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (ShellSection.home, 'Ana Sayfa', Icons.home_outlined),
      (ShellSection.live, 'Canlı TV', Icons.live_tv_outlined),
      (ShellSection.series, 'Diziler', Icons.video_library_outlined),
      (ShellSection.movies, 'Filmler', Icons.movie_outlined),
      (ShellSection.menu, 'Menü', Icons.menu),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF01A1A1A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelect(item.$1),
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: item.$1 == section ? const Color(0xFF3A3A3A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Icon(item.$3, size: 22, color: Colors.white),
                            ),
                          ),
                          Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.onAdd,
    required this.favoriteCount,
  });

  final VoidCallback onAdd;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.mia.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const MiaWord(size: 22),
            const SizedBox(height: 4),
            Text(Brand.storeSubtitle, style: TextStyle(color: context.mia.muted)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Kaynak ekle'),
              onTap: () {
                Navigator.pop(context);
                onAdd();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Favoriler'),
              subtitle: Text(favoriteCount == 0 ? 'Henüz işaret yok' : '$favoriteCount kayıt'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.title,
    required this.video,
    required this.onOpen,
    required this.onClose,
  });

  final String title;
  final VideoController video;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 240,
        height: 148,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onOpen,
              child: Video(controller: video, controls: NoVideoControls, fit: BoxFit.cover),
            ),
            Positioned(
              left: 8,
              right: 36,
              bottom: 8,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MiaType.manrope(12, 700, color: Colors.white),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Kapat',
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
