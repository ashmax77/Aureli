import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

  static const String _userCacheKey = 'aureli_cached_user';

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;
  String? _errorMessage;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _firebaseUser != null;
  bool get needsOnboarding => _userModel != null && _userModel!.onboardingStatus == OnboardingStatus.NOT_STARTED;

  AuthProvider(this._authService, this._apiService) {
    _loadCachedUser();
    _authService.userChanges.listen(_onAuthStateChanged);
  }

  Future<void> _loadCachedUser() async {
    try {
      final cachedJson = await SecureStorageService.read(_userCacheKey);
      if (cachedJson != null) {
        _userModel = UserModel.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error loading cached user: $e");
    }
  }

  Future<void> _saveCachedUser(UserModel user) async {
    try {
      await SecureStorageService.write(_userCacheKey, jsonEncode(user.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving cached user: $e");
    }
  }

  Future<void> _clearCachedUser() async {
    try {
      await SecureStorageService.delete(_userCacheKey);
    } catch (_) {}
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _errorMessage = null;

    if (user != null) {
      final bool hasCache = _userModel != null;
      if (!hasCache) {
        _isLoading = true;
        notifyListeners();
      }
      await fetchUserProfile(silent: hasCache);
    } else {
      _userModel = null;
      _isLoading = false;
      await _clearCachedUser();
      notifyListeners();
    }
  }

  // Fetch or Provision local user profile
  Future<void> fetchUserProfile({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final response = await _apiService.get('/me');
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
      } else {
        _errorMessage = "Backend profile sync status: ${response.statusCode}";
        if (_firebaseUser != null && _userModel == null) {
          _userModel = UserModel(
            id: 0,
            firebaseUid: _firebaseUser!.uid,
            email: _firebaseUser!.email ?? '',
            onboardingStatus: OnboardingStatus.COMPLETED,
          );
        }
      }
    } catch (e) {
      _errorMessage = "Network error syncing profile: $e";
      if (_firebaseUser != null && _userModel == null) {
        _userModel = UserModel(
          id: 0,
          firebaseUid: _firebaseUser!.uid,
          email: _firebaseUser!.email ?? '',
          onboardingStatus: OnboardingStatus.COMPLETED,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email, password);
      return true;
    } catch (e) {
      _errorMessage = _cleanAuthErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign Up
  Future<bool> signUp(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(email, password);
      return true;
    } catch (e) {
      _errorMessage = _cleanAuthErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Complete Onboarding status
  Future<bool> completeOnboarding() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.patch('/me/onboarding', {'status': 'COMPLETED'});
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "Failed to complete onboarding: Code ${response.statusCode}";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = "Network error completing onboarding: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register device FCM token
  Future<void> registerFcmToken(String token) async {
    try {
      final response = await _apiService.patch('/me/fcm-token', {'fcmToken': token});
      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint("Failed to register FCM token: Code ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error registering FCM token: $e");
    }
  }

  // Update Savings Rate percentage
  Future<bool> updateSavingsRate(double rate) async {
    try {
      final response = await _apiService.patch('/me/savings-rate', {'savingsRatePercentage': rate});
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _saveCachedUser(_userModel!);
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Error updating savings rate: $e");
    }
    return false;
  }

  // Sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    // CRITICAL: Clear ALL encrypted caches (transactions, budgets, debts, offline queue)
    await SecureStorageService.deleteAll();
    await _authService.signOut();
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanAuthErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _cleanAuthErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('invalid-email') || lower.contains('invalid email')) {
      return "The email address is badly formatted.";
    }
    if (lower.contains('invalid-credential') ||
        lower.contains('invalid_login_credentials') ||
        lower.contains('user-not-found') ||
        lower.contains('wrong-password')) {
      return "Invalid email or password. Please check your credentials or switch to 'Create account' if you haven't signed up yet.";
    }
    if (lower.contains('email-already-in-use')) {
      return "An account already exists with this email. Please switch to 'Sign in'.";
    }
    if (lower.contains('weak-password')) {
      return "Password must be at least 6 characters.";
    }
    if (lower.contains('too-many-requests')) {
      return "Account temporarily blocked due to multiple failed login attempts. Please reset your password or try again later.";
    }
    if (lower.contains('network-request-failed')) {
      return "Network error. Please check your internet connection and try again.";
    }
    return error.replaceAll(RegExp(r'\[.*?\]'), '').trim();
  }
}
