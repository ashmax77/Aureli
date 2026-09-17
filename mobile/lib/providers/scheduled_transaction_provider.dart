import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/scheduled_transaction_model.dart';
import '../services/api_service.dart';

class ScheduledTransactionProvider with ChangeNotifier {
  final ApiService _apiService;

  List<ScheduledTransactionModel> _scheduledTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ScheduledTransactionModel> get scheduledTransactions => _scheduledTransactions;

  List<ScheduledTransactionModel> get pendingScheduledTransactions =>
      _scheduledTransactions.where((t) => t.status == ScheduledStatus.PENDING).toList();

  List<ScheduledTransactionModel> get paidScheduledTransactions =>
      _scheduledTransactions.where((t) => t.status == ScheduledStatus.PAID).toList();

  int get upcomingCount => pendingScheduledTransactions.length;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ScheduledTransactionProvider(this._apiService);

  Future<void> fetchScheduledTransactions({bool force = false}) async {
    if (!force && _scheduledTransactions.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/scheduled-transactions');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _scheduledTransactions = data
            .map((item) => ScheduledTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
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
