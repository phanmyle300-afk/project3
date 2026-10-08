import 'package:flutter/material.dart';

class CameraOverlayPainter extends CustomPainter {
  final double scanAnimationValue;

  CameraOverlayPainter({required this.scanAnimationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double rectWidth = size.width * 0.85;
    final double rectHeight = size.height * 0.55;
    final Offset center = Offset(size.width / 2, size.height / 2 - 20);

    final Rect cropRect = Rect.fromCenter(
      center: center,
      width: rectWidth,
      height: rectHeight,
    );

    // 1. Draw dark translucent overlay background
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // 2. Draw white crop boundary border
    final Paint borderPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)), borderPaint);

    // 3. Draw 4 bright corner brackets
    final Paint cornerPaint = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 24.0;

    // Top-Left
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Top-Right
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.topRight, cropRect.topRight + const Offset(0, cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + const Offset(0, -cornerLength), cornerPaint);

    // Bottom-Right
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight + const Offset(0, -cornerLength), cornerPaint);

    // 4. Draw laser scanning line animation
    final double scanY = cropRect.top + (cropRect.height * scanAnimationValue);
    final Paint laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6C5CE7).withOpacity(0.0),
          const Color(0xFF00E676),
          const Color(0xFF6C5CE7).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(cropRect.left, scanY, cropRect.width, 3));

    canvas.drawRect(Rect.fromLTWH(cropRect.left + 8, scanY, cropRect.width - 16, 3), laserPaint);
  }

  @override
  bool shouldRepaint(covariant CameraOverlayPainter oldDelegate) {
    return oldDelegate.scanAnimationValue != scanAnimationValue;
  }
}
