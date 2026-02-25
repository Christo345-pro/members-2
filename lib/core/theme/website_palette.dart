import 'package:flutter/material.dart';

class WebsitePalette {
  const WebsitePalette._();

  static const Color bgTop = Color(0xFF0B2233);
  static const Color bgMid = Color(0xFF0E2D44);
  static const Color bgBottom = Color(0xFF0F3B5A);

  static const Color ink = Color(0xFFEEF4FF);
  static const Color inkSoft = Color(0xFFCCE6D3);
  static const Color line = Color(0xFF5F9170);
  static const Color panel = Color(0xE00B2639);

  static const Color accent = Color(0xFF33CC33);
  static const Color accentStrong = Color(0xFFFFB777);
  static const Color sun = Color(0xFFFF9933);
  static const Color mint = Color(0xFF8CE08C);
  static const Color danger = Color(0xFFFF6F7B);

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBottom],
  );
}
