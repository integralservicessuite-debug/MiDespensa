
import '../../../shared/services/api_service.dart';

class StoreRepository {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>?> getStoreSettings() async {
    try {
      final response = await _apiService.get('/store');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Failed to load store settings: $e');
      return null;
    }
  }
}
