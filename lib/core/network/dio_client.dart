import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../storage/token_storage.dart';

class DioClient {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  DioClient({
    Dio? dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio ?? Dio(),
        _tokenStorage = tokenStorage {
    _dio.options = BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if not already provided and not login/token endpoint
          if (!options.path.contains(ApiConstants.tokenEndpoint)) {
            final token = await _tokenStorage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Log or handle common status codes
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  /// Helper to map DioException to Clean Architecture Exceptions
  Exception handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException(message: 'Connection timed out. Check network.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;
        String message = 'Server error occurred ($statusCode)';
        if (data is Map && data.containsKey('detail')) {
          message = data['detail'].toString();
        } else if (data is Map && data.containsKey('message')) {
          message = data['message'].toString();
        } else if (data is String && data.isNotEmpty) {
          message = data;
        }
        if (statusCode == 401) {
          return AuthException(message: message);
        }
        return ServerException(message: message, statusCode: statusCode);
      case DioExceptionType.cancel:
        return const TransferException(message: 'Transfer was cancelled or paused by user.');
      case DioExceptionType.badCertificate:
        return const ServerException(message: 'Bad SSL certificate.');
      case DioExceptionType.unknown:
      default:
        if (e.error is SocketException) {
          return const NetworkException(message: 'No internet connection.');
        }
        return ServerException(
          message: e.message ?? 'Unexpected error occurred',
          statusCode: e.response?.statusCode,
        );
    }
  }
}
