import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipt_expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Cross-platform SQLite initialization for Desktop & Windows
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Table 1: Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_name TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Table 2: Monthly Budgets
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_year TEXT UNIQUE NOT NULL,
        limit_amount REAL NOT NULL
      )
    ''');

    // Insert Default Budget (e.g. 5,000,000đ per month for club/student)
    final currentMonthYear = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    await db.insert('budgets', {
      'month_year': currentMonthYear,
      'limit_amount': 5000000.0,
    });

    // Insert sample realistic transactions for quick preview
    final sampleTx = [
      TransactionModel(
        merchantName: 'Siêu thị WinMart+',
        amount: 245000,
        date: DateTime.now().subtract(const Duration(days: 0)),
        category: ExpenseCategory.food,
        note: 'Rau củ và sữa tươi',
      ),
      TransactionModel(
        merchantName: 'Highlands Coffee',
        amount: 65000,
        date: DateTime.now().subtract(const Duration(days: 1)),
        category: ExpenseCategory.food,
        note: 'Cà phê phin sữa đá',
      ),
      TransactionModel(
        merchantName: 'Nhà sách Fahasa',
        amount: 180000,
        date: DateTime.now().subtract(const Duration(days: 2)),
        category: ExpenseCategory.education,
        note: 'Sách Thuật toán & Sổ tay Dart',
      ),
      TransactionModel(
        merchantName: 'GrabBike',
        amount: 42000,
        date: DateTime.now().subtract(const Duration(days: 3)),
        category: ExpenseCategory.travel,
        note: 'Di chuyển đến trường',
      ),
      TransactionModel(
        merchantName: 'CellphoneS',
        amount: 450000,
        date: DateTime.now().subtract(const Duration(days: 5)),
        category: ExpenseCategory.equipment,
        note: 'Củ sạc Anker Fast Charge 30W',
      ),
      TransactionModel(
        merchantName: 'Rạp CGV Cinemas',
        amount: 190000,
        date: DateTime.now().subtract(const Duration(days: 6)),
        category: ExpenseCategory.entertainment,
        note: 'Vé xem phim cuối tuần',
      ),
    ];

    for (final tx in sampleTx) {
      await db.insert('transactions', tx.toMap());
    }
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          month_year TEXT UNIQUE NOT NULL,
          limit_amount REAL NOT NULL
        )
      ''');
    }
  }

  // --- TRANSACTION CRUD ---

  Future<int> insertTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return result.map((json) => TransactionModel.fromMap(json)).toList();
  }

  Future<Map<ExpenseCategory, double>> getCategoryTotals() async {
    final txs = await getAllTransactions();
    final Map<ExpenseCategory, double> totals = {};
    for (final cat in ExpenseCategory.values) {
      totals[cat] = 0.0;
    }
    for (final tx in txs) {
      totals[tx.category] = (totals[tx.category] ?? 0.0) + tx.amount;
    }
    return totals;
  }

  Future<int> updateTransaction(TransactionModel transaction) async {
    final db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- BUDGET & TARGET MANAGEMENT ---

  Future<double> getMonthlyBudgetLimit(String monthYear) async {
    final db = await instance.database;
    final result = await db.query(
      'budgets',
      where: 'month_year = ?',
      whereArgs: [monthYear],
    );
    if (result.isNotEmpty) {
      return (result.first['limit_amount'] as num).toDouble();
    }
    return 5000000.0; // Default 5M VND
  }

  Future<void> setMonthlyBudgetLimit(String monthYear, double limitAmount) async {
    final db = await instance.database;
    await db.insert(
      'budgets',
      {'month_year': monthYear, 'limit_amount': limitAmount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- DATABASE BACKUP & RESTORE (EXPORT / IMPORT JSON) ---

  Future<String> exportDatabaseToJSON() async {
    final txs = await getAllTransactions();
    final List<Map<String, dynamic>> jsonData = txs.map((t) => t.toMap()).toList();
    final String jsonString = jsonEncode(jsonData);

    final directory = await getApplicationDocumentsDirectory();
    final file = File(join(directory.path, 'expenses_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(jsonString);

    return file.path;
  }

  Future<int> importDatabaseFromJSON(String jsonString) async {
    final db = await instance.database;
    final List<dynamic> list = jsonDecode(jsonString);
    int count = 0;
    for (final item in list) {
      final tx = TransactionModel.fromMap(Map<String, dynamic>.from(item));
      await db.insert('transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      count++;
    }
    return count;
  }
}
