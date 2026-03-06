
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/api_service.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<void> login(String email, String password) async {
    final response = await _apiService.post('/auth/login', {
      'email': email,
      'password': password,
    });
    
    // Save token and userId
    final token = response['access_token'];
    final userId = response['user']['id'];
    final address = response['user']['address'] ?? '';
    final phone = response['user']['phone'] ?? '';
    final cardInfo = response['user']['cardInfo'] ?? '';
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userId', userId.toString());
    await prefs.setString('userEmail', email);
    await prefs.setString('userAddress', address);
    await prefs.setString('userPhone', phone);
    await prefs.setString('userCardInfo', cardInfo);
  }
}
