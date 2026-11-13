import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/errors/failures.dart';
import 'package:laantech_task/core/storage/token_storage.dart';
import 'package:laantech_task/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:laantech_task/features/auth/data/models/auth_token_model.dart';
import 'package:laantech_task/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockTokenStorage mockTokenStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockTokenStorage = MockTokenStorage();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      tokenStorage: mockTokenStorage,
    );
  });

  const testUsername = 'testuser';
  const testPassword = 'password123';
  const testTokenModel = AuthTokenModel(
    token: 'jwt_token_sample',
    username: testUsername,
  );

  group('AuthRepositoryImpl login', () {
    test('should save token to storage and return AuthToken on success', () async {
      when(() => mockRemoteDataSource.login(
            username: testUsername,
            password: testPassword,
          )).thenAnswer((_) async => testTokenModel);
      when(() => mockTokenStorage.saveToken(any())).thenAnswer((_) async {});
      when(() => mockTokenStorage.saveUsername(any())).thenAnswer((_) async {});

      final result = await repository.login(
        username: testUsername,
        password: testPassword,
      );

      expect(result.token, testTokenModel.token);
      verify(() => mockTokenStorage.saveToken(testTokenModel.token)).called(1);
      verify(() => mockTokenStorage.saveUsername(testUsername)).called(1);
    });

    test('should map AuthException to AuthFailure', () async {
      when(() => mockRemoteDataSource.login(
            username: testUsername,
            password: testPassword,
          )).thenThrow(const AuthException(message: 'Invalid credentials'));

      expect(
        () => repository.login(username: testUsername, password: testPassword),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('should map NetworkException to NetworkFailure', () async {
      when(() => mockRemoteDataSource.login(
            username: testUsername,
            password: testPassword,
          )).thenThrow(const NetworkException(message: 'No internet'));

      expect(
        () => repository.login(username: testUsername, password: testPassword),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('AuthRepositoryImpl logout', () {
    test('should clear token storage', () async {
      when(() => mockTokenStorage.clear()).thenAnswer((_) async {});

      await repository.logout();

      verify(() => mockTokenStorage.clear()).called(1);
    });
  });

  group('AuthRepositoryImpl getCurrentUser & isAuthenticated', () {
    test('getCurrentUser returns AuthToken when token is in storage', () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'saved_token');
      when(() => mockTokenStorage.getUsername()).thenAnswer((_) async => 'stored_user');

      final user = await repository.getCurrentUser();

      expect(user?.token, 'saved_token');
      expect(user?.username, 'stored_user');
    });

    test('isAuthenticated returns true when token exists', () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => 'saved_token');

      final isAuth = await repository.isAuthenticated();

      expect(isAuth, isTrue);
    });

    test('isAuthenticated returns false when token is null', () async {
      when(() => mockTokenStorage.getToken()).thenAnswer((_) async => null);

      final isAuth = await repository.isAuthenticated();

      expect(isAuth, isFalse);
    });
  });
}
