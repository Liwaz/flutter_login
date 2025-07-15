// packages/user_repo/lib/src/user_repo.dart
import 'dart:async';
import 'package:user_repo/src/models/models.dart';
import 'package:api_service/api_service.dart';

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