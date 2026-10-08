import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyBarChartData {
  final String dayLabel; // T2, T3, T4, T5, T6, T7, CN
  final double amount;
  final DateTime date;

  WeeklyBarChartData({
    required this.dayLabel,
    required this.amount,
    required this.date,
  });
}

class CustomWeeklyBarChart extends StatefulWidget {
  final List<WeeklyBarChartData> weeklyData;
  final double height;

  const CustomWeeklyBarChart({
    super.key,
    required this.weeklyData,
    this.height = 220,
  });

  @override
  State<CustomWeeklyBarChart> createState() => _CustomWeeklyBarChartState();
}

class _CustomWeeklyBarChartState extends State<CustomWeeklyBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final Offset local = details.localPosition;
              final double width = box.size.width;
              final double chartWidth = width - 40; // margin left/right
              final double step = chartWidth / widget.weeklyData.length;

              final int index = ((local.dx - 20) / step).floor();
              if (index >= 0 && index < widget.weeklyData.length) {
                setState(() {
                  _hoveredIndex = (_hoveredIndex == index) ? null : index;
                });
              }
            },
            child: CustomPaint(
              size: Size(double.infinity, widget.height),
              painter: WeeklyBarChartPainter(
                data: widget.weeklyData,
                progress: _animation.value,
                selectedIndex: _hoveredIndex,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WeeklyBarChartPainter extends CustomPainter {
  final List<WeeklyBarChartData> data;
  final double progress;
  final int? selectedIndex;

  WeeklyBarChartPainter({
    required this.data,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double leftMargin = 32.0;
    const double rightMargin = 16.0;
    const double topMargin = 30.0;
    const double bottomMargin = 30.0;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - topMargin - bottomMargin;

    // Find max value for dynamic scaling
    double maxAmount = data.map((e) => e.amount).fold(0, max);
    if (maxAmount <= 0) maxAmount = 100000;

    // Draw horizontal dashed grid lines & Y-axis labels
    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 3; i++) {
      final double yRatio = i / 3;
      final double y = topMargin + chartHeight * (1 - yRatio);

      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      final double value = maxAmount * yRatio;
      final String label = (value >= 1000000)
          ? '${(value / 1000000).toStringAsFixed(1)}M'
          : (value >= 1000)
              ? '${(value / 1000).toStringAsFixed(0)}K'
              : '0';

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftMargin - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Draw bars & X-axis labels
    final double barGap = chartWidth / data.length;
    final double barWidth = min(barGap * 0.45, 24.0);

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final double centerX = leftMargin + (i + 0.5) * barGap;
      final double barHeight = (item.amount / maxAmount) * chartHeight * progress;
      final double topY = topMargin + chartHeight - barHeight;
      final bool isSelected = (selectedIndex == i);

      final Rect barRect = Rect.fromLTWH(
        centerX - barWidth / 2,
        topY,
        barWidth,
        max(barHeight, 4.0),
      );

      final RRect roundedBar = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      // Gradient Paint
      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isSelected
              ? [const Color(0xFFFF5252), const Color(0xFFFF7A00)]
              : [const Color(0xFF6C5CE7), const Color(0xFF00CEC9)],
        ).createShader(barRect);

      if (isSelected) {
        barPaint.shadowColor = const Color(0xFFFF5252).withOpacity(0.8);
        barPaint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
      }

      // Draw Bar
      canvas.drawRRect(roundedBar, barPaint);

      // Draw X-axis Day Label
      textPainter.text = TextSpan(
        text: item.dayLabel,
        style: TextStyle(
          color: isSelected ? const Color(0xFFFF5252) : Colors.grey.shade400,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, size.height - bottomMargin + 8),
      );

      // Draw interactive tooltip when selected
      if (isSelected) {
        final String tooltipText = NumberFormat.compact(locale: 'vi_VN').format(item.amount);
        textPainter.text = TextSpan(
          text: tooltipText,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        );
        textPainter.layout();

        final double bubbleWidth = textPainter.width + 12;
        final double bubbleHeight = textPainter.height + 8;
        final Rect bubbleRect = Rect.fromCenter(
          center: Offset(centerX, max(topY - 14, 12)),
          width: bubbleWidth,
          height: bubbleHeight,
        );

        final Paint bubblePaint = Paint()..color = const Color(0xFFFF5252);
        canvas.drawRRect(RRect.fromRectAndRadius(bubbleRect, const Radius.circular(4)), bubblePaint);
        textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, bubbleRect.top + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyBarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.data != data;
  }
}
