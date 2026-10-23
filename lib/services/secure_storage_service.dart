import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _deviceIdKey = 'device_id';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
    Future<void> deleteDeviceId() async {
    await _storage.delete(key: _deviceIdKey);
  }

  /// Backend mewajibkan device_id di tiap login, tapi tidak jelaskan
  /// formatnya harus apa. Jadi kita generate sekali secara acak per HP,
  /// lalu simpan supaya nilainya selalu sama di login-login berikutnya.
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      deviceId = _generateRandomId();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  String _generateRandomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}