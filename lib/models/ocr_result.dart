import 'category.dart';

class ParsedReceiptResult {
  final String merchantName;
  final double totalAmount;
  final DateTime transactionDate;
  final ExpenseCategory suggestedCategory;
  final List<String> rawTextLines;
  final double confidenceScore;

  ParsedReceiptResult({
    required this.merchantName,
    required this.totalAmount,
    required this.transactionDate,
    required this.suggestedCategory,
    required this.rawTextLines,
    this.confidenceScore = 0.85,
  });

  Map<String, dynamic> toMap() {
    return {
      'merchantName': merchantName,
      'totalAmount': totalAmount,
      'transactionDate': transactionDate.toIso8601String(),
      'suggestedCategory': suggestedCategory.name,
      'rawTextLines': rawTextLines,
      'confidenceScore': confidenceScore,
    };
  }
}
