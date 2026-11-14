import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
          if (!options.path.contains(ApiConstants.tokenEndpoint) &&
              !options.path.contains('/register')) {
            final token = await _tokenStorage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );

    // Debug-only: log every API request / response / error in the console.
    if (kDebugMode) {
      _dio.interceptors.add(_ApiDebugLogInterceptor());
    }
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
          return AuthException(
            message: message.isNotEmpty && message != 'Server error occurred (401)'
                ? message
                : 'Session expired or unauthorized. Please sign in again.',
          );
        }
        if (statusCode == 404) {
          return ServerException(
            message: message.isNotEmpty && !message.startsWith('Server error')
                ? message
                : 'File or resource not found.',
            statusCode: statusCode,
          );
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

/// Pretty, truncated API logs for debug builds only.
class _ApiDebugLogInterceptor extends Interceptor {
  static const String _tag = '[API]';
  static const int _maxBodyChars = 1200;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final uri = options.uri;
    debugPrint('$_tag ➤ ${options.method} $uri');
    debugPrint('$_tag   headers: ${_sanitizeHeaders(options.headers)}');
    final body = _formatBody(options.data);
    if (body != null) {
      debugPrint('$_tag   body: $body');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final uri = response.requestOptions.uri;
    debugPrint(
      '$_tag ◀ ${response.statusCode} ${response.requestOptions.method} $uri',
    );
    if (response.requestOptions.responseType == ResponseType.stream) {
      debugPrint('$_tag   body: <binary/stream response>');
    } else {
      final body = _formatBody(response.data);
      if (body != null) {
        debugPrint('$_tag   body: $body');
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final uri = err.requestOptions.uri;
    debugPrint(
      '$_tag ✖ ${err.response?.statusCode ?? '-'} '
      '${err.requestOptions.method} $uri',
    );
    debugPrint('$_tag   type: ${err.type}');
    debugPrint('$_tag   message: ${err.message}');
    final body = _formatBody(err.response?.data);
    if (body != null) {
      debugPrint('$_tag   errorBody: $body');
    }
    handler.next(err);
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final copy = Map<String, dynamic>.from(headers);
    final authKey = copy.keys.firstWhere(
      (k) => k.toLowerCase() == 'authorization',
      orElse: () => '',
    );
    if (authKey.isNotEmpty) {
      final value = copy[authKey]?.toString() ?? '';
      if (value.length > 16) {
        copy[authKey] =
            '${value.substring(0, 12)}…${value.substring(value.length - 6)}';
      }
    }
    return copy;
  }

  String? _formatBody(dynamic data) {
    if (data == null) return null;
    if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}=${e.value}').join(', ');
      final files = data.files
          .map((e) => '${e.key}=${e.value.filename ?? 'file'}'
              '(${e.value.length} bytes)')
          .join(', ');
      final parts = <String>[
        if (fields.isNotEmpty) 'fields: [$fields]',
        if (files.isNotEmpty) 'files: [$files]',
      ];
      return parts.isEmpty ? '<empty FormData>' : parts.join(' | ');
    }
    if (data is List<int>) {
      return '<bytes: ${data.length}>';
    }
    if (data is Stream) {
      return '<stream>';
    }
    final text = data.toString();
    if (text.length <= _maxBodyChars) return text;
    return '${text.substring(0, _maxBodyChars)}… (truncated)';
  }
}
