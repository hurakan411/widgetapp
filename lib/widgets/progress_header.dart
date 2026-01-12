import 'package:flutter/material.dart';
import '../constants/design.dart';

import 'package:lottie/lottie.dart';

class ProgressHeader extends StatefulWidget {
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
  State<ProgressHeader> createState() => _ProgressHeaderState();
}

class _ProgressHeaderState extends State<ProgressHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    // Initialize to current progress
    _lottieController.value = widget.progress;
  }

  @override
  void didUpdateWidget(ProgressHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _lottieController.animateTo(widget.progress);
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                  tween: Tween<double>(begin: 0, end: widget.progress),
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
                            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(widget.icon, size: 28, color: widget.accentColor.withOpacity(0.8)),
                            const SizedBox(height: 2),
                            Text(
                              "${(value * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.accentColor,
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
          
          // Title & Subtitle (Middle)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle.toUpperCase(),
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

          // Lottie Animation (Right)
          SizedBox(
            width: 60,
            height: 60,
            child: Lottie.asset(
              'lib/assets/flutter/tree_growth.json',
              controller: _lottieController,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print("Lottie Error: $error");
                return const Icon(Icons.error, color: Colors.red);
              },
            ),
          ),
        ],
      ),
    );
  }
}
