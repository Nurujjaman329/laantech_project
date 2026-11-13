import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_token_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthTokenModel> login({
    required String username,
    required String password,
  });

  Future<AuthTokenModel> register({
    required String username,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient dioClient;

  AuthRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<AuthTokenModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.dio.post(
        ApiConstants.tokenEndpoint,
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthTokenModel.fromJson(response.data, username: username);
      } else {
        throw ServerException(
          message: 'Authentication failed with status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw dioClient.handleDioException(e);
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<AuthTokenModel> register({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dioClient.dio.post(
        '/register',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthTokenModel.fromJson(response.data, username: username);
      } else {
        // If /register is not a separate endpoint, attempt logging in directly
        return await login(username: username, password: password);
      }
    } catch (_) {
      // Fallback: Attempt standard login with these credentials
      return await login(username: username, password: password);
    }
  }
}
