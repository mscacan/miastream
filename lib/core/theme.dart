import 'package:flutter/material.dart';

class MiaPalette {
  const MiaPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.accent,
    required this.glow,
    required this.muted,
    required this.line,
    required this.label,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color accent;
  final Color glow;
  final Color muted;
  final Color line;
  final String label;

  static const sinema = MiaPalette(
    background: Color(0xFF141414),
    surface: Color(0xFF141414),
    card: Color(0xFF181818),
    accent: Color(0xFFE50914),
    glow: Color(0xFF5C121C),
    muted: Color(0xFFB3B3B3),
    line: Color(0xFF2A2A2A),
    label: 'Sinema',
  );

  static const gece = MiaPalette(
    background: Color(0xFF070B14),
    surface: Color(0xFF101624),
    card: Color(0xFF171E30),
    accent: Color(0xFF8AA4FF),
    glow: Color(0xFF1A2A55),
    muted: Color(0xFF9AA4BD),
    line: Color(0xFF2A3348),
    label: 'Gece',
  );

  static const kum = MiaPalette(
    background: Color(0xFF100E0C),
    surface: Color(0xFF1A1612),
    card: Color(0xFF241E18),
    accent: Color(0xFFE7B07A),
    glow: Color(0xFF4A3420),
    muted: Color(0xFFB3A79A),
    line: Color(0xFF3A3128),
    label: 'Kum',
  );
}

class MiaColors extends ThemeExtension<MiaColors> {
  const MiaColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.accent,
    required this.glow,
    required this.muted,
    required this.line,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color accent;
  final Color glow;
  final Color muted;
  final Color line;

  factory MiaColors.fromPalette(MiaPalette palette) {
    return MiaColors(
      background: palette.background,
      surface: palette.surface,
      card: palette.card,
      accent: palette.accent,
      glow: palette.glow,
      muted: palette.muted,
      line: palette.line,
    );
  }

  @override
  MiaColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? accent,
    Color? glow,
    Color? muted,
    Color? line,
  }) {
    return MiaColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      accent: accent ?? this.accent,
      glow: glow ?? this.glow,
      muted: muted ?? this.muted,
      line: line ?? this.line,
    );
  }

  @override
  MiaColors lerp(ThemeExtension<MiaColors>? other, double t) {
    if (other is! MiaColors) {
      return this;
    }
    return MiaColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension MiaContext on BuildContext {
  MiaColors get mia => Theme.of(this).extension<MiaColors>()!;
}

abstract final class MiaType {
  static TextStyle outfit(
    double size,
    double weight, {
    double letterSpacing = 0,
    double height = 1.15,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Outfit',
      fontSize: size,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', weight)],
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextStyle quicksand(
    double size,
    double weight, {
    double letterSpacing = 0,
    double height = 1.1,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Quicksand',
      fontSize: size,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', weight)],
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextStyle manrope(
    double size,
    double weight, {
    double height = 1.4,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w500,
      fontVariations: [FontVariation('wght', weight)],
      height: height,
      color: color,
    );
  }
}

abstract final class MiaTheme {
  static ThemeData data(MiaPalette palette) {
    final colors = MiaColors.fromPalette(palette);
    final scheme = ColorScheme.dark(
      primary: palette.accent,
      onPrimary: Colors.white,
      surface: palette.surface,
      onSurface: Colors.white,
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.background,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Manrope',
      extensions: [colors],
      textTheme: TextTheme(
        headlineLarge: MiaType.outfit(36, 620, letterSpacing: -0.8, height: 1.05),
        headlineMedium: MiaType.outfit(28, 600, letterSpacing: -0.4),
        titleLarge: MiaType.outfit(20, 580, letterSpacing: -0.2),
        titleMedium: MiaType.manrope(16, 650),
        bodyLarge: MiaType.manrope(16, 500),
        bodyMedium: MiaType.manrope(14, 500, color: palette.muted),
        labelLarge: MiaType.manrope(13, 650),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: MiaType.outfit(18, 600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: MiaType.manrope(15, 700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: palette.surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.card,
        labelStyle: MiaType.manrope(14, 500, color: palette.muted),
        hintStyle: MiaType.manrope(14, 500, color: palette.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent),
        ),
      ),
      dividerColor: palette.line,
    );
  }
}
