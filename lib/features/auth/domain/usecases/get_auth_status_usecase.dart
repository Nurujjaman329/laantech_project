import '../../../../core/usecase/usecase.dart';
import '../entities/auth_token.dart';
import '../repositories/auth_repository.dart';

class GetAuthStatusUseCase implements UseCase<AuthToken?, NoParams> {
  final AuthRepository repository;

  GetAuthStatusUseCase(this.repository);

  @override
  Future<AuthToken?> call(NoParams params) async {
    return await repository.getCurrentUser();
  }
}
