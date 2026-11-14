import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/errors/error_message_mapper.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/errors/failures.dart';

void main() {
  group('ErrorMessageMapper', () {
    test('maps timeout-like text to friendly timeout message', () {
      final message = ErrorMessageMapper.from(
        const NetworkException(message: 'Connection timed out. Check network.'),
      );
      expect(message, contains('timed out'));
    });

    test('maps 401 auth failure to session message', () {
      final message = ErrorMessageMapper.from(
        const AuthFailure(message: 'Unauthorized', statusCode: 401),
      );
      expect(message.toLowerCase(), contains('sign in'));
    });

    test('maps offline / socket text to no-internet message', () {
      final message = ErrorMessageMapper.from(
        Exception('SocketException: Failed host lookup'),
      );
      expect(message.toLowerCase(), contains('internet'));
    });

    test('keeps short friendly server messages', () {
      final message = ErrorMessageMapper.from(
        const ServerException(message: 'Username already taken', statusCode: 409),
      );
      expect(message.toLowerCase(), contains('already taken'));
    });
  });
}
