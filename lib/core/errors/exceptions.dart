class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'ServerException(message: $message, statusCode: $statusCode)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException({this.message = 'No internet connection available'});

  @override
  String toString() => 'NetworkException(message: $message)';
}

class CacheException implements Exception {
  final String message;

  const CacheException({this.message = 'Cache operation failed'});

  @override
  String toString() => 'CacheException(message: $message)';
}

class TransferException implements Exception {
  final String message;
  final String? taskId;

  const TransferException({
    required this.message,
    this.taskId,
  });

  @override
  String toString() => 'TransferException(message: $message, taskId: $taskId)';
}

class AuthException implements Exception {
  final String message;

  const AuthException({required this.message});

  @override
  String toString() => 'AuthException(message: $message)';
}
