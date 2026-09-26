import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miastream/core/brand.dart';
import 'package:miastream/core/rules.dart';
import 'package:miastream/features/library/user_library.dart';
import 'package:miastream/features/library/user_source.dart';
import 'package:miastream/features/playback/media_entry.dart';
import 'package:miastream/features/playback/source_loader.dart';
import 'package:miastream/features/shell/shell_section.dart';

class _QuietLoader extends SourceLoader {
  const _QuietLoader();

  @override
  Future<List<MediaEntry>> load(UserSource source, {void Function(String label, int count)? onPulse}) async => const [];
}

void main() {
  test('ürün yayın ve varsayılan liste taşımaz', () {
    ProductRules.assertInvariants();
    expect(ProductRules.sellsBroadcasts, isFalse);
    expect(ProductRules.shipsDefaultPlaylist, isFalse);
    expect(ProductRules.shipsPiratePackage, isFalse);
    expect(ProductRules.membershipRequired, isTrue);
    expect(ProductRules.launchIsFree, isTrue);
    expect(BrandStoreCopy.title, Brand.name);
    expect(BrandStoreCopy.subtitle, 'kişisel medya oynatıcı');
    expect(BrandStoreCopy.title.toLowerCase(), isNot(contains('iptv')));
  });

  test('kütüphane boş başlar ve yalnızca eklenen kaynağı tutar', () async {
    final library = UserLibrary(loader: const _QuietLoader());
    expect(library.items, isEmpty);

    final error = await library.tryAdd(
      const UserSource(
        id: '1',
        label: 'Benim listem',
        kind: UserSourceKind.m3u,
        value: 'https://ornek.invalid/liste.m3u',
      ),
    );

    expect(error, isNull);
    expect(library.items, hasLength(1));
    expect(library.items.single.label, 'Benim listem');
    library.dispose();
  });

  test('eklenen kaynak sonraki açılışta durur', () async {
    final folder = await Directory.systemTemp.createTemp('mia-kaynak');
    addTearDown(() => folder.delete(recursive: true));
    Future<Directory> dir() async => folder;

    final first = UserLibrary(loader: const _QuietLoader(), folder: dir);
    final error = await first.tryAdd(
      const UserSource(
        id: 'salon',
        label: 'Salon',
        kind: UserSourceKind.xtream,
        value: 'https://ornek.invalid',
        username: 'uye',
        password: 'gizli',
      ),
    );
    expect(error, isNull);
    first.dispose();

    final second = UserLibrary(loader: const _QuietLoader(), folder: dir);
    expect(second.items, isEmpty);
    await second.restore();
    expect(second.items, hasLength(1));
    expect(second.items.single.value, 'https://ornek.invalid');
    expect(second.items.single.username, 'uye');
    expect(second.items.single.password, 'gizli');
    second.dispose();
  });

  test('kayıtlı liste sonraki açılışta ağ beklemeden durur', () async {
    final folder = await Directory.systemTemp.createTemp('mia-katalog');
    addTearDown(() => folder.delete(recursive: true));
    Future<Directory> dir() async => folder;
    final loader = _CountingLoader([
      const MediaEntry(
        id: 'film-1',
        title: 'Kayıtlı film',
        section: ShellSection.movies,
        sourceId: 'salon',
        artwork: 'https://ornek.invalid/afis.jpg',
      ),
    ]);
    final first = UserLibrary(loader: loader, folder: dir, now: () => DateTime.utc(2026, 9, 1));
    final error = await first.tryAdd(
      const UserSource(
        id: 'salon',
        label: 'Salon',
        kind: UserSourceKind.xtream,
        value: 'https://ornek.invalid',
        username: 'uye',
        password: 'gizli',
      ),
    );
    expect(error, isNull);
    expect(loader.calls, 1);
    first.dispose();

    final second = UserLibrary(loader: loader, folder: dir, now: () => DateTime.utc(2026, 9, 3));
    await second.restore();
    await second.settled;
    expect(second.items, hasLength(1));
    expect(second.entries.single.title, 'Kayıtlı film');
    expect(second.entries.single.artwork, 'https://ornek.invalid/afis.jpg');
    expect(loader.calls, 1);
    expect(second.refreshEvery, sourceRefreshWeekly);

    await second.setRefreshEvery(sourceRefreshDaily);
    final third = UserLibrary(loader: loader, folder: dir, now: () => DateTime.utc(2026, 9, 5));
    await third.restore();
    await third.settled;
    expect(third.refreshEvery, sourceRefreshDaily);
    expect(loader.calls, 2);
    expect(third.entries.single.title, 'Kayıtlı film');
    third.dispose();
    second.dispose();
  });
}

class _CountingLoader extends SourceLoader {
  _CountingLoader(this.entries);

  final List<MediaEntry> entries;
  var calls = 0;

  @override
  Future<List<MediaEntry>> load(UserSource source, {void Function(String label, int count)? onPulse}) async {
    calls += 1;
    return entries;
  }
}
