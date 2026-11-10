import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/brand.dart';
import 'core/device.dart';
import 'core/look.dart';
import 'core/mia_mark.dart';
import 'core/rules.dart';
import 'core/theme.dart';
import 'features/browse/cover_store.dart';
import 'features/library/add_source_page.dart';
import 'features/library/user_library.dart';
import 'features/library/keep_store.dart';
import 'features/membership/membership_gate.dart';
import 'features/offline/download_store.dart';
import 'features/playback/playback_bus.dart';
import 'features/playback/source_loader.dart';
import 'features/shell/app_shell.dart';
import 'features/sync/lounge_link.dart';

/// Kumandanın orta tuşu ve oyun kumandası A tuşu da seçer.
final Map<ShortcutActivator, Intent> _remoteShortcuts = {
  ...WidgetsApp.defaultShortcuts,
  const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
  const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
  // Web'de oklar varsayılan olarak sayfayı kaydırır; TV modunda odak taşımalı.
  if (MiaDevice.isTv) ...{
    const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
  },
};

class MiaStreamApp extends StatefulWidget {
  const MiaStreamApp({super.key, this.loader});

  final SourceLoader? loader;

  @override
  State<MiaStreamApp> createState() => _MiaStreamAppState();
}

class _MiaStreamAppState extends State<MiaStreamApp> {
  late final UserLibrary _library = UserLibrary(loader: widget.loader);
  final PlaybackBus _bus = PlaybackBus();
  final DownloadStore _downloads = DownloadStore();
  final KeepStore _keeps = KeepStore();
  final LoungeLink _link = LoungeLink();
  final MiaLook _look = MiaLook();
  final CoverStore _covers = CoverStore();
  var _sourcesReady = false;

  @override
  void initState() {
    super.initState();
    if (MiaDevice.isTv) {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    }
    _keeps.ensureLoaded();
    _look.ensureLoaded();
    _library.restore().whenComplete(() {
      if (mounted) {
        setState(() => _sourcesReady = true);
      }
    });
    ProductRules.assertInvariants();
    assert(ProductRules.launchIsFree);
    assert(_library.items.isEmpty);
  }

  @override
  void dispose() {
    _bus.close();
    _bus.dispose();
    _link.close();
    _link.dispose();
    _downloads.dispose();
    _keeps.dispose();
    _library.dispose();
    _look.dispose();
    _covers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _look,
      builder: (context, _) {
        return MaterialApp(
          title: Brand.name,
          debugShowCheckedModeBanner: false,
          theme: MiaTheme.data(_look.palette),
          themeAnimationDuration: Duration.zero,
          shortcuts: _remoteShortcuts,
          builder: (context, child) => LookScope(
            look: _look,
            child: CoverScope(store: _covers, child: child!),
          ),
          home: ListenableBuilder(
            listenable: _library,
            builder: (context, _) {
              return ListenableBuilder(
                listenable: _keeps,
                builder: (context, _) {
                  if (!_sourcesReady) {
                    return const ColoredBox(
                      color: Color(0xFF0B0B0F),
                      child: Center(child: MiaWord(size: 42)),
                    );
                  }
                  if (_library.items.isEmpty) {
                    return SourceEntry(
                      onAdd: () => addUserSource(context, _library),
                    );
                  }
                  final shell = AppShell(
                    library: _library,
                    bus: _bus,
                    downloads: _downloads,
                    keeps: _keeps,
                    link: _link,
                  );
                  return shell;
                },
              );
            },
          ),
        );
      },
    );
  }
}
