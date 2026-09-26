import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miastream/app.dart';
import 'package:miastream/features/browse/title_page.dart';
import 'package:miastream/features/library/user_library.dart';
import 'package:miastream/features/library/user_source.dart';
import 'package:miastream/features/lounge/seat_store.dart';
import 'package:miastream/features/offline/download_store.dart';
import 'package:miastream/features/playback/media_entry.dart';
import 'package:miastream/features/playback/playback_bus.dart';
import 'package:miastream/features/playback/source_loader.dart';
import 'package:miastream/features/shell/shell_section.dart';
import 'package:miastream/features/sync/lounge_link.dart';

class _QuietLoader extends SourceLoader {
  const _QuietLoader();

  @override
  Future<List<MediaEntry>> load(UserSource source, {void Function(String label, int count)? onPulse}) async => const [];
}

class _FailLoader extends SourceLoader {
  const _FailLoader();

  @override
  Future<List<MediaEntry>> load(UserSource source, {void Function(String label, int count)? onPulse}) async {
    throw SourceLoadException('Kaynak yanıt vermedi');
  }
}

Future<void> _addSalon(WidgetTester tester) async {
  await tester.tap(find.text('Kaynak Ekle'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('M3U / M3U8 Oynatma Listesi'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'Salon');
  await tester.enterText(find.byType(TextField).at(1), 'https://ornek.invalid/liste.m3u');
  await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
  await tester.pumpAndSettle();
  final seat = find.text('Miran');
  if (seat.evaluate().isNotEmpty) {
    await tester.tap(seat.first);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('kaynak yokken yalnızca kaynak ekle vardır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiaStreamApp(loader: _QuietLoader()));
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Mia Stream'), findsOneWidget);
    expect(find.text('kişisel medya oynatıcı'), findsOneWidget);
    expect(find.text('Kaynak Ekle'), findsOneWidget);
    expect(find.textContaining('kişisel medya oynatıcıdır'), findsOneWidget);
    expect(find.text('Ücretsiz devam et'), findsNothing);
    expect(find.textContaining('Henüz kaynak yok'), findsNothing);

    await _addSalon(tester);

    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Canlı TV'), findsWidgets);
  });

  testWidgets('geniş ekranda alt şerit yok, sol ray var', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiaStreamApp(loader: _QuietLoader()));
    await tester.pump(const Duration(seconds: 3));
    await _addSalon(tester);

    expect(find.text('Canlı TV'), findsWidgets);
    expect(find.text('Diziler'), findsWidgets);
    expect(find.text('Çevrimdışı'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('ayar menüsü ve xtream alanları', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiaStreamApp(loader: _QuietLoader()));
    await tester.pump(const Duration(seconds: 3));
    await _addSalon(tester);
    await tester.tap(find.text('Menü'));
    await tester.pumpAndSettle();

    expect(find.text('Kişiselleştirme'), findsOneWidget);
    expect(find.text('Video oynatıcı ayarları'), findsOneWidget);
    expect(find.text('EPG'), findsWidgets);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Diğer cihazlarda kullanma'), findsOneWidget);
    expect(find.text('Uygulamayı paylaş'), findsOneWidget);
    expect(find.text('Uygulamayı değerlendir'), findsOneWidget);

    await tester.tap(find.text('Kaynak ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('Stalker Portalı'), findsOneWidget);
    await tester.tap(find.text('Xtream Codes'));
    await tester.pumpAndSettle();
    expect(find.text('Sunucu'), findsOneWidget);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });

  testWidgets('yanıt vermeyen kaynak anasayfayı açmaz', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MiaStreamApp(loader: _FailLoader()));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Kaynak Ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('M3U / M3U8 Oynatma Listesi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Salon');
    await tester.enterText(find.byType(TextField).at(1), 'https://ornek.invalid/liste.m3u');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Kaynak yanıt vermedi'), findsOneWidget);
    expect(find.text('Liste adresi'), findsOneWidget);
    expect(find.text('Canlı TV'), findsNothing);
  });

  testWidgets('detay geniş ekranda afiş tam genişler', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TitlePage(
          entry: const MediaEntry(
            id: '1',
            title: 'Geniş Film',
            section: ShellSection.movies,
            sourceId: 'yok',
            url: 'https://ornek.invalid/a.mp4',
          ),
          library: UserLibrary(loader: const _QuietLoader()),
          bus: PlaybackBus(),
          downloads: DownloadStore(),
          seat: SeatStore(),
          link: LoungeLink(),
          similar: const [],
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pump();

    final hero = tester.getSize(find.byKey(const Key('title-hero')));
    expect(hero.width, 1400);
    expect(hero.height, 640);
    expect(find.text('Oynat'), findsOneWidget);
    expect(find.text('Listem'), findsOneWidget);
  });
}
