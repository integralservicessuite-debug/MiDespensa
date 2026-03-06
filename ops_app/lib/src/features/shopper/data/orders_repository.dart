
import '../../../shared/services/api_service.dart';

class OrdersRepository {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> getOrdersForShopper() async {
    final response = await _apiService.get('/orders/shopper');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    throw Exception('Invalid format');
  }

  Future<List<Map<String, dynamic>>> getOrdersForDriver() async {
    final response = await _apiService.get('/orders/driver');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    throw Exception('Invalid format');
  }

  Future<List<Map<String, dynamic>>> getOrdersForDriverCompleted() async {
    final response = await _apiService.get('/orders/driver/completed');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    throw Exception('Invalid format');
  }

  Future<List<Map<String, dynamic>>> getAvailableBatches() async {
    final response = await _apiService.get('/orders/driver/available-batches');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    throw Exception('Invalid format');
  }

  Future<Map<String, dynamic>> acceptBatch(String driverId, List<String> orderIds) async {
    final response = await _apiService.post('/orders/driver/accept-batch', {
      'driverId': driverId,
      'orderIds': orderIds,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> updateStatus(String orderId, String status) async {
    await _apiService.patch('/orders/$orderId', {
      'status': status,
    });
  }

  Future<void> updateOrderItem(String orderId, String orderItemId, Map<String, dynamic> data) async {
    await _apiService.patch('/orders/$orderId/items/$orderItemId', data);
  }
}
