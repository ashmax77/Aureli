import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

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
    _authService.userChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _errorMessage = null;

    if (user != null) {
      await fetchUserProfile();
    } else {
      _userModel = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch or Provision local user profile
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/me');
      if (response.statusCode == 200) {
        _userModel = UserModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        _errorMessage = "Failed to sync user profile: Code ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Network error syncing profile: $e";
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
        debugPrint("Failed to register FCM token: Code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error registering FCM token: $e");
    }
  }

  // Sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
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
