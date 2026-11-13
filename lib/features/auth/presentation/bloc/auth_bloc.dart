import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/auth_token.dart';
import '../../domain/usecases/get_auth_status_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final GetAuthStatusUseCase getAuthStatusUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.getAuthStatusUseCase,
  }) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthDemoLoginRequested>(_onAuthDemoLoginRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await getAuthStatusUseCase(NoParams());
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await loginUseCase(
        LoginParams(
          username: event.username,
          password: event.password,
        ),
      );
      emit(AuthAuthenticated(token));
    } on Failure catch (failure) {
      emit(AuthFailureState(failure.message));
    } catch (e) {
      emit(AuthFailureState(e.toString()));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final token = await registerUseCase(
        LoginParams(
          username: event.username,
          password: event.password,
        ),
      );
      emit(AuthAuthenticated(token));
    } on Failure catch (failure) {
      emit(AuthFailureState(failure.message));
    } catch (e) {
      emit(AuthFailureState(e.toString()));
    }
  }

  Future<void> _onAuthDemoLoginRequested(
    AuthDemoLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    // Instant test operator access
    const demoToken = AuthToken(
      token: 'mock_demo_bearer_token_xyz',
      tokenType: 'Bearer',
      username: 'demo_operator',
    );
    emit(const AuthAuthenticated(demoToken));
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await logoutUseCase(NoParams());
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }
}
