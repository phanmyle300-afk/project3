import '../models/category.dart';
import '../models/ocr_result.dart';

/// Heuristic Regex Engine for parsing raw OCR text from receipts in offline environment.
class HeuristicReceiptParser {
  /// Entry point to process lines of text extracted from OCR.
  static ParsedReceiptResult parse(List<String> rawLines) {
    if (rawLines.isEmpty) {
      return ParsedReceiptResult(
        merchantName: 'Cửa hàng không xác định',
        totalAmount: 0.0,
        transactionDate: DateTime.now(),
        suggestedCategory: ExpenseCategory.other,
        rawTextLines: [],
        confidenceScore: 0.0,
      );
    }

    final cleanedLines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final merchantName = _extractMerchant(cleanedLines);
    final totalAmount = _extractTotalAmount(cleanedLines);
    final date = _extractDate(cleanedLines);
    final category = _determineCategory(merchantName, cleanedLines);
    final confidence = _calculateConfidence(merchantName, totalAmount, date);

    return ParsedReceiptResult(
      merchantName: merchantName,
      totalAmount: totalAmount,
      transactionDate: date,
      suggestedCategory: category,
      rawTextLines: cleanedLines,
      confidenceScore: confidence,
    );
  }

  /// Heuristic 1: Extract Merchant Name from header lines
  static String _extractMerchant(List<String> lines) {
    // List of blacklisted generic lines that aren't store names
    final ignoreKeywords = [
      'HOA DON', 'HÓA ĐƠN', 'PHIẾU THANH TOÁN', 'RECEIPT', 'VAT',
      'CỬA HÀNG', 'THU NGÂN', 'TEL', 'HOTLINE', 'MST', 'MÃ SỐ THUẾ',
      'WELCOME', 'XIN CẢM ƠN', 'THANK YOU', 'NGÀY', 'DATE', 'CÔNG TY',
      'ĐỊA CHỈ', 'ADDRESS', 'CHI NHÁNH', 'STORE'
    ];

    // Known famous merchants in Vietnam for instant regex match
    final knownMerchants = [
      RegExp(r'WINMART\+?', caseSensitive: false),
      RegExp(r'CO\.?OP\s?MART', caseSensitive: false),
      RegExp(r'CIRCLE\s?K', caseSensitive: false),
      RegExp(r'HIGHLANDS\s?COFFEE', caseSensitive: false),
      RegExp(r'PHÚC\s?LONG|PHUC\s?LONG', caseSensitive: false),
      RegExp(r'BÁCH\s?HÓA\s?XANH|BACH\s?HOA\s?XANH', caseSensitive: false),
      RegExp(r'MINISTOP', caseSensitive: false),
      RegExp(r'GS25', caseSensitive: false),
      RegExp(r'STARBUCKS', caseSensitive: false),
      RegExp(r'FAHASA', caseSensitive: false),
      RegExp(r'CELLPHONES|CELLPHONE\s?S', caseSensitive: false),
      RegExp(r'THẾ\s?GIỚI\s?DI\s?ĐỘNG|THE\s?GIOI\s?DI\s?DONG', caseSensitive: false),
      RegExp(r'GRAB|BE|GOJEK', caseSensitive: false),
      RegExp(r'SHOPEE|TIKI|LAZADA', caseSensitive: false),
      RegExp(r'CGV|LOTTE\s?CINEMA|BHD', caseSensitive: false),
    ];

    // Check header lines first for known brands
    for (int i = 0; i < lines.length && i < 6; i++) {
      final line = lines[i];
      for (final pattern in knownMerchants) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          return line.trim();
        }
      }
    }

    // Fallback: search first 4 lines for non-ignored string
    for (int i = 0; i < lines.length && i < 4; i++) {
      final upper = lines[i].toUpperCase();
      bool shouldIgnore = false;
      for (final kw in ignoreKeywords) {
        if (upper.contains(kw)) {
          shouldIgnore = true;
          break;
        }
      }
      if (!shouldIgnore && lines[i].length >= 3 && !RegExp(r'^\d+$').hasMatch(lines[i])) {
        return lines[i].trim();
      }
    }

    return 'Cửa hàng tiện lợi / Siêu thị';
  }

  /// Heuristic 2: Extract Total Amount using Regex keyword anchors and numeric parsing
  static double _extractTotalAmount(List<String> lines) {
    // 1. High priority keywords: final bill grand total
    final grandTotalKeywords = [
      'TỔNG CỘNG', 'TONG CONG', 'THÀNH TIỀN', 'THANH TIEN', 'TỔNG TIỀN',
      'CẦN THANH TOÁN', 'CAN THANH TOAN', 'TOTAL', 'SUM', 'GIÁ TRỊ', 'CỘNG TIỀN', 'T.CỘNG', 'T.CONG'
    ];

    // Low priority payment keywords
    final tenderKeywords = ['TIỀN MẶT', 'CASH', 'PAYMENT'];

    // Search high priority grand total keywords first
    for (int i = lines.length - 1; i >= 0; i--) {
      final lineUpper = lines[i].toUpperCase();
      for (final kw in grandTotalKeywords) {
        if (lineUpper.contains(kw)) {
          final amount = _parseAmountFromText(lines[i]);
          if (amount > 0) return amount;
          if (i + 1 < lines.length) {
            final nextAmount = _parseAmountFromText(lines[i + 1]);
            if (nextAmount > 0) return nextAmount;
          }
        }
      }
    }

    // Search tender keywords if no grand total keyword found
    for (int i = lines.length - 1; i >= 0; i--) {
      final lineUpper = lines[i].toUpperCase();
      for (final kw in tenderKeywords) {
        if (lineUpper.contains(kw)) {
          final amount = _parseAmountFromText(lines[i]);
          if (amount > 0) return amount;
        }
      }
    }

    // Fallback search: scan lines from bottom to top for currency figures
    // e.g., 150.000, 150,000 VND, 150000đ
    double maxFoundAmount = 0.0;
    for (int i = lines.length - 1; i >= 0; i--) {
      final val = _parseAmountFromText(lines[i]);
      if (val > maxFoundAmount && val < 50000000) { // Safety bound < 50M VND
        // Exclude phone numbers, dates, tax IDs
        if (!_isPhoneOrTaxOrDate(lines[i])) {
          maxFoundAmount = val;
        }
      }
    }

    return maxFoundAmount;
  }

  /// Helper to convert currency text strings like '150.000đ', '240,500 VND', '1.250.000' into double
  static double _parseAmountFromText(String text) {
    // Match amounts like: 150.000, 150,000, 150000, 1.250.000, 1,250,000.00
    final regex = RegExp(r'(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})?|\d+)\s*(?:VND|VNĐ|đ|D)?', caseSensitive: false);
    final matches = regex.allMatches(text);

    double highestInLine = 0.0;
    for (final match in matches) {
      String rawNum = match.group(1) ?? '';
      if (rawNum.isEmpty) continue;

      // Clean Vietnamese dots/commas format: e.g. 150.000 -> 150000
      // If contains dot as thousands separator (e.g., 150.000)
      if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(rawNum)) {
        rawNum = rawNum.replaceAll('.', '');
      } else if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(rawNum)) {
        rawNum = rawNum.replaceAll(',', '');
      } else if (rawNum.contains(',') && !rawNum.contains('.')) {
        // e.g. 150000,00 or 150,000
        if (rawNum.endsWith(',00') || rawNum.endsWith(',0')) {
          rawNum = rawNum.split(',')[0].replaceAll('.', '');
        } else {
          rawNum = rawNum.replaceAll(',', '');
        }
      } else {
        rawNum = rawNum.replaceAll(RegExp(r'[^\d.]'), '');
      }

      final parsed = double.tryParse(rawNum) ?? 0.0;
      // Realistic expense filtering
      if (parsed >= 1000 && parsed > highestInLine) {
        highestInLine = parsed;
      }
    }
    return highestInLine;
  }

  /// Check if line is likely phone number, MST tax ID or timestamp
  static bool _isPhoneOrTaxOrDate(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('mst') || lower.contains('tel') || lower.contains('dt') || lower.contains('hotline')) return true;
    if (RegExp(r'\b(0\d{9,10})\b').hasMatch(line)) return true; // Phone number
    if (RegExp(r'\b\d{2}/\d{2}/\d{4}\b').hasMatch(line)) return true; // Date
    return false;
  }

  /// Heuristic 3: Extract Transaction Date
  static DateTime _extractDate(List<String> lines) {
    // Standard Date formats: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, DD.MM.YYYY
    final dateRegexes = [
      RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b'), // 15/05/2026
      RegExp(r'\b(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})\b'), // 2026/05/15
      RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2})\b'),   // 15/05/26
    ];

    for (final line in lines) {
      for (final regex in dateRegexes) {
        final match = regex.firstMatch(line);
        if (match != null) {
          try {
            int year, month, day;
            if (match.group(1)!.length == 4) {
              year = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              day = int.parse(match.group(3)!);
            } else {
              day = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              String yStr = match.group(3)!;
              year = yStr.length == 2 ? 2000 + int.parse(yStr) : int.parse(yStr);
            }

            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              return DateTime(year, month, day);
            }
          } catch (_) {
            // fallback to next
          }
        }
      }
    }
    return DateTime.now();
  }

  /// Heuristic 4: Determine category based on Merchant and Text Content
  static ExpenseCategory _determineCategory(String merchant, List<String> lines) {
    final fullContent = ([merchant, ...lines]).join(' ').toLowerCase();

    if (fullContent.contains('winmart') ||
        fullContent.contains('coopmart') ||
        fullContent.contains('circle k') ||
        fullContent.contains('highlands') ||
        fullContent.contains('phúc long') ||
        fullContent.contains('cà phê') ||
        fullContent.contains('trà sữa') ||
        fullContent.contains('bánh') ||
        fullContent.contains('cơm') ||
        fullContent.contains('bách hóa') ||
        fullContent.contains('starbucks') ||
        fullContent.contains('ăn uống')) {
      return ExpenseCategory.food;
    }

    if (fullContent.contains('fahasa') ||
        fullContent.contains('sách') ||
        fullContent.contains('văn phòng phẩm') ||
        fullContent.contains('bút') ||
        fullContent.contains('tập') ||
        fullContent.contains('trường') ||
        fullContent.contains('học phí') ||
        fullContent.contains('khóa học')) {
      return ExpenseCategory.education;
    }

    if (fullContent.contains('grab') ||
        fullContent.contains('be') ||
        fullContent.contains('gojek') ||
        fullContent.contains('xăng') ||
        fullContent.contains('vé xe') ||
        fullContent.contains('xe máy') ||
        fullContent.contains('taxi') ||
        fullContent.contains('bãi xe') ||
        fullContent.contains('vé máy bay')) {
      return ExpenseCategory.travel;
    }

    if (fullContent.contains('cellphones') ||
        fullContent.contains('thế giới di động') ||
        fullContent.contains('fpt shop') ||
        fullContent.contains('tai nghe') ||
        fullContent.contains('sạc') ||
        fullContent.contains('chuột') ||
        fullContent.contains('bàn phím') ||
        fullContent.contains('laptop') ||
        fullContent.contains('điện thoại')) {
      return ExpenseCategory.equipment;
    }

    if (fullContent.contains('cgv') ||
        fullContent.contains('lotte cinema') ||
        fullContent.contains('bhd') ||
        fullContent.contains('vé xem phim') ||
        fullContent.contains('bida') ||
        fullContent.contains('game') ||
        fullContent.contains('bowling')) {
      return ExpenseCategory.entertainment;
    }

    return ExpenseCategory.other;
  }

  /// Calculate overall extraction confidence
  static double _calculateConfidence(String merchant, double totalAmount, DateTime date) {
    double score = 0.4;
    if (merchant != 'Cửa hàng không xác định') score += 0.25;
    if (totalAmount > 0) score += 0.25;
    if (date.isBefore(DateTime.now().add(const Duration(days: 1)))) score += 0.1;
    return score.clamp(0.0, 1.0);
  }
}
