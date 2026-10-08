import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';

class CustomPieChart extends StatefulWidget {
  final Map<ExpenseCategory, double> data;
  final double height;
  final Function(ExpenseCategory?)? onCategorySelected;

  const CustomPieChart({
    super.key,
    required this.data,
    this.height = 260,
    this.onCategorySelected,
  });

  @override
  State<CustomPieChart> createState() => _CustomPieChartState();
}

class _CustomPieChartState extends State<CustomPieChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  ExpenseCategory? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double total = widget.data.values.fold(0, (sum, val) => sum + val);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTapUp: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localOffset = details.localPosition;
                  final Size size = box.size;
                  final Offset center = Offset(size.width / 2, size.height / 2);

                  final dx = localOffset.dx - center.dx;
                  final dy = localOffset.dy - center.dy;
                  final double distance = sqrt(dx * dx + dy * dy);
                  final double radius = min(size.width, size.height) / 2 * 0.85;
                  final double innerRadius = radius * 0.55;

                  if (distance >= innerRadius && distance <= radius) {
                    double angle = atan2(dy, dx);
                    if (angle < -pi / 2) {
                      angle += 2 * pi;
                    }
                    angle += pi / 2; // Normalize start angle from top (-pi/2)

                    double startAngle = 0;
                    for (final entry in widget.data.entries) {
                      if (entry.value <= 0) continue;
                      final sweepAngle = (entry.value / (total > 0 ? total : 1)) * 2 * pi;
                      if (angle >= startAngle && angle <= startAngle + sweepAngle) {
                        setState(() {
                          _selectedIndex = (_selectedIndex == entry.key) ? null : entry.key;
                        });
                        widget.onCategorySelected?.call(_selectedIndex);
                        break;
                      }
                      startAngle += sweepAngle;
                    }
                  } else {
                    setState(() {
                      _selectedIndex = null;
                    });
                    widget.onCategorySelected?.call(null);
                  }
                },
                child: CustomPaint(
                  size: Size(widget.height, widget.height),
                  painter: DonutChartPainter(
                    data: widget.data,
                    total: total,
                    progress: _animation.value,
                    selectedCategory: _selectedIndex,
                  ),
                ),
              ),

              // Center text inside donut hole
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedIndex != null ? _selectedIndex!.nameVi : 'Tổng chi tiêu',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(
                      _selectedIndex != null ? (widget.data[_selectedIndex] ?? 0) : total,
                    ),
                    style: TextStyle(
                      fontSize: _selectedIndex != null ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: _selectedIndex != null ? _selectedIndex!.color : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<ExpenseCategory, double> data;
  final double total;
  final double progress;
  final ExpenseCategory? selectedCategory;

  DonutChartPainter({
    required this.data,
    required this.total,
    required this.progress,
    this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) {
      final paint = Paint()
        :color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24.0;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 20, paint);
      return;
    }

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = min(size.width, size.height) / 2 - 16;
    final double strokeWidth = 32.0;
    final Rect rect = Rect.fromCircle(center: center, radius: outerRadius);

    double startAngle = -pi / 2; // Start from top (12 o'clock)

    for (final entry in data.entries) {
      final double value = entry.value;
      if (value <= 0) continue;

      final double sweepAngle = (value / total) * 2 * pi * progress;
      final bool isSelected = (selectedCategory == entry.key);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 8 : strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = entry.key.color;

      if (isSelected) {
        paint.shadowColor = entry.key.color.withOpacity(0.8);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
      }

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      // Separator white thin stroke
      final separatorPaint = Paint()
        ..color = const Color(0xFF1E1E2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, 0.02, false, separatorPaint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.data != data;
  }
}
