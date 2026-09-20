import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class DebtProvider with ChangeNotifier {
  final ApiService _apiService;

  static const String _debtSummaryCacheKey = 'aureli_cached_debt_summary';

  DebtSummaryModel? _summary;
  List<DebtRecordModel> _debts = [];
  bool _isLoading = false;
  String? _errorMessage;

  DebtSummaryModel? get summary => _summary;
  List<DebtRecordModel> get debts => _debts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<DebtRecordModel> get lentDebts =>
      _debts.where((d) => d.type == DebtType.LENT).toList();

  List<DebtRecordModel> get borrowedDebts =>
      _debts.where((d) => d.type == DebtType.BORROWED).toList();

  DebtProvider(this._apiService) {
    _loadCachedSummary();
  }

  Future<void> _loadCachedSummary() async {
    try {
      final cached = await SecureStorageService.read(_debtSummaryCacheKey);
      if (cached != null) {
        _summary = DebtSummaryModel.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached debt summary: $e");
    }
  }

  Future<void> _saveCachedSummary(DebtSummaryModel summary) async {
    try {
      await SecureStorageService.write(_debtSummaryCacheKey, jsonEncode(summary.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached debt summary: $e");
    }
  }

  Future<void> fetchSummary() async {
    try {
      final response = await _apiService.get('/debts/summary');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _summary = DebtSummaryModel.fromJson(data);
        _errorMessage = null;
        await _saveCachedSummary(_summary!);
      } else {
        _errorMessage = "Failed to fetch debt summary: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error fetching debt summary: $e";
    }
    notifyListeners();
  }

  Future<void> fetchDebts({DebtType? type, DebtStatus? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String query = '';
      final params = <String>[];
      if (type != null) {
        params.add('type=${type.name}');
      }
      if (status != null) {
        params.add('status=${status.name}');
      }
      if (params.isNotEmpty) {
        query = '?${params.join('&')}';
      }

      final response = await _apiService.get('/debts$query');
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body) as List;
        _debts = list.map((item) => DebtRecordModel.fromJson(item as Map<String, dynamic>)).toList();
        _errorMessage = null;
      } else {
        _errorMessage = "Failed to load debts: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error fetching debts: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createDebt({
    required DebtType type,
    required String counterpartyName,
    String? counterpartyContact,
    required double principalAmount,
    double? interestRate,
    required DateTime startDate,
    DateTime? dueDate,
    int reminderDaysBefore = 3,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'type': type.name,
        'counterpartyName': counterpartyName,
        'counterpartyContact': counterpartyContact,
        'principalAmount': principalAmount,
        'interestRate': interestRate,
        'startDate': startDate.toIso8601String().split('T').first,
        'dueDate': dueDate?.toIso8601String().split('T').first,
        'reminderDaysBefore': reminderDaysBefore,
        'note': note,
      };

      final response = await _apiService.post('/debts', body);
      if (response.statusCode == 201) {
        await fetchSummary();
        await fetchDebts();
        return true;
      } else {
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          _errorMessage = errBody['message'] ?? "Failed to create debt";
        } catch (_) {
          _errorMessage = "Failed to create debt: ${response.statusCode}";
        }
      }
    } catch (e) {
      _errorMessage = "Network error creating debt: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> recordRepayment({
    required int debtId,
    required double amount,
    required DateTime repaymentDate,
    required PaymentMethod paymentMethod,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final body = {
        'amount': amount,
        'repaymentDate': repaymentDate.toIso8601String().split('T').first,
        'paymentMethod': paymentMethod.name,
        'note': note,
      };

      final response = await _apiService.post('/debts/$debtId/repayments', body);
      if (response.statusCode == 200) {
        await fetchSummary();
        await fetchDebts();
        return true;
      } else {
        try {
          final errBody = jsonDecode(response.body) as Map<String, dynamic>;
          _errorMessage = errBody['message'] ?? "Failed to record repayment";
        } catch (_) {
          _errorMessage = "Failed to record repayment: ${response.statusCode}";
        }
      }
    } catch (e) {
      _errorMessage = "Network error recording repayment: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteDebt(int id) async {
    try {
      final response = await _apiService.delete('/debts/$id');
      if (response.statusCode == 204 || response.statusCode == 200) {
        _debts.removeWhere((d) => d.id == id);
        await fetchSummary();
        notifyListeners();
        return true;
      } else {
        _errorMessage = "Failed to delete debt: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error deleting debt: $e";
    }
    notifyListeners();
    return false;
  }
}
