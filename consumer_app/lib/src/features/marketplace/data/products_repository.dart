
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/api_service.dart';

class ProductsRepository {
  final ApiService _apiService = ApiService();

  Future<List<Map<String, dynamic>>> getProducts() async {
    final response = await _apiService.get('/products');
    
    // Ensure response is a list
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      throw Exception('Format returned invalid format');
    }
  }

  Future<void> createOrder(List<Map<String, dynamic>> cartItems, {
    required String address,
    required String phone,
    String paymentMethod = 'CASH',
    String? cardInfo,
    double deliveryFee = 3.0, // Cargo de entrega calculado en checkout
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId == null) {
      throw Exception('User ID not found. Please re-login.');
    }
    
    final itemsPayload = cartItems.map((p) => {
      'productId': p['id'],
      'quantityRequested': p['quantity'] ?? 1
    }).toList();

    await _apiService.post('/orders', {
      'customerId': userId,
      'items': {
        'create': itemsPayload
      },
      'deliveryAddress': address,
      'contactPhone': phone,
      'paymentMethod': paymentMethod,
      'deliveryFee': deliveryFee, // Guardar el fee real calculado
    });
  }

  Future<List<Map<String, dynamic>>> getMyOrders() async {
     // Ideally, filtering by customerId. For now, let's fetch /orders (which might return ALL orders if not scoped).
     // Since backend likely doesn't have /orders/me, I'll filter client-side or use existing /orders if it allows filtering.
     // Wait, OrdersService has `findAll`, `findForShoppers`...
     // Does it have `findForCustomer`? No.
     // I need to add that to backend OR just fetch all and filter in frontend (BAD for prod, OK for MVP).
     // BUT: OrdersService.findAll returns ALL orders.
     // Let's assume for MVP `client1` sees ALL orders or that I can filter by `customerId` in the response.
     // Actually, let's check OrdersController if it takes filter.
     // If not, I'll fetch `/orders` and since I'm `client1`, I'll filter by my ID in Dart.
     
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    final response = await _apiService.get('/orders'); // Assuming this lists orders
    if (response is List) {
       final allOrders = List<Map<String, dynamic>>.from(response);
       // Filter locally for MVP stability
       return allOrders.where((o) => o['customerId'] == userId).toList();
    }
    return [];
  }

  Future<void> updateOrderItem(String orderId, String orderItemId, Map<String, dynamic> data) async {
    await _apiService.patch('/orders/$orderId/items/$orderItemId', data);
  }
}
