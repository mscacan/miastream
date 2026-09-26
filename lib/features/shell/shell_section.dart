import 'package:flutter/material.dart';

enum ShellSection {
  home,
  live,
  series,
  movies,
  offline,
  search,
  bot,
  menu;

  String get label {
    return switch (this) {
      ShellSection.home => 'Ana Sayfa',
      ShellSection.live => 'Canlı TV',
      ShellSection.series => 'Diziler',
      ShellSection.movies => 'Filmler',
      ShellSection.offline => 'Çevrimdışı',
      ShellSection.search => 'Arama',
      ShellSection.bot => 'Bot',
      ShellSection.menu => 'Menü',
    };
  }

  static ShellSection byLabel(String label) {
    for (final section in ShellSection.values) {
      if (section.label == label) {
        return section;
      }
    }
    return ShellSection.live;
  }

  IconData get icon {
    return switch (this) {
      ShellSection.home => Icons.home_outlined,
      ShellSection.live => Icons.live_tv,
      ShellSection.series => Icons.video_library_outlined,
      ShellSection.movies => Icons.movie_outlined,
      ShellSection.offline => Icons.download_outlined,
      ShellSection.search => Icons.search,
      ShellSection.bot => Icons.auto_awesome_outlined,
      ShellSection.menu => Icons.settings_outlined,
    };
  }
}

/// Telefon alt şerit, geniş ekran sol ray.
bool miaIsPhone(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 800;
}
