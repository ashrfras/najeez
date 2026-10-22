import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF080D12);
  static const surface = Color(0xFF101820);
  static const surfaceRaised = Color(0xFF16212C);
  static const border = Color(0xFF26323E);
  static const text = Color(0xFFF5F7FA);
  static const muted = Color(0xFF9CAABD);
  static const blue = Color(0xFF168FFF);
  static const blueDim = Color(0xFF0B2D4C);
  static const green = Color(0xFF0BC889);
  static const orange = Color(0xFFFFA727);
  static const purple = Color(0xFFBA8AF4);
  static const red = Color(0xFFFF474D);

  // Separate hue, saturation and lightness so badges remain distinguishable
  // on dark surfaces. Keep the order stable: names determine palette indices.
  static const categoryPalette = <Color>[
    blue,
    purple,
    green,
    orange,
    red,
    Color(0xFF36D9ED), // Cyan, clearly lighter than blue.
    Color(0xFF9BAFC4), // Slate, replacing the second green accent.
    Color(0xFFB9E44C), // Lime.
    Color(0xFFFFE066), // Yellow, lighter than orange.
    Color(0xFFF064C4), // Magenta.
    Color(0xFF7C83FF), // Indigo.
    Color(0xFFD6AA75), // Sand, replacing the second red accent.
  ];

  /// A stable, automatic color shared by category badges and statistics.
  static Color category(String? tag) {
    final label = tag?.trim();
    if (label == null || label.isEmpty) return muted;
    final hash = label.runes.fold(
      0,
      (value, rune) => (value * 31 + rune) & 0x7fffffff,
    );
    return categoryPalette[hash % categoryPalette.length];
  }
}

abstract final class AppSpace {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

abstract final class AppRadius {
  static const card = 16.0;
  static const control = 13.0;
}

abstract final class AppType {
  static const title = TextStyle(
    fontSize: 29,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );
  static const section = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
  static const caption = TextStyle(fontSize: 12, color: AppColors.muted);
}

BoxDecoration panel({
  Color? color,
  double radius = AppRadius.card,
  Color? border,
}) => BoxDecoration(
  color: color ?? AppColors.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border ?? AppColors.border, width: .8),
);
