import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network error. Please check your internet connection.'});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Failed to load cached data.'});
}

class TransferFailure extends Failure {
  final String? taskId;

  const TransferFailure({required super.message, this.taskId, super.statusCode});

  @override
  List<Object?> get props => [message, statusCode, taskId];
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}
