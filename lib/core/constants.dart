import 'package:flutter/material.dart';

const String API_ROOT = "http://localhost:8080";
const String API_BASE = "$API_ROOT/v1";

class AppColors {
  static const bg = Color(0xFF111827); // slate-950
  static const card = Color(0xFF1E293B); // slate-800
  static const accent = Color(0xFF2563EB); // blue-600
  static const text = Color(0xFFE2E8F0); // slate-200
  static const textDim = Color(0xFF94A3B8); // slate-400
  
  static Color getRarityColor(int rarity) {
    switch (rarity) {
      case 1: return const Color(0xFF9CA3AF); // C
      case 2: return const Color(0xFF22C55E); // UC
      case 3: return const Color(0xFF3B82F6); // R
      case 4: return const Color(0xFFA855F7); // SR
      case 5: return const Color(0xFFEAB308); // SSR
      case 6: return const Color(0xFFEF4444); // UR
      case 7: return const Color(0xFFEC4899); // LEGEND
      case 8: return const Color(0xFF06B6D4); // SUPREM
      case 9: return const Color(0xFFFFFFFF); // UNIQUE
      default: return Colors.grey;
    }
  }
  
  static String getRarityLabel(int rarity) {
    const map = ["?", "C", "UC", "R", "SR", "SSR", "UR", "LEGEND", "SUPREM", "UNIQUE"];
    return (rarity >= 0 && rarity < map.length) ? map[rarity] : "?";
  }
}