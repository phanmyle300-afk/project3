import 'category.dart';

class TransactionModel {
  final int? id;
  final String merchantName;
  final double amount;
  final DateTime date;
  final ExpenseCategory category;
  final String? imagePath;
  final String? note;
  final DateTime createdAt;

  TransactionModel({
    this.id,
    required this.merchantName,
    required this.amount,
    required this.date,
    required this.category,
    this.imagePath,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant_name': merchantName,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category.name,
      'image_path': imagePath,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      merchantName: map['merchant_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: ExpenseCategoryExtension.fromString(map['category'] as String),
      imagePath: map['image_path'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  TransactionModel copyWith({
    int? id,
    String? merchantName,
    double? amount,
    DateTime? date,
    ExpenseCategory? category,
    String? imagePath,
    String? note,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
