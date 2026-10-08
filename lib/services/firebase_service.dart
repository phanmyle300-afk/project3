import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/transaction_model.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._init();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Firebase Web/App Config Parameters (Project: my-receipt-tracker-76618)
  static const String projectId = "my-receipt-tracker-76618";
  static const String storageBucket = "my-receipt-tracker-76618.firebasestorage.app";

  FirebaseService._init();

  // Collection reference in Firestore
  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection('receipt_transactions');

  /// Upload receipt image to Firebase Storage and return download URL
  Future<String?> uploadReceiptImage(File imageFile, String userId) async {
    try {
      final fileName = 'receipts/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Firebase Storage Upload Error: $e');
      return null;
    }
  }

  /// Add new transaction to Firebase Firestore
  Future<String> addTransaction(TransactionModel transaction, {String userId = 'guest_user'}) async {
    final docRef = await _transactionsCollection.add({
      ...transaction.toMap(),
      'user_id': userId,
      'synced_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Real-time stream listener for transactions from Firebase Firestore
  Stream<List<TransactionModel>> getTransactionsStream({String userId = 'guest_user'}) {
    return _transactionsCollection
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return TransactionModel.fromMap({
          ...data,
          'id': doc.id.hashCode, // Hash docId for local int id compatibility
        });
      }).toList();
    });
  }

  /// Delete transaction from Firebase Cloud Firestore
  Future<void> deleteTransaction(String firestoreDocId) async {
    await _transactionsCollection.doc(firestoreDocId).delete();
  }

  /// Sync local SQLite transactions with Cloud Firebase Firestore
  Future<void> syncLocalWithCloud(List<TransactionModel> localTxs, {String userId = 'guest_user'}) async {
    final batch = _firestore.batch();
    for (final tx in localTxs) {
      final docRef = _transactionsCollection.doc('tx_${tx.id}_${tx.createdAt.millisecondsSinceEpoch}');
      batch.set(docRef, {
        ...tx.toMap(),
        'user_id': userId,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
