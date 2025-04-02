import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A utility class for creating subtle background patterns for the app
class BackgroundPatterns {
  /// Creates a light theme background with subtle geometric patterns
  static Widget lightThemeBackground({Widget? child}) {
    return Stack(
      children: [
        // Base gradient background for light mode
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF9F9FB), Color(0xFFE3E6EF)],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        
        // Programmatic geometric pattern overlay
        CustomPaint(
          painter: LightGeometricPatternPainter(),
          size: Size.infinite,
        ),
        
        // Subtle gradient overlay for depth
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withOpacity(0.2), Colors.transparent, Colors.white.withOpacity(0.1)],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Child content
        if (child != null) child,
      ],
    );
  }

  /// Creates a dark theme background with subtle geometric patterns
  static Widget darkThemeBackground({Widget? child}) {
    return Stack(
      children: [
        // Base gradient background for dark mode
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1E2E), Color(0xFF25273D)],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        
        // Programmatic geometric pattern overlay
        CustomPaint(
          painter: DarkGeometricPatternPainter(),
          size: Size.infinite,
        ),
        
        // Subtle gradient overlay for depth
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15), 
                Colors.transparent, 
                Colors.black.withOpacity(0.2)
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Child content
        if (child != null) child,
      ],
    );
  }

  static Widget waterBubbleBackground({Color? color}) {
    return CustomPaint(
      painter: WaterBubblePainter(color: color ?? Colors.blue.withOpacity(0.05)),
      size: Size.infinite,
    );
  }
}

/// Custom painter for light theme geometric pattern
class LightGeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // Using a fixed seed for consistent pattern
    
    // Draw light blue geometric shapes (rounded rectangles) similar to example
    final lightBluePaint = Paint()
      ..color = const Color(0xFF84CDF8).withOpacity(0.15) // Light blue with opacity
      ..style = PaintingStyle.fill;
      
    final paleAquaPaint = Paint()
      ..color = const Color(0xFFAEE4F8).withOpacity(0.15) // Pale aqua with opacity
      ..style = PaintingStyle.fill;
    
    final whitePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
      
    // Calculate grid dimensions
    final cellSize = size.width / 12; // Create a 12x24 grid approximately
    
    for (int i = -4; i < 16; i++) {
      for (int j = -4; j < 24; j++) {
        // Skip some cells randomly
        if (rng.nextDouble() > 0.4) continue;
        
        // Calculate cell center
        final centerX = i * cellSize;
        final centerY = j * cellSize;
        
        // Choose shape size
        final shapeSize = cellSize * (0.4 + rng.nextDouble() * 0.6);
        final halfSize = shapeSize / 2;
        
        // Choose shape paint based on position
        final paint = rng.nextDouble() > 0.7 
          ? whitePaint 
          : (rng.nextDouble() > 0.5 ? lightBluePaint : paleAquaPaint);
        
        // Apply slight rotation for some shapes
        canvas.save();
        canvas.translate(centerX, centerY);
        canvas.rotate(rng.nextDouble() * 0.2);
        
        // Draw rounded rectangle shape instead of diamond
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: shapeSize,
          height: shapeSize,
        );
        
        // Rounded corners radius (make corners more rounded for some shapes)
        final cornerRadius = rng.nextDouble() > 0.5 
            ? shapeSize / 4  // More rounded
            : shapeSize / 8; // Less rounded
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
          paint
        );
        
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for dark theme geometric pattern
class DarkGeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // Using a fixed seed for consistent pattern
    
    // Draw dark blue geometric shapes (rounded rectangles)
    final darkBluePaint = Paint()
      ..color = const Color(0xFF5C8CB0).withOpacity(0.13) // Dark blue with opacity
      ..style = PaintingStyle.fill;
      
    final deepBluePaint = Paint()
      ..color = const Color(0xFF4371A8).withOpacity(0.13) // Deep blue with opacity
      ..style = PaintingStyle.fill;
    
    final accentPaint = Paint()
      ..color = const Color(0xFF6C5CE7).withOpacity(0.1) // Brand purple with low opacity
      ..style = PaintingStyle.fill;
      
    // Calculate grid dimensions
    final cellSize = size.width / 12; // Create a 12x24 grid approximately
    
    for (int i = -4; i < 16; i++) {
      for (int j = -4; j < 24; j++) {
        // Skip some cells randomly
        if (rng.nextDouble() > 0.4) continue;
        
        // Calculate cell center
        final centerX = i * cellSize;
        final centerY = j * cellSize;
        
        // Choose shape size
        final shapeSize = cellSize * (0.4 + rng.nextDouble() * 0.6);
        
        // Choose shape paint based on position
        final paint = rng.nextDouble() > 0.8
          ? accentPaint 
          : (rng.nextDouble() > 0.5 ? darkBluePaint : deepBluePaint);
        
        // Apply slight rotation for some shapes
        canvas.save();
        canvas.translate(centerX, centerY);
        canvas.rotate(rng.nextDouble() * 0.2);
        
        // Draw rounded rectangle shape instead of diamond
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: shapeSize,
          height: shapeSize,
        );
        
        // Rounded corners radius (make corners more rounded for some shapes)
        final cornerRadius = rng.nextDouble() > 0.5 
            ? shapeSize / 4  // More rounded
            : shapeSize / 8; // Less rounded
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
          paint
        );
        
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaterBubblePainter extends CustomPainter {
  final Color color;
  final math.Random random = math.Random(42); // Fixed seed for consistent pattern

  WaterBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bubbles = 12; // Fewer bubbles
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0); // Add blur for softer edges

    for (var i = 0; i < bubbles; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 20 + 5; // Smaller bubbles between 5-25px

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(WaterBubblePainter oldDelegate) => false;
} 