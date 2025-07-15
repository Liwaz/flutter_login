import 'package:auth_repo/auth_repo.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_login/login/models/models.dart';
import 'package:flutter_login/register/models/email.dart';
import 'package:formz/formz.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({required AuthenticationRepository authenticationRepository})
      : _authenticationRepository = authenticationRepository,
        super(const RegisterState()) {
    on<RegisterUsernameChanged>(_onUsernameChanged);
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  final AuthenticationRepository _authenticationRepository;

  void _onUsernameChanged(
      RegisterUsernameChanged event, Emitter<RegisterState> emit) {
    final username = Username.dirty(event.username);
    emit(state.copyWith(
      username: username,
      isValid: Formz.validate([username, state.email, state.password]),
    ));
  }

  void _onEmailChanged(RegisterEmailChanged event, Emitter<RegisterState> emit) {
    final email = Email.dirty(event.email);
    emit(state.copyWith(
      email: email,
      isValid: Formz.validate([state.username, email, state.password]),
    ));
  }

  void _onPasswordChanged(
      RegisterPasswordChanged event, Emitter<RegisterState> emit) {
    final password = Password.dirty(event.password);
    emit(state.copyWith(
      password: password,
      isValid: Formz.validate([state.username, state.email, password]),
    ));
  }

  Future<void> _onSubmitted(
      RegisterSubmitted event, Emitter<RegisterState> emit) async {
    if (state.isValid) {
      emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
      try {
        await _authenticationRepository.register(
          username: state.username.value,
          email: state.email.value,
          password: state.password.value,
        );
        emit(state.copyWith(status: FormzSubmissionStatus.success));
      } catch (_) {
        emit(state.copyWith(status: FormzSubmissionStatus.failure));
      }
    }
  }
}
