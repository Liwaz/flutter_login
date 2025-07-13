import 'dart:async';

import 'package:user_repo/src/models/models.dart';
import 'package:uuid/uuid.dart';


/// For this simple example, the UserRepository exposes a single method 
/// getUser which will retrieve the current user. 
/// We are stubbing this but in practice 
/// this is where we would query the current user from the backend.

class UserRepository {
  User? _user;

  Future<User?> getUser() async {
    if (_user != null) return _user;
    return Future.delayed(
      const Duration(milliseconds: 300),
      () => _user = User(const Uuid().v4()),
    );
  }
}