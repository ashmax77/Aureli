import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/scheduled_transaction_model.dart';
import '../services/api_service.dart';

class ScheduledTransactionProvider with ChangeNotifier {
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

  Future<void> fetchScheduledTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/scheduled-transactions');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _scheduledTransactions = data
            .map((item) => ScheduledTransactionModel.fromJson(item))
            .toList();
      } else {
        _errorMessage = "Failed to load scheduled payments";
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
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/scheduled-transactions');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'categoryId': categoryId,
          'type': 'EXPENSE',
          'title': title,
          'amount': amount,
          'dueDate': dueDate.toIso8601String().split('T')[0],
          'paymentMethod': paymentMethod,
          'note': note,
          'recurringFrequency': recurringFrequency,
          'reminderDaysBefore': reminderDaysBefore,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchScheduledTransactions();
        return true;
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
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/scheduled-transactions/$id/pay');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        await fetchScheduledTransactions();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  Future<bool> deleteScheduledTransaction(int id) async {
    try {
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/scheduled-transactions/$id');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

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
