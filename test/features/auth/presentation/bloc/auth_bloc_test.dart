import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laantech_task/core/errors/failures.dart';
import 'package:laantech_task/core/usecase/usecase.dart';
import 'package:laantech_task/features/auth/domain/entities/auth_token.dart';
import 'package:laantech_task/features/auth/domain/usecases/get_auth_status_usecase.dart';
import 'package:laantech_task/features/auth/domain/usecases/login_usecase.dart';
import 'package:laantech_task/features/auth/domain/usecases/logout_usecase.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_event.dart';
import 'package:laantech_task/features/auth/presentation/bloc/auth_state.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockGetAuthStatusUseCase extends Mock implements GetAuthStatusUseCase {}

void main() {
  late MockLoginUseCase mockLoginUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockGetAuthStatusUseCase mockGetAuthStatusUseCase;
  late AuthBloc authBloc;

  const testUser = AuthToken(token: 'token_123', username: 'pos_admin');

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockGetAuthStatusUseCase = MockGetAuthStatusUseCase();
    authBloc = AuthBloc(
      loginUseCase: mockLoginUseCase,
      logoutUseCase: mockLogoutUseCase,
      getAuthStatusUseCase: mockGetAuthStatusUseCase,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  test('initial state should be AuthInitial', () {
    expect(authBloc.state, const AuthInitial());
  });

  group('AuthCheckRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when user is found in storage',
      build: () {
        when(() => mockGetAuthStatusUseCase(NoParams()))
            .thenAnswer((_) async => testUser);
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] when no user in storage',
      build: () {
        when(() => mockGetAuthStatusUseCase(NoParams()))
            .thenAnswer((_) async => null);
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );
  });

  group('AuthLoginRequested', () {
    const loginParams = LoginParams(username: 'pos_admin', password: 'secretpassword');

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] on successful login',
      build: () {
        when(() => mockLoginUseCase(loginParams))
            .thenAnswer((_) async => testUser);
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        username: 'pos_admin',
        password: 'secretpassword',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(testUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthFailureState] when login fails',
      build: () {
        when(() => mockLoginUseCase(loginParams))
            .thenThrow(const AuthFailure(message: 'Invalid credentials'));
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLoginRequested(
        username: 'pos_admin',
        password: 'secretpassword',
      )),
      expect: () => [
        const AuthLoading(),
        const AuthFailureState('Invalid credentials'),
      ],
    );
  });

  group('AuthLogoutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthUnauthenticated] on logout',
      build: () {
        when(() => mockLogoutUseCase(NoParams()))
            .thenAnswer((_) async {});
        return authBloc;
      },
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [
        const AuthLoading(),
        const AuthUnauthenticated(),
      ],
    );
  });
}
