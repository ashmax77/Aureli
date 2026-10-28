import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

class OfflineQueueService {
  static const String _queueKey = 'aureli_offline_transaction_queue';
  static Future<void> _writeChain = Future<void>.value();

  /// Get all pending transactions
  static Future<List<Map<String, dynamic>>> getPendingTransactions() async {
    return _readQueue();
  }

  static Future<List<Map<String, dynamic>>> _readQueue() async {
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
    await _serialized(() async {
      final queue = await _readQueue();

      // Generate durable local identifiers so queued writes remain trackable after restarts.
      transaction['queueId'] ??= '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      transaction['id'] ??= -(DateTime.now().millisecondsSinceEpoch);
      transaction['isPendingOffline'] = true;
      transaction['attempts'] = 0;
      transaction['nextAttemptAt'] = DateTime.now().toUtc().toIso8601String();

      queue.add(Map<String, dynamic>.from(transaction));
      await _writeQueue(queue);
      if (kDebugMode) debugPrint("Transaction enqueued. Total pending: ${queue.length}");
    });
  }

  /// Remove a transaction from the queue (usually after successful sync)
  static Future<void> removeTransaction(int tempId) async {
    await _serialized(() async {
      final queue = await _readQueue();
      queue.removeWhere((tx) => tx['id'] == tempId);
      await _writeQueue(queue);
    });
  }

  static Future<void> recordFailure(int tempId) async {
    await _serialized(() async {
      final queue = await _readQueue();
      final index = queue.indexWhere((tx) => tx['id'] == tempId);
      if (index == -1) return;

      final item = queue[index];
      final attempts = ((item['attempts'] as num?)?.toInt() ?? 0) + 1;
      final delaySeconds = min(3600, 1 << min(attempts, 12));
      item['attempts'] = attempts;
      item['nextAttemptAt'] = DateTime.now()
          .toUtc()
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();
      await _writeQueue(queue);
    });
  }

  /// Clear the entire queue
  static Future<void> clearQueue() async {
    await _serialized(() => SecureStorageService.delete(_queueKey));
  }

  static Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await SecureStorageService.write(_queueKey, jsonEncode(queue));
  }

  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _writeChain;
    final result = previous.then((_) => operation());
    _writeChain = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }
}
