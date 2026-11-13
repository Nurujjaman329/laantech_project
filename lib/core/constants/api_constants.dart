class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://108.136.142.112:90';
  static const String fallbackBaseUrl = 'http://15.232.228.139/api';

  // Endpoints
  static const String tokenEndpoint = '/token';
  static const String listFilesEndpoint = '/get';
  static const String uploadEndpoint = '/upload';
  static const String downloadEndpoint = '/get'; // ?file=NAME
  static const String deleteEndpoint = '/delete'; // ?file=NAME

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(minutes: 5); // for large files

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'auth_username';
}
