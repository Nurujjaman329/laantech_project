import 'package:equatable/equatable.dart';

class AuthToken extends Equatable {
  final String token;
  final String tokenType;
  final String username;

  const AuthToken({
    required this.token,
    this.tokenType = 'Bearer',
    required this.username,
  });

  @override
  List<Object?> get props => [token, tokenType, username];
}
