import 'package:flutter/material.dart';
import '../constants/design.dart';

class BackgroundPattern extends StatelessWidget {
  final Widget child;

  const BackgroundPattern({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF5F0F2), // Slightly lighter (Top-Left source)
                AppColors.background, // Base color
                Color(0xFFDBD5D7), // Slightly darker (Bottom-Right shadow)
              ],
            ),
          ),
        ),
        
        // Dot Pattern
        CustomPaint(
          painter: DotPatternPainter(),
          size: Size.infinite,
        ),
        
        // Content
        child,
      ],
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.vintageNavy.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    const double spacing = 20.0;
    const double radius = 1.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        // Offset every other row for a honeycomb-like pattern
        double offsetX = (y / spacing).floor() % 2 == 0 ? 0 : spacing / 2;
        canvas.drawCircle(Offset(x + offsetX, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
