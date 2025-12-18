import 'package:flutter/material.dart';

const String API_ROOT = "http://sea.main.rainbowcreation.net:8080";
const String API_BASE = "$API_ROOT/v1";

class AppColors {
  static const bg = Color(0xFF101010); 
  static const card = Color(0xFF1D1D1D); 
  static const accent = Color(0xFF9379C2); 
  static const text = Color(0xFFFFFFFF); 
  static const textDim = Color(0xFFB0B0B0);

  static const gem = Color(0xFF4DD0E1);
  static const coin = Color(0xFFFFD54F);

  // 1. Solid Colors (Fallback)
  static Color getRarityColor(int rarity) {
    switch (rarity) {
      case 1: return const Color(0xFF9E9E9E); // COMMON: Grey
      case 2: return const Color(0xFF4CAF50); // UNCOMMON: Green
      case 3: return const Color(0xFF2196F3); // RARE: Blue
      case 4: return const Color(0xFF9C27B0); // EPIC: Purple
      case 5: return const Color(0xFFFFC107); // LEGENDARY: Gold
      case 6: return const Color(0xFFFF5252); // MYTHIC: Red
      
      // High Tiers (Swapped)
      case 7: return const Color(0xFFD500F9); // ANCIENT: Neon Pink (Void/Magic)
      case 8: return const Color(0xFF00E5FF); // DIVINE: Cyan (Holy/Light)
      case 9: return const Color(0xFFFFFFFF); // UNIQUE: White (Rainbow Base)
      default: return Colors.grey;
    }
  }

  // 2. Gradients (High Tiers)
  static Gradient? getGradient(int rarity) {
    switch (rarity) {
      // --- Standard Fades ---
      case 5: // LEGENDARY: Gold Fade
        return const LinearGradient(
          colors: [Color(0xFFFFCA28), Color(0xFFFF6F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 6: // MYTHIC: Red Fade
        return const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      // --- NEW HIGH TIERS ---
      
      case 7: // ANCIENT (Pink -> Deep Purple)
              // Gives a "Forbidden Magic" or "Void" feel
        return const LinearGradient(
          colors: [
            Color(0xFFD500F9), // Neon Pink
            Color(0xFF651FFF), // Deep Purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      case 8: // DIVINE (Cyan -> White)
              // Gives a "Holy", "Diamond", or "Heavenly" feel
        return const LinearGradient(
          colors: [
            Color(0xFF00E5FF), // Cyan Accent
            Color(0xFFE0F7FA), // White/Pale Cyan
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      // --- UNIQUE ---
      case 9: // UNIQUE: Rainbow Spectrum
        return const LinearGradient(
          colors: [
            Color(0xFFEF5350), 
            Color(0xFFFFCA28), 
            Color(0xFFFFFF00), 
            Color(0xFF66BB6A), 
            Color(0xFF42A5F5), 
            Color(0xFFAB47BC), 
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

      default:
        return null; 
    }
  }

  static String getRarityLabel(int rarity) {
    const map = [
      "?", 
      "COMMON", 
      "UNCOMMON", 
      "RARE", 
      "EPIC", 
      "LEGENDARY", 
      "MYTHIC", 
      "ANCIENT",
      "DIVINE",
      "UNIQUE"
    ];
    return (rarity >= 0 && rarity < map.length) ? map[rarity] : "?";
  }
}

class AppIcons {
  static const gem = Icons.diamond;
  static const coin = Icons.monetization_on;
}

class RarityText extends StatelessWidget {
  final String text;
  final int rarity;
  final double fontSize;

  const RarityText(this.text, {required this.rarity, this.fontSize = 14, super.key});

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.getGradient(rarity);
    final color = AppColors.getRarityColor(rarity);

    final style = TextStyle(
      fontWeight: FontWeight.bold, 
      fontSize: fontSize,
      color: gradient != null ? Colors.white : color, 
    );

    Widget textWidget = Text(text, style: style);

    if (gradient != null) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        ),
        child: textWidget,
      );
    }

    return textWidget;
  }
}

class RarityContainer extends StatelessWidget {
  final int rarity;
  final double? width;
  final double? height;
  final Widget? child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;

  const RarityContainer({
    super.key,
    required this.rarity,
    this.width,
    this.height,
    this.child,
    this.margin,
    this.padding,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getRarityColor(rarity);
    final gradient = AppColors.getGradient(rarity);

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : (borderRadius ?? BorderRadius.circular(0)),
        
        gradient: gradient,
        color: gradient == null ? color : null,
      ),
      child: child,
    );
  }
}