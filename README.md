# Mia Stream

Kişisel medya oynatıcı. Film, dizi ve canlı yayını kendi kaynağından izlersin.

Marka Mia Stream. Çekirdek MIAS, Miran ve Asmin.

## İndir

- [Android](https://msc.so/miastream.apk)
- [macOS](https://msc.so/miastream.app)

macOS dosyası imzasızdır. İlk açılışta uygulamaya sağ tıklayıp Aç de.

## Kullanım

Uygulama boş açılır. Kaynağı kendin eklersin: M3U, Xtream veya Stalker. Liste, kapak ve kaldığın yer bu cihazda durur.

## Geliştirme

Flutter 3.47, Dart 3.13.

```bash
flutter pub get
flutter run -d macos
flutter test
```

Android paketi:

```bash
flutter build apk --release
```

macOS paketi:

```bash
flutter build macos --release
```

Sürüm 1.0.1. Paket kimliği `com.mias.stream`.
