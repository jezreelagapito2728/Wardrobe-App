// Centralized color constants for the Wardrobe AI app
// Color Palette:
// - Dark: Forest Ink #1F2A24
// - Light: Linen #F4F1EA
// - Neutral: Soft Sage #A9B8A3

import 'package:flutter/material.dart';

// Primary palette
const Color forestInk = Color(0xFF1F2A24);  // Dark
const Color linen = Color(0xFFF4F1EA);       // Light
const Color softSage = Color(0xFFA9B8A3);    // Neutral

// Extended palette for variations
const Color forestInkLight = Color(0xFF2D4A3F);
const Color forestInkLighter = Color(0xFF3D5A4F);
const Color linenDark = Color(0xFFE8E4DD);
const Color linenDarker = Color(0xFFDCD8D0);
const Color softSageDark = Color(0xFF8A9A84);
const Color softSageLight = Color(0xFFC4D0BF);

// Semantic colors
const Color successGreen = Color(0xFF2D6A4F);
const Color warningAmber = Color(0xFFF4A261);
const Color errorRed = Color(0xFFE76F51);
const Color infoBlue = Color(0xFF2A9D8F);

// Gradient definitions
const LinearGradient forestGradient = LinearGradient(
  colors: [forestInk, forestInkLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient sageGradient = LinearGradient(
  colors: [softSage, softSageDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient linenGradient = LinearGradient(
  colors: [linen, linenDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Helper extensions
extension ColorExtensions on Color {
  Color withAlphaValue(double alpha) => withValues(alpha: alpha);

  // Forest Ink variations
  static Color get forestInk10 => forestInk.withValues(alpha: 0.1);
  static Color get forestInk20 => forestInk.withValues(alpha: 0.2);
  static Color get forestInk30 => forestInk.withValues(alpha: 0.3);
  static Color get forestInk40 => forestInk.withValues(alpha: 0.4);
  static Color get forestInk50 => forestInk.withValues(alpha: 0.5);
  static Color get forestInk60 => forestInk.withValues(alpha: 0.6);

  // Linen variations
  static Color get linen10 => linen.withValues(alpha: 0.1);
  static Color get linen20 => linen.withValues(alpha: 0.2);
  static Color get linen30 => linen.withValues(alpha: 0.3);

  // Soft Sage variations
  static Color get softSage10 => softSage.withValues(alpha: 0.1);
  static Color get softSage20 => softSage.withValues(alpha: 0.2);
  static Color get softSage30 => softSage.withValues(alpha: 0.3);
  static Color get softSage40 => softSage.withValues(alpha: 0.4);
}