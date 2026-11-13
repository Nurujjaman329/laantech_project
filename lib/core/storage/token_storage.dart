import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

abstract class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> saveUsername(String username);
  Future<String?> getUsername();
  Future<void> clear();
}

class TokenStorageImpl implements TokenStorage {
  final FlutterSecureStorage secureStorage;
  final SharedPreferences sharedPreferences;

  TokenStorageImpl({
    required this.secureStorage,
    required this.sharedPreferences,
  });

  @override
  Future<void> saveToken(String token) async {
    try {
      await secureStorage.write(key: ApiConstants.tokenKey, value: token);
    } catch (_) {
      // Fallback to SharedPreferences if secure storage fails on emulator/platform
      await sharedPreferences.setString(ApiConstants.tokenKey, token);
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      final token = await secureStorage.read(key: ApiConstants.tokenKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return sharedPreferences.getString(ApiConstants.tokenKey);
  }

  @override
  Future<void> saveUsername(String username) async {
    await sharedPreferences.setString(ApiConstants.usernameKey, username);
  }

  @override
  Future<String?> getUsername() async {
    return sharedPreferences.getString(ApiConstants.usernameKey);
  }

  @override
  Future<void> clear() async {
    try {
      await secureStorage.delete(key: ApiConstants.tokenKey);
    } catch (_) {}
    await sharedPreferences.remove(ApiConstants.tokenKey);
    await sharedPreferences.remove(ApiConstants.usernameKey);
  }
}
