import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_tracker/models/category.dart';
import 'package:smart_receipt_tracker/services/heuristic_parser.dart';

void main() {
  group('HeuristicReceiptParser Tests', () {
    test('Should parse WinMart receipt with amount, date, and category correctly', () {
      final sampleLines = [
        'SIÊU THỊ WINMART+ NGUYỄN VĂN CỪ',
        'Địa chỉ: 123 Nguyễn Văn Cừ, Q.5',
        'Ngày: 15/05/2026 14:30',
        '1. Sữa tươi Vinamilk 1L - 38.000',
        '2. Bánh mì Sandwich - 22.000',
        'TỔNG CỘNG: 60.000 VNĐ',
        'TIỀN MẶT: 100.000',
        'TIỀN THỪA: 40.000',
      ];

      final result = HeuristicReceiptParser.parse(sampleLines);

      expect(result.merchantName, contains('WINMART'));
      expect(result.totalAmount, equals(60000.0));
      expect(result.transactionDate.day, equals(15));
      expect(result.transactionDate.month, equals(5));
      expect(result.transactionDate.year, equals(2026));
      expect(result.suggestedCategory, equals(ExpenseCategory.food));
    });

    test('Should parse Highlands Coffee receipt with total amount format', () {
      final sampleLines = [
        'HIGHLANDS COFFEE',
        'Mã HD: HD98821',
        'Date: 2026/06/20',
        'Phin Sữa Đá L - 49.000đ',
        'Bánh Mì Thịt Nướng - 35.000đ',
        'THÀNH TIỀN: 84.000',
        'CẢM ƠN QUÝ KHÁCH',
      ];

      final result = HeuristicReceiptParser.parse(sampleLines);

      expect(result.merchantName, contains('HIGHLANDS COFFEE'));
      expect(result.totalAmount, equals(84000.0));
      expect(result.suggestedCategory, equals(ExpenseCategory.food));
    });

    test('Should parse Fahasa bookstore receipt as Education category', () {
      final sampleLines = [
        'NHÀ SÁCH FAHASA NGUYỄN HUỆ',
        'MST: 0300441239',
        'Ngày lập: 10/04/2026',
        'Sách Flutter for Beginners - 185.000',
        'Bút chì 2B - 15.000',
        'TỔNG TIỀN: 200.000đ',
      ];

      final result = HeuristicReceiptParser.parse(sampleLines);

      expect(result.merchantName, contains('FAHASA'));
      expect(result.totalAmount, equals(200000.0));
      expect(result.suggestedCategory, equals(ExpenseCategory.education));
    });
  });
}
