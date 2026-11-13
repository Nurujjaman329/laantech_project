import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/network/dio_client.dart';
import 'package:laantech_task/core/storage/token_storage.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockTokenStorage mockTokenStorage;
  late DioClient dioClient;

  setUp(() {
    mockTokenStorage = MockTokenStorage();
    dioClient = DioClient(tokenStorage: mockTokenStorage);
  });

  group('DioClient Exception Handling Tests', () {
    test('connectionTimeout maps to NetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final result = dioClient.handleDioException(dioException);
      expect(result, isA<NetworkException>());
    });

    test('badResponse 401 maps to AuthException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'detail': 'Invalid credentials'},
        ),
      );

      final result = dioClient.handleDioException(dioException);
      expect(result, isA<AuthException>());
      expect((result as AuthException).message, contains('Invalid credentials'));
    });

    test('badResponse 500 maps to ServerException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
          data: {'detail': 'Internal Server Error'},
        ),
      );

      final result = dioClient.handleDioException(dioException);
      expect(result, isA<ServerException>());
      expect((result as ServerException).statusCode, 500);
    });

    test('cancel maps to TransferException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );

      final result = dioClient.handleDioException(dioException);
      expect(result, isA<TransferException>());
    });
  });
}
