import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl = dotenv.env['STRAPI_URL'] ?? "";
  final _storage = const FlutterSecureStorage();

  /* ApiService() : _baseUrl = _getStrapiBaseUrl();

  static String _getStrapiBaseUrl() {
    final url = dotenv.env['STRAPI_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('STRAPI_URL is not defined in the .env file or is empty.');
    }
    return url;
  } */
  //final _storage = const FlutterSecureStorage();

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

  // Fetch logged in user
Future<Map<String, dynamic>> fetchLoggedInUser() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      throw Exception('No JWT token found');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'), // The Strapi endpoint for the logged-in user
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Token might be expired or invalid
      await _storage.delete(key: 'jwt'); // Clear invalid token
      throw Exception('Unauthorized: Token expired or invalid');
    } else {
      throw Exception('Failed to fetch user: ${response.statusCode}');
    }
  }
}


