# Strapi Backend Implementation Guide

This document outlines the steps to integrate the Flutter application with a Strapi backend, including user registration and proper state management using the existing BLoC pattern.

## 1. Additional Libraries Needed

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.1
  flutter_dotenv: ^5.1.0
  shared_preferences: ^2.2.3 # Or flutter_secure_storage
```

## 2. Strapi Backend Configuration

Configure Strapi's **Users & Permissions** plugin.

### Steps:

1.  **Enable Public Registration:**
    *   In your Strapi Admin Panel, go to `Settings` -> `Users & Permissions Plugin` -> `Roles`.
    *   Select the **Public** role.
    *   Under `Permissions`, enable `Auth` -> `register` and `Users-permissions` -> `connect`.
    *   Click **Save**.

2.  **Configure Authenticated User Permissions:**
    *   Go back to `Roles` and select the **Authenticated** role.
    *   Under `Permissions`, find your user collection type (e.g., **Flutter-user**).
    *   Enable actions like `findone` and `update`.
    *   Ensure the default `GET /api/users/me` endpoint is enabled.
    *   Click **Save**.

3.  **API Endpoints:**
    *   **Registration:** `POST /api/auth/local/register`
    *   **Login:** `POST /api/auth/local`
    *   **Get Logged-in User:** `GET /api/users/me`

## 3. Flutter Implementation Steps

### a. Load Environment Variables

In `main.dart`, load the `.env` file.

```dart
// main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  // ... rest of your main function
}
```

### b. Update the User Model

Update `packages/user_repo/lib/src/models/user.dart` to include all necessary fields.

```dart
// packages/user_repo/lib/src/models/user.dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User(this.id, {this.username, this.email});

  final String id;
  final String? username;
  final String? email;

  @override
  List<Object?> get props => [id, username, email];

  static const empty = User('-');

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      json['id'].toString(),
      username: json['username'],
      email: json['email'],
    );
  }
}
```

### c. Create an API Service

Create a service at `lib/services/api_service.dart` to handle Strapi communication.

```dart
// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String _baseUrl = "https://tronngarage.com/strapi/api";

  // User Login
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identifier': identifier, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', data['jwt']);
      return data;
    } else {
      throw Exception('Failed to log in');
    }
  }

  // User Registration
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', data['jwt']);
      return data;
    } else {
      throw Exception('Failed to register');
    }
  }
}
```

### d. Integrate API Service with AuthenticationRepository

Modify `packages/auth_repo/lib/src/auth_repo.dart` to use the `ApiService`.

```dart
// packages/auth_repo/lib/src/auth_repo.dart
import 'dart:async';
import 'package:user_repo/user_repo.dart';
import 'package:flutter_login/services/api_service.dart'; // Adjust import
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationRepository {
  final _controller = StreamController<AuthenticationStatus>();
  final ApiService _apiService;
  User? _user;

  AuthenticationRepository({required ApiService apiService}) : _apiService = apiService;

  Stream<AuthenticationStatus> get status async* {
    yield AuthenticationStatus.unauthenticated;
    yield* _controller.stream;
  }

  Future<void> logIn({required String username, required String password}) async {
    try {
      final response = await _apiService.login(username, password);
      _user = User.fromJson(response['user']);
      _controller.add(AuthenticationStatus.authenticated);
    } catch (e) {
      _controller.add(AuthenticationStatus.unauthenticated);
    }
  }

  Future<void> register({required String username, required String email, required String password}) async {
    try {
      final response = await _apiService.register(username, email, password);
      _user = User.fromJson(response['user']);
      _controller.add(AuthenticationStatus.authenticated);
    } catch (e) {
      // Handle registration failure, maybe rethrow a specific exception
      throw Exception('Registration failed');
    }
  }

  void logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    _user = null;
    _controller.add(AuthenticationStatus.unauthenticated);
  }

  User? get currentUser => _user;

  void dispose() => _controller.close();
}
```

### e. Implement User Registration Feature

We will create a new, self-contained `register` feature.

**1. Create Registration BLoC:**

Create a new directory `lib/register/bloc`. Inside, create the following files. You will also need a new `Email` model in `lib/register/models/email.dart`.

*   `lib/register/models/email.dart`:
    ```dart
    import 'package:formz/formz.dart';

    enum EmailValidationError { invalid }

    class Email extends FormzInput<String, EmailValidationError> {
      const Email.pure() : super.pure('');
      const Email.dirty([super.value = '']) : super.dirty();

      static final _emailRegExp = RegExp(r'^[a-zA-Z0-9.!#$%&\'\'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');

      @override
      EmailValidationError? validator(String? value) {
        return _emailRegExp.hasMatch(value ?? '') ? null : EmailValidationError.invalid;
      }
    }
    ```

*   `lib/register/bloc/register_event.dart`:
    ```dart
    part of 'register_bloc.dart';

    sealed class RegisterEvent extends Equatable {
      const RegisterEvent();
      @override
      List<Object> get props => [];
    }

    final class RegisterUsernameChanged extends RegisterEvent {
      const RegisterUsernameChanged(this.username);
      final String username;
      @override
      List<Object> get props => [username];
    }

    final class RegisterEmailChanged extends RegisterEvent {
      const RegisterEmailChanged(this.email);
      final String email;
      @override
      List<Object> get props => [email];
    }

    final class RegisterPasswordChanged extends RegisterEvent {
      const RegisterPasswordChanged(this.password);
      final String password;
      @override
      List<Object> get props => [password];
    }

    final class RegisterSubmitted extends RegisterEvent {
      const RegisterSubmitted();
    }
    ```

*   `lib/register/bloc/register_state.dart`:
    ```dart
    part of 'register_bloc.dart';

    final class RegisterState extends Equatable {
      const RegisterState({
        this.status = FormzSubmissionStatus.initial,
        this.username = const Username.pure(),
        this.email = const Email.pure(),
        this.password = const Password.pure(),
        this.isValid = false,
      });

      final FormzSubmissionStatus status;
      final Username username;
      final Email email;
      final Password password;
      final bool isValid;

      RegisterState copyWith({
        FormzSubmissionStatus? status,
        Username? username,
        Email? email,
        Password? password,
        bool? isValid,
      }) {
        return RegisterState(
          status: status ?? this.status,
          username: username ?? this.username,
          email: email ?? this.email,
          password: password ?? this.password,
          isValid: isValid ?? this.isValid,
        );
      }

      @override
      List<Object> get props => [status, username, email, password];
    }
    ```

*   `lib/register/bloc/register_bloc.dart`:
    ```dart
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

      void _onUsernameChanged(RegisterUsernameChanged event, Emitter<RegisterState> emit) {
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

      void _onPasswordChanged(RegisterPasswordChanged event, Emitter<RegisterState> emit) {
        final password = Password.dirty(event.password);
        emit(state.copyWith(
          password: password,
          isValid: Formz.validate([state.username, state.email, password]),
        ));
      }

      Future<void> _onSubmitted(RegisterSubmitted event, Emitter<RegisterState> emit) async {
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
    ```

**2. Create Registration View:**

Create a new directory `lib/register/view` and add the following files.

*   `lib/register/view/register_page.dart`:
    ```dart
    import 'package:auth_repo/auth_repo.dart';
    import 'package:flutter/material.dart';
    import 'package:flutter_bloc/flutter_bloc.dart';
    import 'package:flutter_login/register/register.dart';

    class RegisterPage extends StatelessWidget {
      const RegisterPage({super.key});

      static Route<void> route() {
        return MaterialPageRoute<void>(builder: (_) => const RegisterPage());
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Register')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: BlocProvider(
              create: (context) => RegisterBloc(
                authenticationRepository: context.read<AuthenticationRepository>(),
              ),
              child: const RegisterForm(),
            ),
          ),
        );
      }
    }
    ```

*   `lib/register/view/register_form.dart`:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_bloc/flutter_bloc.dart';
    import 'package:flutter_login/register/register.dart';
    import 'package:formz/formz.dart';

    class RegisterForm extends StatelessWidget {
      const RegisterForm({super.key});

      @override
      Widget build(BuildContext context) {
        return BlocListener<RegisterBloc, RegisterState>(
          listener: (context, state) {
            if (state.status.isFailure) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Registration Failure')),
                );
            }
          },
          child: Align(
            alignment: const Alignment(0, -1 / 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UsernameInput(),
                const Padding(padding: EdgeInsets.all(12)),
                _EmailInput(),
                const Padding(padding: EdgeInsets.all(12)),
                _PasswordInput(),
                const Padding(padding: EdgeInsets.all(12)),
                _RegisterButton(),
              ],
            ),
          ),
        );
      }
    }
    // ... Implement _UsernameInput, _EmailInput, _PasswordInput, and _RegisterButton widgets
    // similar to the ones in lib/login/view/login_form.dart, but connected to the RegisterBloc.
    ```

**3. Update UI for Navigation:**

Finally, add a button to the `LoginForm` to allow users to navigate to the registration page.

*   Modify `lib/login/view/login_form.dart`:
    ```dart
    // In the build method of LoginForm, after the _LoginButton
    // ...
    _LoginButton(),
    const Padding(padding: EdgeInsets.all(12)),
    _RegisterAccountButton(),
    // ...

    // Add this new widget to the file
    class _RegisterAccountButton extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return TextButton(
          key: const Key('loginForm_createAccount_flatButton'),
          onPressed: () => Navigator.of(context).push(RegisterPage.route()),
          child: const Text('Create an Account'),
        );
      }
    }
    ```

By following these steps, you will have a complete login and registration flow integrated with your Strapi backend and managed correctly with the BLoC pattern.