import 'package:flutter/material.dart';

class AppColors {
  // Base Background
  static const Color background = Color(0xFFE0E5EC);

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
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadowLight,
        offset: Offset(-6, -6),
        blurRadius: 12,
      ),
      BoxShadow(
        color: AppColors.shadowDark,
        offset: Offset(6, 6),
        blurRadius: 12,
      ),
    ],
  );

  // Neumorphism Decoration (Concave / 凹) - Pressed state
  static BoxDecoration neumorphicConcave = BoxDecoration(
    color: AppColors.background, // Or slightly darker if needed
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadowLight,
        offset: Offset(4, 4), // Inset effect simulation usually needs custom painting or specific package, 
                              // but standard shadow inversion works for basic feel.
                              // For true inset, we might need a library, but let's stick to standard for now.
        blurRadius: 5,
        spreadRadius: -3,
      ),
      // Inset shadows are tricky in standard Flutter BoxDecoration.
      // We will simulate "Pressed" state by removing outer shadows and changing color slightly or using a custom painter later.
      // For now, let's define a "Pressed" look that is flatter.
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
