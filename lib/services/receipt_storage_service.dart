import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ReceiptStorageService {
  /// Saves a receipt image into local app storage directory and returns saved absolute file path
  static Future<String> saveReceiptImage(File imageFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory(p.join(docsDir.path, 'receipts'));
    if (!await receiptDir.exists()) {
      await receiptDir.create(recursive: true);
    }

    final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = p.join(receiptDir.path, fileName);
    final savedFile = await imageFile.copy(savedPath);

    return savedFile.path;
  }
}
