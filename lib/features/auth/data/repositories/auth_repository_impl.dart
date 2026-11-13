import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final TokenStorage tokenStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStorage,
  });

  @override
  Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    try {
      final tokenModel = await remoteDataSource.login(
        username: username,
        password: password,
      );

      // Persist token and username locally
      await tokenStorage.saveToken(tokenModel.token);
      await tokenStorage.saveUsername(username);

      return tokenModel;
    } on AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(message: e.message);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  @override
  Future<AuthToken> register({
    required String username,
    required String password,
  }) async {
    try {
      final tokenModel = await remoteDataSource.register(
        username: username,
        password: password,
      );

      await tokenStorage.saveToken(tokenModel.token);
      await tokenStorage.saveUsername(username);

      return tokenModel;
    } on AuthException catch (e) {
      throw AuthFailure(message: e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(message: e.message);
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message, statusCode: e.statusCode);
    } catch (e) {
      throw ServerFailure(message: e.toString());
    }
  }

  @override
  Future<void> logout() async {
    await tokenStorage.clear();
  }

  @override
  Future<AuthToken?> getCurrentUser() async {
    final token = await tokenStorage.getToken();
    final username = await tokenStorage.getUsername();

    if (token != null && token.isNotEmpty) {
      return AuthToken(
        token: token,
        username: username ?? 'User',
      );
    }
    return null;
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await tokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }
}
