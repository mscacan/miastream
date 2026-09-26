import 'brand.dart';

abstract final class ProductRules {
  static const bool sellsBroadcasts = false;
  static const bool shipsDefaultPlaylist = false;
  static const bool shipsPiratePackage = false;
  static const bool membershipRequired = true;
  static const bool storeMaySayIptv = false;

  /// Başlangıç ücretsizdir. İndirme ve kullanıcı artınca ücretli plana geçilebilir.
  static const bool launchIsFree = true;

  static void assertInvariants() {
    assert(!sellsBroadcasts);
    assert(!shipsDefaultPlaylist);
    assert(!shipsPiratePackage);
    assert(membershipRequired);
    assert(!storeMaySayIptv);
    assert(!BrandStoreCopy.title.toLowerCase().contains('iptv'));
    assert(!BrandStoreCopy.subtitle.toLowerCase().contains('iptv'));
  }
}

abstract final class BrandStoreCopy {
  static const String title = Brand.name;
  static const String subtitle = Brand.storeSubtitle;
}
