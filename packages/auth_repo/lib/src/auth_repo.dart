
import 'dart:async';
//import 'package:flutter_login/services/api_service.dart';
import 'package:api_service/api_service.dart';

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
      print(response);
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
