import '../entities/auth_token.dart';

abstract class AuthRepository {
  Future<AuthToken> login({
    required String username,
    required String password,
  });

  Future<AuthToken> register({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<AuthToken?> getCurrentUser();

  Future<bool> isAuthenticated();
}
