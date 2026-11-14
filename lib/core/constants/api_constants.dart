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
  /// Default Dio send timeout for normal API calls (not large multipart uploads).
  static const Duration sendTimeout = Duration(minutes: 5);
  /// Upload-only override: global [sendTimeout] covers the whole multipart body,
  /// so a 50MB+ catalog on a slow link can fail mid-send. Uploads use this longer
  /// (effectively "no short send deadline") while still keeping [connectTimeout].
  static const Duration uploadSendTimeout = Duration(hours: 6);

  /// Configurable upload size cap (bytes). Not a file-type filter.
  static const int maxUploadBytes = 500 * 1024 * 1024; // 500MB

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'auth_username';
}
