import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/ocr_result.dart';
import '../models/transaction_model.dart';
import '../services/database_helper.dart';
import '../services/receipt_storage_service.dart';

class ReviewReceiptScreen extends StatefulWidget {
  final ParsedReceiptResult parsedResult;
  final File? originalImage;

  const ReviewReceiptScreen({
    super.key,
    required this.parsedResult,
    this.originalImage,
  });

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  late DateTime _selectedDate;
  late ExpenseCategory _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.parsedResult.merchantName);
    _amountController = TextEditingController(
      text: widget.parsedResult.totalAmount > 0
          ? widget.parsedResult.totalAmount.toStringAsFixed(0)
          : '',
    );
    _noteController = TextEditingController();
    _selectedDate = widget.parsedResult.transactionDate;
    _selectedCategory = widget.parsedResult.suggestedCategory;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? savedImagePath;
      if (widget.originalImage != null) {
        savedImagePath = await ReceiptStorageService.saveReceiptImage(widget.originalImage!);
      }

      final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

      final newTx = TransactionModel(
        merchantName: _merchantController.text.trim(),
        amount: amount,
        date: _selectedDate,
        category: _selectedCategory,
        imagePath: savedImagePath,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      await DatabaseHelper.instance.insertTransaction(newTx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu hóa đơn vào nhật ký chi tiêu!'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121D),
      appBar: AppBar(
        title: const Text('Xác nhận & Chỉnh sửa'),
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image & Confidence Banner
              if (widget.originalImage != null)
                Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                    image: DecorationImage(
                      image: FileImage(widget.originalImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ảnh hóa đơn đã quét',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Độ tin cậy OCR: ${(widget.parsedResult.confidenceScore * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Merchant Name Field
              Text(
                'NƠI BÁN / THƯƠNG HIỆU',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _merchantController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: _inputDecoration(
                  hint: 'Nhập tên cửa hàng...',
                  prefixIcon: Icons.storefront_rounded,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Vui lòng nhập tên nơi bán' : null,
              ),
              const SizedBox(height: 20),

              // Amount Field
              Text(
                'TỔNG SỐ TIỀN (VND)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF00E676), fontSize: 22, fontWeight: FontWeight.bold),
                decoration: _inputDecoration(
                  hint: '0',
                  prefixIcon: Icons.attach_money_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số tiền';
                  final num = double.tryParse(val.replaceAll(RegExp(r'[^\d.]'), ''));
                  if (num == null || num <= 0) return 'Số tiền phải lớn hơn 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Date Picker Field
              Text(
                'NGÀY GIAO DỊCH',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Color(0xFF6C5CE7)),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category Picker Chips
              Text(
                'DANH MỤC CHI TIÊU',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((category) {
                  final isSelected = (_selectedCategory == category);
                  return FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Icon(category.icon, size: 18, color: isSelected ? Colors.white : category.color),
                    label: Text(category.nameVi),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade300,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    selectedColor: category.color,
                    backgroundColor: const Color(0xFF1E1E2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? category.color : Colors.white12),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Note Field
              Text(
                'GHI CHÚ (TÙY CHỌN)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hint: 'Ghi chú thêm về món đồ...',
                  prefixIcon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'ĐANG LƯU...' : 'LƯU VÀO SỔ CHI TIÊU',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF6C5CE7)),
      filled: true,
      fillColor: const Color(0xFF1E1E2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
      ),
    );
  }
}
