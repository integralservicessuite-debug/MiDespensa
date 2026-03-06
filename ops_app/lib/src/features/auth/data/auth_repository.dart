
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/api_service.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<void> login(String email, String password) async {
    final response = await _apiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    // Save token
    final token = response['access_token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
}
