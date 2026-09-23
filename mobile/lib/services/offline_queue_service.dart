import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

class OfflineQueueService {
  static const String _queueKey = 'aureli_offline_transaction_queue';

  /// Get all pending transactions
  static Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    final String? data = await SecureStorageService.read(_queueKey);
    if (data == null || data.isEmpty) return [];
    try {
      final List decoded = jsonDecode(data) as List;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) debugPrint("Error decoding offline queue: $e");
      return [];
    }
  }

  /// Add a transaction to the offline queue
  static Future<void> enqueueTransaction(Map<String, dynamic> transaction) async {
    final queue = await getPendingTransactions();
    
    // Generate a temporary negative ID so we can track it in the UI and avoid duplicates
    if (!transaction.containsKey('id') || transaction['id'] == null) {
      transaction['id'] = -(DateTime.now().millisecondsSinceEpoch);
    }
    transaction['isPendingOffline'] = true;
    
    queue.add(transaction);
    await SecureStorageService.write(_queueKey, jsonEncode(queue));
    if (kDebugMode) debugPrint("Transaction enqueued. Total pending: ${queue.length}");
  }

  /// Remove a transaction from the queue (usually after successful sync)
  static Future<void> removeTransaction(int tempId) async {
    final queue = await getPendingTransactions();
    queue.removeWhere((tx) => tx['id'] == tempId);
    await SecureStorageService.write(_queueKey, jsonEncode(queue));
  }

  /// Clear the entire queue
  static Future<void> clearQueue() async {
    await SecureStorageService.delete(_queueKey);
  }
}
