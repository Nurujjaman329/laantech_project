import 'exceptions.dart';
import 'failures.dart';

/// Maps exceptions / failures to short, user-friendly messages.
class ErrorMessageMapper {
  ErrorMessageMapper._();

  static String from(Object error, {String? fallback}) {
    if (error is Failure) {
      return _refine(error.message, statusCode: error.statusCode);
    }
    if (error is NetworkException) {
      return _refine(error.message);
    }
    if (error is AuthException) {
      return _refine(error.message, statusCode: 401);
    }
    if (error is ServerException) {
      return _refine(error.message, statusCode: error.statusCode);
    }
    if (error is TransferException) {
      return error.message;
    }

    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^[A-Za-z]+Exception\(message:\s*'), '')
        .replaceFirst(RegExp(r',\s*statusCode:.*\)\s*$'), '')
        .replaceFirst(RegExp(r'\)\s*$'), '')
        .trim();

    return _refine(raw.isEmpty ? (fallback ?? 'Something went wrong.') : raw);
  }

  static String _refine(String message, {int? statusCode}) {
    final lower = message.toLowerCase();

    if (statusCode == 401 ||
        lower.contains('unauthorized') ||
        lower.contains('invalid credentials') ||
        lower.contains('authentication')) {
      if (lower.contains('credential') || lower.contains('password')) {
        return 'Invalid username or password.';
      }
      return 'Session expired or unauthorized. Please sign in again.';
    }

    if (statusCode == 404 || lower.contains('not found')) {
      return 'File or resource not found.';
    }

    if (statusCode == 409 || lower.contains('already taken')) {
      return 'Username already taken. Try another one.';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Connection timed out. Check your network and try again.';
    }

    if (lower.contains('socket') ||
        lower.contains('no internet') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection error') ||
        lower.contains('failed host lookup')) {
      return 'No internet connection. Check your network and try again.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Server error ($statusCode). Please try again later.';
    }

    // Prefer short server message if already friendly.
    if (message.length <= 120 && !message.contains('DioException')) {
      return message;
    }

    return 'Something went wrong. Please try again.';
  }
}
