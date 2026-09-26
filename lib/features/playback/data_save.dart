const dataSaveChoices = ['Otomatik', 'Düşük', 'Orta', 'Yüksek'];

/// mpv hls-bitrate. Sayı, sunucunun bildirdiği bit/sn tavanıdır.
String hlsBitrateFor(String choice) {
  return switch (choice) {
    'Düşük' => 'min',
    'Orta' => '2500000',
    'Yüksek' => 'max',
    _ => 'no',
  };
}

/// Bu yüksekliğin üstü, kaynağın küçük boy vermediği anlamına gelir.
int? dataSaveWarnAbove(String choice) {
  return switch (choice) {
    'Düşük' => 800,
    'Orta' => 1200,
    _ => null,
  };
}
