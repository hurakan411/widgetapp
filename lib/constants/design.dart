import 'package:flutter/material.dart';

class AppColors {
  // Base Colors
  static const Color background = Color(0xFFE8E2E4); // Warm Mauve Grey

  // Primary Colors (Done)
  static const Color mustardYellow = Color(0xFFE3B04B);
  static const Color sageGreen = Color(0xFF8A9A5B);
  static const Color terracotta = Color(0xFFC05555);

  // Accent (Text/Icon)
  static const Color vintageNavy = Color(0xFF2C3E50);
  
  // Text Colors
  static const Color textPrimary = vintageNavy;
  static const Color textSecondary = Color(0xFF7A8FA3);

  // Shadows
  static const Color shadowLight = Color(0xFFFFFFFF);
  static const Color shadowDark = Color(0xFFA3B1C6);
}

class AppStyles {
  // Neumorphism Decoration (Convex / 凸)
  static BoxDecoration neumorphicConvex = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withOpacity(0.4), // Reduced opacity
        offset: const Offset(-3, -3), // Reduced offset
        blurRadius: 6, // Reduced blur
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.1), // Reduced opacity
        offset: const Offset(3, 3), // Reduced offset
        blurRadius: 6, // Reduced blur
      ),
    ],
  );

  // Neumorphism Decoration (Concave / 凹) - Pressed state
  static BoxDecoration neumorphicConcave = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1), // Reduced opacity
        offset: const Offset(-3, -3), // Reduced offset
        blurRadius: 6, // Reduced blur
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.4), // Reduced opacity
        offset: const Offset(3, 3), // Reduced offset
        blurRadius: 6, // Reduced blur
      ),
    ],
  );
  
  // Helper for Done state (Colored Concave)
  static BoxDecoration neumorphicDone(Color baseColor) {
    return BoxDecoration(
      color: baseColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: 0,
          blurStyle: BlurStyle.inner, // Inner shadow support!
        ),
      ],
    );
  }
}
