import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../widgets/custom_pie_chart.dart';
import '../widgets/custom_bar_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<TransactionModel> _transactions = [];
  Map<ExpenseCategory, double> _categoryTotals = {};
  List<WeeklyBarChartData> _weeklyBarData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final txs = await DatabaseHelper.instance.getAllTransactions();
    final catTotals = await DatabaseHelper.instance.getCategoryTotals();

    // Prepare weekly bar chart data (last 7 days)
    final now = DateTime.now();
    final List<WeeklyBarChartData> barData = [];
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayTxs = txs.where((t) =>
        t.date.year == day.year &&
        t.date.month == day.month &&
        t.date.day == day.day
      );

      final double daySum = dayTxs.fold(0, (sum, t) => sum + t.amount);
      int weekdayIdx = day.weekday - 1; // 0 = Mon, 6 = Sun
      barData.add(WeeklyBarChartData(
        dayLabel: dayNames[weekdayIdx],
        amount: daySum,
        date: day,
      ));
    }

    if (mounted) {
      setState(() {
        _transactions = txs;
        _categoryTotals = catTotals;
        _weeklyBarData = barData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalSpent = _transactions.fold(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF12121D),
      appBar: AppBar(
        title: const Text('Phân Tích Chi Tiêu CustomPainter'),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6C5CE7),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Month Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF8E44AD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C5CE7).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TỔNG CHI TIÊU TÍCH LŨY',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(totalSpent),
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${_transactions.length} Hóa đơn đã quét & phân tích',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Donut Chart Canvas Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Phân bổ theo Danh mục',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Canvas Donut',
                                  style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CustomPieChart(data: _categoryTotals),
                          const SizedBox(height: 16),
                          // Category Legend List
                          Column(
                            children: ExpenseCategory.values.map((cat) {
                              final amount = _categoryTotals[cat] ?? 0.0;
                              final percentage = totalSpent > 0 ? (amount / totalSpent * 100) : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(cat.nameVi, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    const Spacer(),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      NumberFormat.compact(locale: 'vi_VN').format(amount),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Weekly Bar Chart Canvas Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Chi tiêu 7 ngày qua',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Canvas Bar Chart',
                                  style: TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CustomWeeklyBarChart(weeklyData: _weeklyBarData),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
