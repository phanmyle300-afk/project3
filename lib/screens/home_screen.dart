import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import 'scan_receipt_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  ExpenseCategory? _selectedCategoryFilter;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getAllTransactions();
    if (mounted) {
      setState(() {
        _allTransactions = list;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        final matchesCategory = (_selectedCategoryFilter == null || tx.category == _selectedCategoryFilter);
        final matchesSearch = _searchQuery.isEmpty ||
            tx.merchantName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (tx.note != null && tx.note!.toLowerCase().contains(_searchQuery.toLowerCase()));
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _deleteTransaction(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa giao dịch'), backgroundColor: Colors.orange),
    );
    _loadTransactions();
  }

  void _showImageModal(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalMonthSpent = _allTransactions.fold(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      backgroundColor: const Color(0xFF12121D),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.receipt_rounded, color: Color(0xFF6C5CE7)),
            SizedBox(width: 10),
            Text('Receipt OCR Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFF00E676)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              color: const Color(0xFF6C5CE7),
              child: CustomScrollView(
                slivers: [
                  // Top Summary Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1E2C), Color(0xFF2A2A3D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng chi tiêu hóa đơn',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(totalMonthSpent),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C5CE7).withOpacity(0.2),
                                foregroundColor: const Color(0xFF6C5CE7),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.pie_chart_rounded, size: 18),
                              label: const Text('Biểu đồ Canvas'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.horizontal(16.0),
                      child: TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _applyFilters();
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm cửa hàng, ghi chú...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6C5CE7)),
                          filled: true,
                          fillColor: const Color(0xFF1E1E2C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Category Filter Horizontal Chips
                  SliverToBoxAdapter(
                    child: Container(
                      height: 54,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.horizontal(16),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: const Text('Tất cả'),
                              selected: _selectedCategoryFilter == null,
                              selectedColor: const Color(0xFF6C5CE7),
                              backgroundColor: const Color(0xFF1E1E2C),
                              labelStyle: TextStyle(
                                color: _selectedCategoryFilter == null ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedCategoryFilter = null);
                                _applyFilters();
                              },
                            ),
                          ),
                          ...ExpenseCategory.values.map((cat) {
                            final isSelected = (_selectedCategoryFilter == cat);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                                label: Text(cat.nameVi),
                                selected: isSelected,
                                selectedColor: cat.color,
                                backgroundColor: const Color(0xFF1E1E2C),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (sel) {
                                  setState(() => _selectedCategoryFilter = sel ? cat : null);
                                  _applyFilters();
                                },
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Header section label
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LỊCH SỬ GIAO DỊCH (${_filteredTransactions.length})',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Vuốt trái để xóa',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Transaction List View
                  _filteredTransactions.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Chưa có hóa đơn nào phù hợp',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tx = _filteredTransactions[index];
                              return Dismissible(
                                key: Key('tx_${tx.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red.shade900,
                                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                                ),
                                onDismissed: (_) {
                                  if (tx.id != null) _deleteTransaction(tx.id!);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E2C),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: tx.category.color.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(tx.category.icon, color: tx.category.color),
                                    ),
                                    title: Text(
                                      tx.merchantName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('dd/MM/yyyy').format(tx.date)}${tx.note != null ? " • ${tx.note}" : ""}',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '-${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(tx.amount)}',
                                          style: const TextStyle(
                                            color: Color(0xFFFF5252),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (tx.imagePath != null && File(tx.imagePath!).existsSync())
                                          GestureDetector(
                                            onTap: () => _showImageModal(tx.imagePath!),
                                            child: const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Xem ảnh',
                                                style: TextStyle(
                                                  color: Color(0xFF6C5CE7),
                                                  fontSize: 11,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _filteredTransactions.length,
                          ),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
          );
          _loadTransactions();
        },
        backgroundColor: const Color(0xFF6C5CE7),
        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        label: const Text(
          'QUÉT HÓA ĐƠN OCR',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
