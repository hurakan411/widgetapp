import 'package:flutter/material.dart';
import '../constants/design.dart';
import 'package:lottie/lottie.dart';

class BackgroundPattern extends StatefulWidget {
  final Widget child;

  const BackgroundPattern({Key? key, required this.child}) : super(key: key);

  @override
  State<BackgroundPattern> createState() => _BackgroundPatternState();
}

class _BackgroundPatternState extends State<BackgroundPattern> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        
        // Lottie Background
        Positioned.fill(
          child: Opacity(
            opacity: 0.15, // Made lighter (0.5 -> 0.15)
            child: Lottie.asset(
              'lib/assets/flutter/space_areal.json',
              fit: BoxFit.cover,
              controller: _controller,
              onLoaded: (composition) {
                // Restore original speed
                _controller.duration = composition.duration;
                _controller.repeat();
              },
            ),
          ),
        ),
        
        // Dot Pattern
        CustomPaint(
          painter: DotPatternPainter(),
          size: Size.infinite,
        ),
        
        // Content
        widget.child,
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
