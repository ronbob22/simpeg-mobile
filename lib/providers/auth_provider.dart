import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();

  AuthStatus _status = AuthStatus.unknown;
  String? _nip;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  String? get nip => _nip;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> checkInitialAuthStatus() async {
    final hasToken = await _secureStorage.hasToken();
    _status = hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String nip, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.login(nip, password);
      _nip = nip;
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _nip = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}