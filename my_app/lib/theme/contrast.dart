import 'package:flutter/material.dart';

Color contrastingTextColor(Color background) {
  // `computeLuminance` returns 0 (dark) -> 1 (light).
  // Use dark text on light backgrounds for readability.
  return background.computeLuminance() > 0.6
      ? const Color(0xFF111827)
      : Colors.white;
}

