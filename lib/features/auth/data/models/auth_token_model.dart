import '../../domain/entities/auth_token.dart';

class AuthTokenModel extends AuthToken {
  const AuthTokenModel({
    required super.token,
    super.tokenType = 'Bearer',
    required super.username,
  });

  factory AuthTokenModel.fromJson(dynamic json, {required String username}) {
    if (json is Map<String, dynamic>) {
      final token = json['access_token'] ?? json['token'] ?? json['key'] ?? '';
      final tokenType = json['token_type'] ?? 'Bearer';
      return AuthTokenModel(
        token: token.toString(),
        tokenType: tokenType.toString(),
        username: username,
      );
    } else if (json is String) {
      return AuthTokenModel(
        token: json,
        tokenType: 'Bearer',
        username: username,
      );
    }
    return AuthTokenModel(
      token: json.toString(),
      tokenType: 'Bearer',
      username: username,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': token,
      'token_type': tokenType,
      'username': username,
    };
  }
}
