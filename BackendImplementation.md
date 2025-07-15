# Strapi Backend Implementation Guide

This document outlines the steps to integrate the Flutter application with a Strapi backend, including user registration, secure token storage, and proper state management using the existing BLoC pattern.

## 1. Data Persistence Strategy

When handling data in a Flutter application, it's crucial to distinguish between sensitive information and general user preferences. This project adopts the following strategy:

*   **`flutter_secure_storage`**: For all sensitive data, such as authentication tokens (JWT). This plugin utilizes platform-native secure storage mechanisms like Keychain on iOS and Keystore on Android, providing a secure place to store credentials.
*   **`shared_preferences`**: For non-sensitive, simple key-value data, such as user preferences (e.g., theme settings, language choice). This data is not guaranteed to be encrypted and should not be used for storing secrets.

## 2. Additional Libraries Needed

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.1
  flutter_dotenv: ^5.1.0
  flutter_secure_storage: ^9.1.1 # For secure storage of tokens (iOS Keychain, Android Keystore)
  shared_preferences: ^2.2.3 # For non-sensitive user preferences (e.g., theme)
```

## 3. Strapi Backend Configuration

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

## 4. Flutter Implementation Steps

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

Update `packages/user_repo/lib/src/models/user.dart` to include all necessary fields from your Strapi user collection. For example, if your collection has custom fields like `fullName` or `profilePictureUrl`, add them to the `User` class and the `fromJson` factory.

```dart
// packages/user_repo/lib/src/models/user.dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.documentId,
    this.firstName,
    this.lastName,
    this.email,
    this.profilePic,
  });

  final String id;
  final String documentId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? profilePic;

  @override
  List<Object?> get props =>
      [id, documentId, firstName, lastName, email, profilePic];

  static const empty = User(id: '-', documentId: '-');

  factory User.fromJson(Map<String, dynamic> json) {
    // Strapi can return profilePic as null or as an object with a url
    final profilePicData = json['profilePic'];
    final profilePicUrl = profilePicData is Map ? profilePicData['url'] : null;

    return User(
      id: json['id'].toString(),
      documentId: json['documentId'] ?? json['id'].toString(), // Fallback for documentId
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      profilePic: profilePicUrl,
    );
  }
}
```

### c. Create an API Service

Create a service at `lib/services/api_service.dart` to handle Strapi communication. This service will use `flutter_secure_storage` to persist the JWT.

```dart
// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl = dotenv.env['STRAPI_URL'] ?? 'http://localhost:1337/api';
  final _storage = const FlutterSecureStorage();

  // User Login
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identifier': identifier, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'jwt', value: data['jwt']);
      return data;
    } else {
      throw Exception('Failed to log in');
    }
  }

  // User Registration
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'jwt', value: data['jwt']);
      return data;
    } else {
      throw Exception('Failed to register');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt');
  }
}
```

### d. Integrate API Service with AuthenticationRepository

Modify `packages/auth_repo/lib/src/auth_repo.dart` to use the `ApiService` and clear the token from secure storage on logout.

```dart
// packages/auth_repo/lib/src/auth_repo.dart
import 'dart:async';
import 'package:flutter_login/services/api_service.dart';
import 'package:user_repo/user_repo.dart';

enum AuthenticationStatus { unknown, authenticated, unauthenticated }

class AuthenticationRepository {
  AuthenticationRepository({required this.apiService});

  final ApiService apiService;
  final _controller = StreamController<AuthenticationStatus>();

  Stream<AuthenticationStatus> get status async* {
    yield AuthenticationStatus.unauthenticated;
    yield* _controller.stream;
  }

  Future<void> logIn({
    required String username,
    required String password,
  }) async {
    try {
      final response = await apiService.login(username, password);
      // Assuming the user data is in response['user']
      // final user = User.fromJson(response['user']);
      _controller.add(AuthenticationStatus.authenticated);
    } catch (e) {
      _controller.add(AuthenticationStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await apiService.register(username, email, password);
      _controller.add(AuthenticationStatus.authenticated);
    } catch (e) {
      _controller.add(AuthenticationStatus.unauthenticated);
    }
  }

  void logOut() {
    apiService.logout();
    _controller.add(AuthenticationStatus.unauthenticated);
  }

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

      static final _emailRegExp =
          RegExp(r'^[a-zA-Z0-9.!#$%&\'\'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*

By following these steps, you will have a complete login and registration flow integrated with your Strapi backend and managed correctly with the BLoC pattern.

## 5. Future Implementation: Managing User Preferences

For non-sensitive data like theme preferences, you can create a separate service that uses `shared_preferences`. This keeps the concerns of authentication and user preferences separate.

Here is an example of how you might implement a `PreferencesService`.

**a. Create a Preferences Service:**

Create a new file `lib/services/preferences_service.dart`.

```dart
// lib/services/preferences_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _themeKey = 'theme_mode';

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => ThemeMode.system, // Default theme
    );
  }
}
```

**b. Using the Service:**

You can then provide and use this service throughout your application to manage the theme.

```dart
// Example of saving the theme
final preferencesService = PreferencesService();
await preferencesService.saveThemeMode(ThemeMode.dark);

// Example of loading the theme when the app starts
final initialTheme = await preferencesService.getThemeMode();
// Use this value to set the initial theme in your MaterialApp
```);

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
    ```

**2. Create Registration View:**

Create a new directory `lib/register/view` and add the following files.

*   `lib/register/view/register_page.dart`:
    ```dart
    import 'package:auth_repo/auth_repo.dart';
    import 'package:flutter/material.dart';
    import 'package:flutter_bloc/flutter_bloc.dart';
    import 'package:flutter_login/register/register.dart';
    import 'package:flutter_login/register/bloc/register_bloc.dart';
    import 'package:flutter_login/register/view/register_form.dart';

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
    import 'package:flutter_login/register/bloc/register_bloc.dart';
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

    class _UsernameInput extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return BlocBuilder<RegisterBloc, RegisterState>(
          buildWhen: (previous, current) => previous.username != current.username,
          builder: (context, state) {
            return TextField(
              key: const Key('registerForm_usernameInput_textField'),
              onChanged: (username) =>
                  context.read<RegisterBloc>().add(RegisterUsernameChanged(username)),
              decoration: InputDecoration(
                labelText: 'username',
                errorText: state.username.displayError != null ? 'invalid username' : null,
              ),
            );
          },
        );
      }
    }

    class _EmailInput extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return BlocBuilder<RegisterBloc, RegisterState>(
          buildWhen: (previous, current) => previous.email != current.email,
          builder: (context, state) {
            return TextField(
              key: const Key('registerForm_emailInput_textField'),
              onChanged: (email) =>
                  context.read<RegisterBloc>().add(RegisterEmailChanged(email)),
              decoration: InputDecoration(
                labelText: 'email',
                errorText: state.email.displayError != null ? 'invalid email' : null,
              ),
            );
          },
        );
      }
    }

    class _PasswordInput extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return BlocBuilder<RegisterBloc, RegisterState>(
          buildWhen: (previous, current) => previous.password != current.password,
          builder: (context, state) {
            return TextField(
              key: const Key('registerForm_passwordInput_textField'),
              onChanged: (password) =>
                  context.read<RegisterBloc>().add(RegisterPasswordChanged(password)),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'password',
                errorText: state.password.displayError != null ? 'invalid password' : null,
              ),
            );
          },
        );
      }
    }

    class _RegisterButton extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return BlocBuilder<RegisterBloc, RegisterState>(
          builder: (context, state) {
            return state.status.isInProgress
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    key: const Key('registerForm_continue_raisedButton'),
                    onPressed: state.isValid
                        ? () {
                            context.read<RegisterBloc>().add(const RegisterSubmitted());
                          }
                        : null,
                    child: const Text('Register'),
                  );
          },
        );
      }
    }
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

## 5. Future Implementation: Managing User Preferences

For non-sensitive data like theme preferences, you can create a separate service that uses `shared_preferences`. This keeps the concerns of authentication and user preferences separate.

Here is an example of how you might implement a `PreferencesService`.

**a. Create a Preferences Service:**

Create a new file `lib/services/preferences_service.dart`.

```dart
// lib/services/preferences_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _themeKey = 'theme_mode';

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeMode.name);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => ThemeMode.system, // Default theme
    );
  }
}
```

**b. Using the Service:**

You can then provide and use this service throughout your application to manage the theme.

```dart
// Example of saving the theme
final preferencesService = PreferencesService();
await preferencesService.saveThemeMode(ThemeMode.dark);

// Example of loading the theme when the app starts
final initialTheme = await preferencesService.getThemeMode();
// Use this value to set the initial theme in your MaterialApp
```

current
lib
├── app.dart
├── auth
│   ├── auth.dart
│   └── bloc
│       ├── auth_bloc.dart
│       ├── auth_event.dart
│       └── auth_state.dart
├── home
│   ├── home.dart
│   └── view
│       └── home_page.dart
├── login
│   ├── bloc
│   │   ├── login_bloc.dart
│   │   ├── login_event.dart
│   │   └── login_state.dart
│   ├── login.dart
│   ├── models
│   │   ├── models.dart
│   │   ├── password.dart
│   │   └── username.dart
│   └── view
│       ├── login_form.dart
│       ├── login_page.dart
│       └── view.dart
├── main.dart
├── register
│   ├── bloc
│   │   ├── register_bloc.dart
│   │   ├── register_event.dart
│   │   └── register_state.dart
│   ├── models
│   │   └── email.dart
│   ├── register.dart
│   └── view
│       ├── register_form.dart
│       └── register_page.dart
├── services
│   └── api_service.dart
└── splash
    ├── splash.dart
    └── view
        └── splash_page.dart

.packages
├── auth_repo
│   ├── lib
│   │   ├── auth_repo.dart
│   │   └── src
│   │       └── auth_repo.dart
│   ├── pubspec.lock
│   └── pubspec.yaml
└── user_repo
    ├── lib
    │   ├── src
    │   │   ├── models
    │   │   │   ├── models.dart
    │   │   │   └── user.dart
    │   │   └── user_repo.dart
    │   └── user_repo.dart
    ├── pubspec.lock
    └── pubspec.yaml

i need lib/services/api_services.dart imported in packages/user_repo/src/user_repo.dart what is the proper way to do this? should services also be a package?

contents of api_services.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl;

  ApiService() : _baseUrl = _getStrapiBaseUrl();

  static String _getStrapiBaseUrl() {
    final url = dotenv.env['STRAPI_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('STRAPI_URL is not defined in the .env file or is empty.');
    }
    return url;
  }
  final _storage = const FlutterSecureStorage();

  // User Login
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identifier': identifier, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'jwt', value: data['jwt']);
      return data;
    } else {
      throw Exception('Failed to log in');
    }
  }

  // User Registration
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/local/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'jwt', value: data['jwt']);
      return data;
    } else {
      throw Exception('Failed to register');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt');
  }
}


contents of packages/user_repo/src/user_repo.dart
// packages/user_repo/lib/src/user_repo.dart
import 'dart:async';
import 'package:user_repo/src/models/models.dart';
import 'package:flutter_login/services/api_service.dart'; // Import the ApiService

class UserRepository {
  UserRepository({required this.apiService}); // Add ApiService as a dependency

  final ApiService apiService; // Store the ApiService instance
  User? _user; // Keep track of the current user

  /// Retrieves the current user from the backend.
  /// If a user is already cached, it returns the cached user.
  /// Otherwise, it fetches the user data from Strapi using the ApiService.
  Future<User?> getUser() async {
    if (_user != null) return _user;

    try {
      final token = await apiService.getToken();
      if (token == null) {
        // No token, no authenticated user
        _user = User.empty; // Set to empty user or null as per your app's logic
        return _user;
      }

      final userData = await apiService.fetchLoggedInUser(); // Assuming a new method in ApiService
      _user = User.fromJson(userData);
      return _user;
    } catch (e) {
      // Handle error, e.g., token expired, network issue
      print('Error fetching user: $e');
      _user = User.empty; // Or set to null to indicate no user
      return _user;
    }
  }

  /// Clears the cached user.
  void clearUser() {
    _user = null;
  }
}