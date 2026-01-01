import 'package:flutter/material.dart';
import '../constants/design.dart';

class ProgressHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress; // 0.0 to 1.0
  final Color accentColor;
  final IconData icon;

  const ProgressHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.accentColor,
    this.icon = Icons.star, // Default icon
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), // Increased margin to be smaller than task cards
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.neumorphicConvex.copyWith(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Circular Progress (Left)
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Circle (Concave)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    boxShadow: [
                      // Simulate concave
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(-3, -3),
                        blurRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.6),
                        offset: const Offset(3, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                // Animated Progress Indicator & Content
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutExpo,
                  builder: (context, value, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 11,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 28, color: accentColor.withOpacity(0.8)),
                            const SizedBox(height: 2),
                            Text(
                              "${(value * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Title & Subtitle (Right)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary.withOpacity(0.6),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
