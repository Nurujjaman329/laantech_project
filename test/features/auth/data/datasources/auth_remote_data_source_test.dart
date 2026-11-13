import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/constants/api_constants.dart';
import 'package:laantech_task/core/errors/exceptions.dart';
import 'package:laantech_task/core/network/dio_client.dart';
import 'package:laantech_task/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:laantech_task/features/auth/data/models/auth_token_model.dart';

class MockDioClient extends Mock implements DioClient {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockDioClient mockDioClient;
  late MockDio mockDio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDioClient = MockDioClient();
    mockDio = MockDio();
    when(() => mockDioClient.dio).thenReturn(mockDio);
    dataSource = AuthRemoteDataSourceImpl(dioClient: mockDioClient);
  });

  group('AuthRemoteDataSourceImpl login', () {
    const testUsername = 'testuser';
    const testPassword = 'password123';
    const testToken = 'token_abc_123';

    test('should return AuthTokenModel when the response is 200', () async {
      when(() => mockDio.post(
            ApiConstants.tokenEndpoint,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.tokenEndpoint),
            statusCode: 200,
            data: {'access_token': testToken, 'token_type': 'Bearer'},
          ));

      final result = await dataSource.login(
        username: testUsername,
        password: testPassword,
      );

      expect(result, isA<AuthTokenModel>());
      expect(result.token, testToken);
      expect(result.username, testUsername);
    });

    test('should throw ServerException when response status code is not 200/201', () async {
      when(() => mockDio.post(
            ApiConstants.tokenEndpoint,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiConstants.tokenEndpoint),
            statusCode: 400,
            data: {'detail': 'Invalid form'},
          ));

      expect(
        () => dataSource.login(username: testUsername, password: testPassword),
        throwsA(isA<ServerException>()),
      );
    });

    test('should rethrow exception from dioClient.handleDioException on DioException', () async {
      final dioException = DioException(
        requestOptions: RequestOptions(path: ApiConstants.tokenEndpoint),
        type: DioExceptionType.connectionTimeout,
      );

      when(() => mockDio.post(
            ApiConstants.tokenEndpoint,
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(dioException);

      when(() => mockDioClient.handleDioException(dioException))
          .thenReturn(const NetworkException(message: 'Timeout'));

      expect(
        () => dataSource.login(username: testUsername, password: testPassword),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
