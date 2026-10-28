import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/scheduled_transaction_model.dart';
import '../services/api_service.dart';
import '../services/snapshot_cache_service.dart';

class ScheduledTransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _scheduledTxCacheResource = 'scheduled-transactions';
  static const Duration _cacheFreshness = Duration(minutes: 5);

  List<ScheduledTransactionModel> _scheduledTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _fetchedAt;

  List<ScheduledTransactionModel> get scheduledTransactions => _scheduledTransactions;

  List<ScheduledTransactionModel> get pendingScheduledTransactions =>
      _scheduledTransactions.where((t) => t.status == ScheduledStatus.PENDING).toList();

  List<ScheduledTransactionModel> get paidScheduledTransactions =>
      _scheduledTransactions.where((t) => t.status == ScheduledStatus.PAID).toList();

  int get upcomingCount => pendingScheduledTransactions.length;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ScheduledTransactionProvider(this._apiService) {
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      final cached = await SnapshotCacheService.read(
        userId: userId,
        resource: _scheduledTxCacheResource,
      );
      if (cached != null &&
          cached.schemaVersion == SnapshotCacheService.currentSchemaVersion) {
        final List raw = cached.data as List? ?? [];
        _scheduledTransactions = raw
            .map((e) => ScheduledTransactionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _fetchedAt = cached.savedAt;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached scheduled transactions: $e");
    }
  }

  Future<void> _saveCachedData() async {
    try {
      final userId = _apiService.currentUserId;
      if (userId == null) return;
      await SnapshotCacheService.write(
        userId: userId,
        resource: _scheduledTxCacheResource,
        data: _scheduledTransactions.map((t) => t.toJson()).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached scheduled transactions: $e");
    }
  }

  Future<void> fetchScheduledTransactions({bool force = false}) async {
    if (!force &&
        _scheduledTransactions.isNotEmpty &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _cacheFreshness) {
      return;
    }
    if (_scheduledTransactions.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      final response = await _apiService.get('/scheduled-transactions');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _scheduledTransactions = data
            .map((item) => ScheduledTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _fetchedAt = DateTime.now();
        await _saveCachedData();
      } else {
        _errorMessage = "Failed to load scheduled payments: Code ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createScheduledTransaction({
    required int categoryId,
    required String title,
    required double amount,
    required DateTime dueDate,
    required String paymentMethod,
    String? note,
    String recurringFrequency = 'ONCE',
    int reminderDaysBefore = 3,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/scheduled-transactions', {
        'categoryId': categoryId,
        'type': 'EXPENSE',
        'title': title,
        'amount': amount,
        'dueDate': dueDate.toIso8601String().split('T')[0],
        'paymentMethod': paymentMethod,
        'note': note,
        'recurringFrequency': recurringFrequency,
        'reminderDaysBefore': reminderDaysBefore,
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchScheduledTransactions(force: true);
        return true;
      } else {
        try {
          final body = json.decode(response.body);
          _errorMessage = body['message'] ?? "Failed to create scheduled payment (${response.statusCode})";
        } catch (_) {
          _errorMessage = "Failed to create scheduled payment (${response.statusCode})";
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> payScheduledTransaction(int id) async {
    try {
      final response = await _apiService.post('/scheduled-transactions/$id/pay', {});

      if (response.statusCode == 200) {
        await fetchScheduledTransactions(force: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  Future<bool> deleteScheduledTransaction(int id) async {
    try {
      final response = await _apiService.delete('/scheduled-transactions/$id');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _scheduledTransactions.removeWhere((item) => item.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }
}
