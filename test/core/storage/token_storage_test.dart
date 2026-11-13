import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laantech_task/core/constants/api_constants.dart';
import 'package:laantech_task/core/storage/token_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late MockFlutterSecureStorage mockSecureStorage;
  late MockSharedPreferences mockSharedPreferences;
  late TokenStorageImpl tokenStorage;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    mockSharedPreferences = MockSharedPreferences();
    tokenStorage = TokenStorageImpl(
      secureStorage: mockSecureStorage,
      sharedPreferences: mockSharedPreferences,
    );
  });

  group('TokenStorageImpl Tests', () {
    const testToken = 'mock_jwt_token_123';
    const testUsername = 'test_user';

    test('saveToken saves to secure storage', () async {
      when(() => mockSecureStorage.write(
            key: ApiConstants.tokenKey,
            value: testToken,
          )).thenAnswer((_) async {});

      await tokenStorage.saveToken(testToken);

      verify(() => mockSecureStorage.write(
            key: ApiConstants.tokenKey,
            value: testToken,
          )).called(1);
    });

    test('saveToken falls back to sharedPreferences on secureStorage exception', () async {
      when(() => mockSecureStorage.write(
            key: ApiConstants.tokenKey,
            value: testToken,
          )).thenThrow(Exception('PlatformException'));
      when(() => mockSharedPreferences.setString(
            ApiConstants.tokenKey,
            testToken,
          )).thenAnswer((_) async => true);

      await tokenStorage.saveToken(testToken);

      verify(() => mockSharedPreferences.setString(
            ApiConstants.tokenKey,
            testToken,
          )).called(1);
    });

    test('getToken returns token from secure storage when present', () async {
      when(() => mockSecureStorage.read(key: ApiConstants.tokenKey))
          .thenAnswer((_) async => testToken);

      final result = await tokenStorage.getToken();

      expect(result, testToken);
      verify(() => mockSecureStorage.read(key: ApiConstants.tokenKey)).called(1);
      verifyNever(() => mockSharedPreferences.getString(any()));
    });

    test('saveUsername and getUsername interact with sharedPreferences', () async {
      when(() => mockSharedPreferences.setString(ApiConstants.usernameKey, testUsername))
          .thenAnswer((_) async => true);
      when(() => mockSharedPreferences.getString(ApiConstants.usernameKey))
          .thenReturn(testUsername);

      await tokenStorage.saveUsername(testUsername);
      final result = await tokenStorage.getUsername();

      expect(result, testUsername);
      verify(() => mockSharedPreferences.setString(ApiConstants.usernameKey, testUsername)).called(1);
      verify(() => mockSharedPreferences.getString(ApiConstants.usernameKey)).called(1);
    });

    test('clear wipes both secure storage and shared preferences', () async {
      when(() => mockSecureStorage.delete(key: ApiConstants.tokenKey))
          .thenAnswer((_) async {});
      when(() => mockSharedPreferences.remove(any()))
          .thenAnswer((_) async => true);

      await tokenStorage.clear();

      verify(() => mockSecureStorage.delete(key: ApiConstants.tokenKey)).called(1);
      verify(() => mockSharedPreferences.remove(ApiConstants.tokenKey)).called(1);
      verify(() => mockSharedPreferences.remove(ApiConstants.usernameKey)).called(1);
    });
  });
}
