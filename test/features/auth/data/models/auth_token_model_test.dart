import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/features/auth/data/models/auth_token_model.dart';
import 'package:laantech_task/features/auth/domain/entities/auth_token.dart';

void main() {
  const testUsername = 'cashier1';
  const testTokenString = 'jwt_test_token_xyz';

  test('AuthTokenModel should be a subclass of AuthToken entity', () {
    const model = AuthTokenModel(
      token: testTokenString,
      username: testUsername,
    );
    expect(model, isA<AuthToken>());
  });

  group('fromJson', () {
    test('should parse OAuth2 access_token map properly', () {
      final jsonMap = {
        'access_token': testTokenString,
        'token_type': 'Bearer',
      };

      final result = AuthTokenModel.fromJson(jsonMap, username: testUsername);

      expect(result.token, testTokenString);
      expect(result.tokenType, 'Bearer');
      expect(result.username, testUsername);
    });

    test('should parse map with token key properly', () {
      final jsonMap = {
        'token': testTokenString,
      };

      final result = AuthTokenModel.fromJson(jsonMap, username: testUsername);

      expect(result.token, testTokenString);
      expect(result.username, testUsername);
    });

    test('should parse raw string token properly', () {
      final result = AuthTokenModel.fromJson(testTokenString, username: testUsername);

      expect(result.token, testTokenString);
      expect(result.username, testUsername);
    });
  });

  group('toJson', () {
    test('should return a JSON map containing proper data', () {
      const model = AuthTokenModel(
        token: testTokenString,
        username: testUsername,
      );

      final result = model.toJson();

      expect(result['access_token'], testTokenString);
      expect(result['token_type'], 'Bearer');
      expect(result['username'], testUsername);
    });
  });
}
