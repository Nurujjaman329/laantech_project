import '../../../../core/usecase/usecase.dart';
import '../entities/auth_token.dart';
import '../repositories/auth_repository.dart';
import 'login_usecase.dart';

class RegisterUseCase implements UseCase<AuthToken, LoginParams> {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  @override
  Future<AuthToken> call(LoginParams params) async {
    return await repository.register(
      username: params.username,
      password: params.password,
    );
  }
}
