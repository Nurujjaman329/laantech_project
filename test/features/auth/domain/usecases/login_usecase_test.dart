import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/features/auth/domain/entities/auth_token.dart';
import 'package:laantech_task/features/auth/domain/repositories/auth_repository.dart';
import 'package:laantech_task/features/auth/domain/usecases/login_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late LoginUseCase useCase;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  const testParams = LoginParams(username: 'pos_user', password: 'pos_password');
  const testAuthToken = AuthToken(token: 'token123', username: 'pos_user');

  test('LoginUseCase calls repository.login and returns AuthToken', () async {
    when(() => mockRepository.login(
          username: testParams.username,
          password: testParams.password,
        )).thenAnswer((_) async => testAuthToken);

    final result = await useCase(testParams);

    expect(result, testAuthToken);
    verify(() => mockRepository.login(
          username: testParams.username,
          password: testParams.password,
        )).called(1);
  });
}
