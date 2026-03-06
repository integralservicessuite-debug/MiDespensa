import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/products_repository.dart';
import '../../../shared/config/app_config.dart';
import '../data/store_repository.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/services/api_service.dart';

// Helper class for cart items with quantity
class CartItem {
  final Map<String, dynamic> product;
  int quantity;
  
  CartItem({required this.product, this.quantity = 1});
  
  double get totalPrice {
    final price = product['price'];
    final priceValue = price is num ? price.toDouble() : double.tryParse(price.toString()) ?? 0.0;
    return priceValue * quantity;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}



class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<String, dynamic>? _storeConfig;
  
  late IO.Socket socket;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  int _selectedIndex = 0;
  final Map<String, CartItem> _cart = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _productsFuture = ref.read(productsRepositoryProvider).getProducts();
    _loadStoreInfo();
    _initNotificationsAndSocket();
    _loadCart();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  Future<void> _initNotificationsAndSocket() async {
    if (!kIsWeb) {
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
      const initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
      try {
        await (flutterLocalNotificationsPlugin as dynamic).initialize(initializationSettings);
      } catch (_) {}
    }

    socket = IO.io('https://midespensa.onrender.com', IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());
        
    socket.connect();
    socket.on('pushNotification', (data) {
      if (mounted) {
        _showNotification(data['title'] ?? 'MiDespensa', data['body'] ?? 'Tienes una nueva actualización');
        // Refresh products and UI if we get a push notification
        setState(() {});
      }
    });
  }

  Future<void> _showNotification(String title, String body) async {
    if (!kIsWeb) {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'midespensa_customer', 'Alertas de Consumidor',
        importance: Importance.max, priority: Priority.high, showWhen: true);
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
      try {
        await (flutterLocalNotificationsPlugin as dynamic).show(DateTime.now().millisecond, title, body, platformChannelSpecifics);
      } catch (_) {}
    }
  }

  Future<void> _loadStoreInfo() async {
    final config = await ref.read(storeRepositoryProvider).getStoreSettings();
    if (mounted && config != null) {
      setState(() {
        _storeConfig = config;
      });
    }
    
    // Load products for search filtering
    try {
      final products = await _productsFuture;
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  // Load cart from SharedPreferences
  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart');
      if (cartJson != null) {
        final Map<String, dynamic> cartData = json.decode(cartJson);
        setState(() {
          _cart.clear();
          cartData.forEach((productId, itemData) {
            _cart[productId] = CartItem(
              product: itemData['product'],
              quantity: itemData['quantity'],
            );
          });
        });
        print('✅ Cart loaded: ${_cart.length} items');
      }
    } catch (e) {
      print('Error loading cart: $e');
    }
  }

  // Save cart to SharedPreferences
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = _cart.map((key, cartItem) => MapEntry(
        key,
        {
          'product': cartItem.product,
          'quantity': cartItem.quantity,
        },
      ));
      final jsonString = json.encode(cartData);
      final success = await prefs.setString('cart', jsonString);
      print('💾 Cart save ${success ? "SUCCESS" : "FAILED"}: ${_cart.length} items');
      print('   JSON length: ${jsonString.length} chars');
    } catch (e) {
      print('❌ Error saving cart: $e');
    }
  }

  // Handle search query changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final name = (product['name'] as String).toLowerCase();
          final category = (product['category'] as String? ?? '').toLowerCase();
          return name.contains(_searchQuery) || category.contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    final productId = product['id'];
    
    // Store previous quantity for undo
    final previousQuantity = _cart.containsKey(productId) ? _cart[productId]!.quantity : 0;
    
    setState(() {
      if (_cart.containsKey(productId)) {
        _cart[productId]!.quantity++;
      } else {
        _cart[productId] = CartItem(product: product);
      }
    });
    
    // Save cart to persistence
    _saveCart();
    
    // Remove any existing SnackBars
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show new SnackBar with auto-dismiss
    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} agregado al carrito'),
        duration: Duration(seconds: AppConfig.snackBarDurationSeconds),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'DESHACER',
          onPressed: () {
            setState(() {
              if (previousQuantity == 0) {
                _cart.remove(productId);
              } else {
                _cart[productId]!.quantity = previousQuantity;
              }
            });
            _saveCart(); // Save after undo
          },
        ),
      ),
    );

    // Forzar el ocultamiento tras el timer (evita el bug de Web hover loop infinito)
    Future.delayed(Duration(seconds: AppConfig.snackBarDurationSeconds), () {
      if (mounted) {
        snackBarController.close();
      }
    });
  }

  Future<void> _showCartReview() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!')),
      );
      return;
    }

    final shouldCheckout = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green),
              SizedBox(width: 10),
              Text('Carrito de Compras'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final productId = _cart.keys.elementAt(index);
                      final cartItem = _cart[productId]!;
                      final product = cartItem.product;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              // Product icon
                              const Icon(Icons.shopping_bag, size: 40, color: Colors.green),
                              const SizedBox(width: 12),
                              // Product info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('\$${product['price']} c/u', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    Text('Subtotal: \$${cartItem.totalPrice.toStringAsFixed(2)}', 
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              // Quantity controls
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      setDialogState(() {
                                        setState(() {
                                          if (cartItem.quantity > 1) {
                                            cartItem.quantity--;
                                          }
                                        });
                                      });
                                    },
                                  ),
                                  Text('${cartItem.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () {
                                      setDialogState(() {
                                        setState(() {
                                          cartItem.quantity++;
                                        });
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    setState(() {
                                      _cart.remove(productId);
                                    });
                                  });
                                  if (_cart.isEmpty) {
                                    Navigator.pop(ctx, false);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 20),
                Text(
                  'Total: \$${_cart.values.fold<double>(0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar Comprando'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Proceder al Checkout'),
            ),
          ],
        ),
      ),
    );

    if (shouldCheckout == true) {
      _checkout();
    }
  }

  // Calculate delivery fee based on distance
  double _calculateDeliveryFee(double distanceMiles, double subtotal) {
    // Service fee: 10% of subtotal
    final serviceFee = subtotal * 0.10;
    
    // Distance-based delivery fee
    double deliveryFee;
    if (distanceMiles <= 3) {
      deliveryFee = 3.0; // Minimum $3 for first 3 miles
    } else {
      deliveryFee = 3.0 + ((distanceMiles - 3) * 1.0); // $1 per additional mile
    }
    
    return serviceFee + deliveryFee;
  }
  
  // Calculate distance using Haversine formula
  double _calculateDistanceFromCoords(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + 
              cos(lat1 * p) * cos(lat2 * p) * 
              (1 - cos((lon2 - lon1) * p)) / 2;
    final distanceKm = 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
    return distanceKm * 0.621371; // Convert to miles
  }
  
  // Calculate distance between two addresses using geocoding
  Future<double> _calculateDistance(String storeAddress, String customerAddress) async {
    print('🔍 Attempting geocoding...');
    print('   Store: $storeAddress');
    print('   Customer: $customerAddress');
    print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
    
    // Validate addresses are not empty
    if (storeAddress.trim().isEmpty || customerAddress.trim().isEmpty) {
      throw Exception('Empty address provided');
    }
    
    if (kIsWeb) {
      // Use REST API for web
      return await _calculateDistanceWeb(storeAddress, customerAddress);
    } else {
      // Use native geocoding for mobile
      return await _calculateDistanceMobile(storeAddress, customerAddress);
    }
  }
  
  // Web implementation using Google Maps Geocoding REST API
  Future<double> _calculateDistanceWeb(String storeAddress, String customerAddress) async {
    const apiKey = 'AIzaSyDUVnxsIM2zhB5qP3CUrS_aiASuZKjuILM';
    
    print('📡 Calling Google Maps REST API...');
    
    // Geocode store address
    final storeUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(storeAddress)}&key=$apiKey';
    final storeResponse = await Dio().get(storeUrl);
    final storeData = storeResponse.data is String ? json.decode(storeResponse.data) : storeResponse.data;
    
    if (storeData['status'] != 'OK' || storeData['results'].isEmpty) {
      throw Exception('Failed to geocode store address: ${storeData['status']}');
    }
    
    // Geocode customer address
    final customerUrl = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(customerAddress)}&key=$apiKey';
    final customerResponse = await Dio().get(customerUrl);
    final customerData = customerResponse.data is String ? json.decode(customerResponse.data) : customerResponse.data;
    
    if (customerData['status'] != 'OK' || customerData['results'].isEmpty) {
      throw Exception('Failed to geocode customer address: ${customerData['status']}');
    }
    
    final storeLat = storeData['results'][0]['geometry']['location']['lat'];
    final storeLng = storeData['results'][0]['geometry']['location']['lng'];
    final customerLat = customerData['results'][0]['geometry']['location']['lat'];
    final customerLng = customerData['results'][0]['geometry']['location']['lng'];
    
    print('📍 Coordinates:');
    print('   Store: $storeLat, $storeLng');
    print('   Customer: $customerLat, $customerLng');
    
    final distance = _calculateDistanceFromCoords(storeLat, storeLng, customerLat, customerLng);
    print('✅ Distance calculated: ${distance.toStringAsFixed(2)} miles');
    
    return distance;
  }
  
  // Mobile implementation using native geocoding package
  Future<double> _calculateDistanceMobile(String storeAddress, String customerAddress) async {
    print('📡 Calling native geocoding...');
    
    final storeLocations = await locationFromAddress(storeAddress);
    final customerLocations = await locationFromAddress(customerAddress);
    
    print('✅ Geocoding response received');
    print('   Store locations: ${storeLocations.length}');
    print('   Customer locations: ${customerLocations.length}');
    
    if (storeLocations.isEmpty || customerLocations.isEmpty) {
      throw Exception('Geocoding returned no results');
    }
    
    final storeLoc = storeLocations.first;
    final customerLoc = customerLocations.first;
    
    print('📍 Coordinates:');
    print('   Store: ${storeLoc.latitude}, ${storeLoc.longitude}');
    print('   Customer: ${customerLoc.latitude}, ${customerLoc.longitude}');
    
    final distance = _calculateDistanceFromCoords(
      storeLoc.latitude, 
      storeLoc.longitude,
      customerLoc.latitude,
      customerLoc.longitude
    );
    
    print('✅ Distance calculated: ${distance.toStringAsFixed(2)} miles');
    return distance;
  }

  Widget _buildReceiptRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _checkout() async {
    String? cardInfoToProcess; // Para guardar la informacion del form de tarjeta temporalmente
    
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty!')),
      );
      return;
    }

    // FORCE inject mock data for client1 BEFORE reading
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail') ?? '';
    
    print('🔍 Current userEmail: "$userEmail"');
    
    // ALWAYS inject for testing (remove condition)
    await prefs.setString('userAddress', '2858 Paprika Dr, Orlando, FL 32837');
    await prefs.setString('userPhone', '1234567890');
    await prefs.setString('userCardInfo', '{"number":"4111"}');
    print('✅ Mock data FORCE injected for testing');

    // Checkout Form
    final savedAddress = prefs.getString('userAddress') ?? '';
    final savedPhone = prefs.getString('userPhone') ?? '';
    final savedCard = prefs.getString('userCardInfo') ?? '';
    
    print('📋 Reading from prefs:');
    print('   Address: "$savedAddress"');
    print('   Phone: "$savedPhone"');
    print('   Card: "$savedCard"');

    final addressController = TextEditingController(text: savedAddress);
    final phoneController = TextEditingController(text: savedPhone);
    String selectedPayment = 'EFECTIVO';
    double capturedDeliveryFee = 3.0; // Se actualizará con el valor real del FutureBuilder
    
    // Tarjeta state variables
    String cardNumber = '';
    String expiryDate = '';
    String cardHolderName = '';
    String cvvCode = '';
    bool isCvvFocused = false;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    if (savedCard.isNotEmpty) {
      try {
         final cardData = jsonDecode(savedCard);
         if (cardData['number'] != null) cardNumber = cardData['number'];
         if (cardData['expiryDate'] != null) expiryDate = cardData['expiryDate'];
         if (cardData['cardHolderName'] != null) cardHolderName = cardData['cardHolderName'];
         if (cardData['cvvCode'] != null) cvvCode = cardData['cvvCode'];
      } catch (_) {}
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateForm) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Finalizar Compra', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, false),
                      )
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20, right: 20, top: 20,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         const Text('Datos de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 12),
                         TextField(
                           controller: addressController,
                           decoration: InputDecoration(
                             labelText: 'Dirección de Entrega',
                             prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)),
                             filled: true,
                             fillColor: Colors.grey.shade50,
                           ),
                         ),
                         const SizedBox(height: 12),
                         TextField(
                           controller: phoneController,
                           decoration: InputDecoration(
                             labelText: 'Teléfono de Contacto',
                             prefixIcon: const Icon(Icons.phone, color: Colors.green),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)),
                             filled: true,
                             fillColor: Colors.grey.shade50,
                           ),
                           keyboardType: TextInputType.phone,
                         ),
                         const SizedBox(height: 24),
                         const Text('Forma de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             Expanded(
                               child: GestureDetector(
                                 onTap: () => setStateForm(() => selectedPayment = 'EFECTIVO'),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                   decoration: BoxDecoration(
                                     color: selectedPayment == 'EFECTIVO' ? Colors.green.shade50 : Colors.white,
                                     border: Border.all(color: selectedPayment == 'EFECTIVO' ? Colors.green : Colors.grey.shade300, width: selectedPayment == 'EFECTIVO' ? 2 : 1),
                                     borderRadius: BorderRadius.circular(12)
                                   ),
                                   child: Column(
                                     children: [
                                       Icon(Icons.money, color: selectedPayment == 'EFECTIVO' ? Colors.green : Colors.grey),
                                       const SizedBox(height: 4),
                                       Text('Efectivo', style: TextStyle(color: selectedPayment == 'EFECTIVO' ? Colors.green : Colors.black87, fontWeight: FontWeight.bold))
                                     ],
                                   ),
                                 ),
                               ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               child: GestureDetector(
                                 onTap: () => setStateForm(() => selectedPayment = 'TARJETA'),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                   decoration: BoxDecoration(
                                     color: selectedPayment == 'TARJETA' ? Colors.green.shade50 : Colors.white,
                                     border: Border.all(color: selectedPayment == 'TARJETA' ? Colors.green : Colors.grey.shade300, width: selectedPayment == 'TARJETA' ? 2 : 1),
                                     borderRadius: BorderRadius.circular(12)
                                   ),
                                   child: Column(
                                     children: [
                                       Icon(Icons.credit_card, color: selectedPayment == 'TARJETA' ? Colors.green : Colors.grey),
                                       const SizedBox(height: 4),
                                       Text('Tarjeta', style: TextStyle(color: selectedPayment == 'TARJETA' ? Colors.green : Colors.black87, fontWeight: FontWeight.bold))
                                     ],
                                   ),
                                 ),
                               ),
                             )
                           ],
                         ),
                         const SizedBox(height: 12),
                         if (selectedPayment == 'TARJETA') 
                            Column(
                              children: [
                                CreditCardWidget(
                                  cardNumber: cardNumber,
                                  expiryDate: expiryDate,
                                  cardHolderName: cardHolderName,
                                  cvvCode: cvvCode,
                                  showBackView: isCvvFocused,
                                  onCreditCardWidgetChange: (CreditCardBrand brand) {},
                                  isHolderNameVisible: true,
                                  cardBgColor: Colors.black87,
                                  labelCardHolder: 'TITULAR',
                                  labelExpiredDate: 'MM/YY',
                                ),
                                CreditCardForm(
                                  formKey: formKey,
                                  obscureCvv: true,
                                  obscureNumber: true,
                                  cardNumber: cardNumber,
                                  cvvCode: cvvCode,
                                  isHolderNameVisible: true,
                                  isCardNumberVisible: true,
                                  isExpiryDateVisible: true,
                                  cardHolderName: cardHolderName,
                                  expiryDate: expiryDate,
                                  inputConfiguration: const InputConfiguration(
                                    cardNumberDecoration: InputDecoration(
                                      labelText: 'Número',
                                      hintText: 'XXXX XXXX XXXX XXXX',
                                      border: OutlineInputBorder(),
                                    ),
                                    expiryDateDecoration: InputDecoration(
                                      labelText: 'Expira',
                                      hintText: 'MM/YY',
                                      border: OutlineInputBorder(),
                                    ),
                                    cvvCodeDecoration: InputDecoration(
                                      labelText: 'CVV',
                                      hintText: 'XXX',
                                      border: OutlineInputBorder(),
                                    ),
                                    cardHolderDecoration: InputDecoration(
                                      labelText: 'Titular de la tarjeta',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  onCreditCardModelChange: (CreditCardModel data) {
                                    setStateForm(() {
                                      cardNumber = data.cardNumber;
                                      expiryDate = data.expiryDate;
                                      cardHolderName = data.cardHolderName;
                                      cvvCode = data.cvvCode;
                                      isCvvFocused = data.isCvvFocused;
                                    });
                                  },
                                ),
                              ],
                            ),

                         const SizedBox(height: 24),
                         Container(
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.grey.shade50,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: Colors.grey.shade200)
                           ),
                           child: FutureBuilder<double>(
                             future: () async {
                               final storeAddress = _storeConfig?['address'] ?? '528 W Vine St, Kissimmee, FL 34741';
                               final customerAddress = addressController.text.isEmpty ? '2858 Paprika Dr, Orlando, FL 32837' : addressController.text;
                               return await _calculateDistance(storeAddress, customerAddress);
                             }(),
                             builder: (context, snapshot) {
                               if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                               }
                               
                               if (snapshot.hasError) {
                                 return Column(
                                   children: [
                                     const Icon(Icons.error_outline, color: Colors.red),
                                     Text('Error calculando distancia', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                                   ],
                                 );
                               }
                               
                               final subtotal = _cart.values.fold<double>(0, (sum, cartItem) => sum + cartItem.totalPrice);
                               final tax = subtotal * 0.075;
                               final serviceFee = subtotal * 0.10;
                               final distance = snapshot.data!;
                               
                               double deliveryFee;
                               if (distance <= 3) {
                                 deliveryFee = 3.0;
                               } else {
                                 deliveryFee = 3.0 + ((distance - 3) * 1.0);
                               }
                               
                               final total = subtotal + tax + serviceFee + deliveryFee;
                               
                               return Column(
                                 crossAxisAlignment: CrossAxisAlignment.stretch,
                                 children: [
                                   _buildReceiptRow('Subtotal', subtotal),
                                   _buildReceiptRow('Impuesto (7.5%)', tax),
                                   _buildReceiptRow('Servicio (10%)', serviceFee),
                                   _buildReceiptRow('Delivery (~${distance.toStringAsFixed(1)} mi)', deliveryFee),
                                   const Padding(
                                     padding: EdgeInsets.symmetric(vertical: 8.0),
                                     child: Divider(),
                                   ),
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       const Text('Total a Pagar', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                       Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.green)),
                                     ],
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                         const SizedBox(height: 24),
                         ElevatedButton(
                           onPressed: () {
                             if (addressController.text.isEmpty || phoneController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor llena todos los datos')));
                                return;
                             }
                             if (selectedPayment == 'TARJETA') {
                               if (formKey.currentState?.validate() == false) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verifica los datos de la tarjeta')));
                                 return;
                               }
                             }
                             
                             if (selectedPayment == 'TARJETA' && cardNumber.isEmpty) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa tu tarjeta')));
                                 return;
                             }
                             
                             // Salvar la tarjeta temporalmente para procesarla abajo
                             if (selectedPayment == 'TARJETA') {
                               cardInfoToProcess = jsonEncode({
                                 "number": cardNumber,
                                 "expiryDate": expiryDate,
                                 "cardHolderName": cardHolderName,
                                 "cvvCode": cvvCode
                               });
                             }
                             
                             Navigator.pop(ctx, true);
                           }, 
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green,
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             elevation: 0,
                           ),
                           child: const Text('Confirmar Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                         ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      )
    );

    if (confirm != true) return;

    try {
      // Validate required fields
      if (addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa una dirección')),
        );
        return;
      }
      
      if (phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor ingresa un teléfono')),
        );
        return;
      }

      // Prepare card info if needed
      String? cardInfoToSend;
      if (selectedPayment == 'TARJETA' && cardInfoToProcess != null) {
         cardInfoToSend = cardInfoToProcess;
      }

      
      print('📦 Creating order...');
      print('   Items: ${_cart.values.map((c) => '${c.product['name']} x${c.quantity}').join(', ')}');
      print('   Address: ${addressController.text.trim()}');
      print('   Phone: ${phoneController.text.trim()}');
      print('   Payment: ${selectedPayment == 'EFECTIVO' ? 'CASH' : 'CARD'}');
      print('   CardInfo: $cardInfoToSend');

      await ref.read(productsRepositoryProvider).createOrder(
        _cart.values.map((cartItem) => {
          'id': cartItem.product['id'],
          'quantity': cartItem.quantity,
        }).toList(),
        address: addressController.text.trim(),
        phone: phoneController.text.trim(),
        paymentMethod: selectedPayment == 'EFECTIVO' ? 'CASH' : 'CARD',
        cardInfo: cardInfoToSend,
        deliveryFee: capturedDeliveryFee,
      );
      
      print('✅ Order created successfully!');

      if (!mounted) return;
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text('✅ Pedido Confirmado!'),
          content: const Text('Tu pedido ha sido enviado a la tienda.\n\nPuedes ver el estado en la pestaña "Orders".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            )
          ],
        )
      );

      setState(() {
        _cart.clear();
      });
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text('❌ Error'),
          content: Text('Checkout failed: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            )
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.jpg', height: 30),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_storeConfig != null && _storeConfig!['logoUrl'] != null)
              Image.network('${ApiService.baseUrl}${_storeConfig!['logoUrl']}', height: 40),
            const SizedBox(width: 10),
            Text(_storeConfig?['name'] ?? 'MiDespensa', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: const [SizedBox(width: 48)], // Balance the leading widget
      ),
      body: _selectedIndex == 0
          ? _HomeContentView(
              productsFuture: _productsFuture, 
              onAddToCart: _addToCart,
              searchController: _searchController,
              searchQuery: _searchQuery,
              filteredProducts: _filteredProducts,
            )
          : _selectedIndex == 2
            ? const _OrdersView() 
            : _selectedIndex == 3
              ? const _ProfileView()
              : _BrowseView(productsFuture: _productsFuture, onAddToCart: _addToCart),

      floatingActionButton: _cart.isNotEmpty && _selectedIndex == 0 
        ? FloatingActionButton.extended(
            onPressed: _showCartReview,
            label: Text('Ver Carrito (${_cart.values.fold<int>(0, (sum, item) => sum + item.quantity)})'),
            icon: const Icon(Icons.shopping_cart),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          )
        : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}



class _HomeContentView extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> productsFuture;
  final Function(Map<String, dynamic>) onAddToCart;
  final TextEditingController searchController;
  final String searchQuery;
  final List<Map<String, dynamic>> filteredProducts;

  const _HomeContentView({
    required this.productsFuture,
    required this.onAddToCart,
    required this.searchController,
    required this.searchQuery,
    required this.filteredProducts,
  });

  @override
  State<_HomeContentView> createState() => _HomeContentViewState();
}

class _HomeContentViewState extends State<_HomeContentView> {
  String _selectedCategory = 'Todo';

  @override
  Widget build(BuildContext context) {
    // Use filtered products if search is active, otherwise use all products from future
    final productsToDisplay = widget.searchQuery.isNotEmpty ? widget.filteredProducts : null;
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        // Use filtered products if searching, otherwise use snapshot data
        final products = productsToDisplay ?? snapshot.data!;
        
        // Group by category
        final Map<String, List<Map<String, dynamic>>> categories = {};
        for (var p in products) {
          final catName = p['category'] != null ? p['category']['name'] : 'Otros';
          categories.putIfAbsent(catName, () => []).add(p);
        }

        final List<String> categoryNames = ['Todo', ...categories.keys.toList()];

        return ListView(
          padding: const EdgeInsets.only(bottom: 20),
          physics: const BouncingScrollPhysics(),
          children: [
             const _PromoCarousel(),
             
             // Search Bar
             Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: widget.searchController,
                  decoration: InputDecoration(
                    hintText: '¿Qué estás buscando hoy?',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search, color: Colors.green),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              widget.searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Show results count when searching
            if (widget.searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  '${products.length} resultado${products.length != 1 ? 's' : ''} para "${widget.searchQuery}"',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),

             // Category Chips
             SizedBox(
               height: 60,
               child: ListView.separated(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                 scrollDirection: Axis.horizontal,
                 physics: const BouncingScrollPhysics(),
                 itemCount: categoryNames.length,
                 separatorBuilder: (_, __) => const SizedBox(width: 10),
                 itemBuilder: (ctx, index) {
                   final cat = categoryNames[index];
                   final isSelected = _selectedCategory == cat;
                   return ChoiceChip(
                     label: Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700)),
                     selected: isSelected,
                     selectedColor: Colors.green,
                     backgroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.green : Colors.grey.shade300)),
                     onSelected: (selected) {
                       setState(() {
                         _selectedCategory = cat;
                       });
                     },
                   );
                 },
               ),
             ),
            
            // Generate sorted sections
            ...categories.entries
                .where((entry) => _selectedCategory == 'Todo' || _selectedCategory == entry.key)
                .map((entry) {
              return _CategorySection(
                title: entry.key, 
                products: entry.value, 
                onAddToCart: widget.onAddToCart
              );
            }),
          ],
        );
      },
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({super.key});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Mock Promotions
  final List<Color> _promoColors = [Colors.redAccent, Colors.blueAccent, Colors.orangeAccent];
  final List<String> _promoTitles = ["50% OFF Apples!", "Free Delivery Today", "Buy 1 Get 1 Milk"];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (_currentPage < _promoColors.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage, 
          duration: const Duration(milliseconds: 350), 
          curve: Curves.easeIn
        );
        _startAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        itemCount: _promoColors.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _promoColors[index],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ]
            ),
            child: Center(
              child: Text(
                _promoTitles[index],
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onAddToCart;

  const _CategorySection({required this.title, required this.products, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => _CategoryDetailScreen(title: title, products: products, onAddToCart: onAddToCart)
                  ));
                }, 
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Text('Ver Todo', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      Icon(Icons.chevron_right, color: Colors.green.shade700, size: 20),
                    ],
                  ),
                )
              )
            ],
          ),
        ),
        SizedBox(
          height: 250, // Increased height for better proportions
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 16),
            itemBuilder: (ctx, index) {
              return SizedBox(
                width: 160, 
                child: _ProductCard(
                  product: products[index], 
                  onAddToCart: onAddToCart
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CategoryDetailScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onAddToCart;

  const _CategoryDetailScreen({required this.title, required this.products, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // Adjusting ratio for the new card length
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
        ),
        itemCount: products.length,
        itemBuilder: (ctx, index) => _ProductCard(product: products[index], onAddToCart: onAddToCart),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onAddToCart;

  const _ProductCard({required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final stock = product['displayedStock'] ?? product['stockQuantity'] ?? 0;
    final isOutOfStock = stock <= 0;
    final imgUrl = product['image'];
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final fullImgUrl = hasImage ? (imgUrl.startsWith('http') ? imgUrl : '${ApiService.baseUrl}$imgUrl') : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 2, blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              flex: 5,
              child: Container(
                color: isOutOfStock ? Colors.grey.shade100 : Colors.grey.shade50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(fullImgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_basket, size: 50, color: Colors.grey))
                    else
                      const Center(child: Icon(Icons.shopping_basket, size: 50, color: Colors.grey)),
                    
                    if (isOutOfStock)
                      Container(
                        color: Colors.white.withOpacity(0.7),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                            child: Text("Sin Stock", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Details Section
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOutOfStock ? 'Agotado' : 'Stock: $stock',
                          style: TextStyle(color: isOutOfStock ? Colors.red : Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${product['price']}',
                          style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        if (!isOutOfStock)
                          InkWell(
                            onTap: () => onAddToCart(product),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                              ),
                              child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                            ),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> item;
  final String orderStatus;

  const _OrderItemTile({required this.orderId, required this.item, required this.orderStatus});

  @override
  State<_OrderItemTile> createState() => _OrderItemTileState();
}

class _OrderItemTileState extends State<_OrderItemTile> {
  bool _isProcessing = false;
  late Map<String, dynamic> _itemData;

  @override
  void initState() {
    super.initState();
    _itemData = Map<String, dynamic>.from(widget.item);
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) return const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.shopping_bag, color: Colors.white, size: 20));
    final String fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return CircleAvatar(
      backgroundImage: NetworkImage(fullUrl),
      backgroundColor: Colors.transparent,
      onBackgroundImageError: (_, __) {},
    );
  }

  Future<void> _handleApproval(bool approved) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ProductsRepository();
      await repo.updateOrderItem(widget.orderId, _itemData['id'], {
        'customerApprovedReplacement': approved
      });
      setState(() {
         _itemData['customerApprovedReplacement'] = approved;
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approved ? '✅ Sustituto Aceptado' : '❌ Sustituto Rechazado'), backgroundColor: approved ? Colors.green : Colors.red));
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _itemData['status'] ?? 'PENDING';
    final isNotFound = status == 'NOT_FOUND';
    final isSubstituted = status == 'SUBSTITUTED';
    final approved = _itemData['customerApprovedReplacement'] as bool?;

    final product = _itemData['product'] ?? {};
    final originalName = product['name'] ?? 'Producto Desconocido';
    final qty = _itemData['quantityRequested'] ?? 0;
    final priceStr = product['price'];
    final price = priceStr != null ? double.tryParse(priceStr.toString()) ?? 0.0 : 0.0;

    // Handle Substitution display
    if (isSubstituted) {
      final replacement = _itemData['replacementProduct'] ?? {};
      final replacementName = replacement['name'] ?? 'Sustituto propuesto';
      final replPriceStr = replacement['price'];
      final replPrice = replPriceStr != null ? double.tryParse(replPriceStr.toString()) ?? 0.0 : 0.0;
      final showActions = approved == null && widget.orderStatus != 'COMPLETED';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: _buildImage(product['image']),
            title: Text(originalName, style: const TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, color: Colors.grey)),
            subtitle: Text('Cant: $qty x \$${price.toStringAsFixed(2)}', style: const TextStyle(decoration: TextDecoration.lineThrough)),
            trailing: Text('\$${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough, color: Colors.grey)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(approved == true ? '✅ Sustituto Aceptado' : (approved == false ? '❌ Sustituto Rechazado' : 'Sustituto Propuesto'), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildImage(replacement['image']),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(replacementName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Cant: $qty x \$${replPrice.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    Text('\$${(replPrice * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 12),
                  if (_isProcessing) 
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _handleApproval(false),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Rechazar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _handleApproval(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text('Aceptar'),
                        )
                      ],
                    )
                ]
              ],
            ),
          )
        ],
      );
    }

    if (isNotFound) {
      return ListTile(
        leading: _buildImage(product['image']),
        dense: true,
        title: Text(originalName, style: const TextStyle(fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, color: Colors.grey)),
        subtitle: const Text('No Disponible', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        trailing: Text('\$${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough, color: Colors.grey)),
      );
    }

    // Default pending/normal
    return ListTile(
      leading: _buildImage(product['image']),
      dense: true,
      title: Text(originalName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Cant: $qty x \$${price.toStringAsFixed(2)}'),
      trailing: Text('\$${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _OrdersView extends ConsumerStatefulWidget {
  const _OrdersView();
  @override
  ConsumerState<_OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends ConsumerState<_OrdersView> {
  late IO.Socket socket;
  final Map<String, Map<String, dynamic>> _driverLocations = {};
  final Set<String> _subscribedOrders = {};

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('https://midespensa.onrender.com', IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());
    socket.connect();
    socket.on('locationUpdate', (data) {
      if (mounted) {
        setState(() {
          _driverLocations[data['orderId']] = data;
        });
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  Widget _buildTimeline(String currentStatus) {
    int step = 0;
    if (currentStatus == 'CHECKOUT') step = 1;
    else if (currentStatus == 'DELIVERING') step = 2;
    else if (currentStatus == 'COMPLETED') step = 3;

    Color getColor(int s) => step >= s ? Colors.green : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(Icons.receipt, color: getColor(0)),
          Expanded(child: Divider(color: getColor(1), thickness: 3)),
          Icon(Icons.shopping_bag, color: getColor(1)),
          Expanded(child: Divider(color: getColor(2), thickness: 3)),
          Icon(Icons.local_shipping, color: getColor(2)),
          Expanded(child: Divider(color: getColor(3), thickness: 3)),
          Icon(Icons.check_circle, color: getColor(3)),
        ],
      ),
    );
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) return const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.shopping_bag, color: Colors.white, size: 20));
    final String fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return CircleAvatar(
      backgroundImage: NetworkImage(fullUrl),
      backgroundColor: Colors.transparent,
      onBackgroundImageError: (_, __) {},
    );
  }

  void _showRatingDialog(Map<String, dynamic> order) {
    int _shopperRating = order['shopperRating'] ?? 5;
    int _driverRating = order['driverRating'] ?? 5;
    final _tipController = TextEditingController(text: order['tipAmount']?.toString() ?? '0');
    final _commentController = TextEditingController(text: order['reviewComment'] ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Calificar Pedido', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Cómo te fue con el Shopper?', style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _shopperRating.toDouble(), min: 1, max: 5, divisions: 4, label: _shopperRating.toString(),
                    onChanged: (val) => setDialogState(() => _shopperRating = val.toInt()),
                    activeColor: Colors.blue,
                  ),
                  const Divider(),
                  const Text('¿Cómo te fue con el Conductor?', style: TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _driverRating.toDouble(), min: 1, max: 5, divisions: 4, label: _driverRating.toString(),
                    onChanged: (val) => setDialogState(() => _driverRating = val.toInt()),
                    activeColor: Colors.green,
                  ),
                  const Divider(),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(labelText: 'Comentarios adicionales (Opcional)', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tipController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Dejar propina (\$ USD)', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  setDialogState(() => isSubmitting = true);
                  try {
                    final apiService = ApiService();
                    await apiService.patch('/orders/${order['id']}', {
                      'shopperRating': _shopperRating,
                      'driverRating': _driverRating,
                      'reviewComment': _commentController.text,
                      'tipAmount': double.tryParse(_tipController.text) ?? 0.0,
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias por tus comentarios!')));
                      setState(() {});
                    }
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
              ),
            ],
          );
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ProductsRepository();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.getMyOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Aún no tienes órdenes pasadas. ¡Haz tu primera compra!', style: TextStyle(fontSize: 16, color: Colors.grey)));
        final sortedOrders = List<Map<String, dynamic>>.from(snapshot.data!);
        sortedOrders.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA); // Descendente (más nuevos primero)
        });

        return ListView.builder(
            itemCount: sortedOrders.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final order = sortedOrders[index];
              final items = order['items'] as List? ?? [];
              
              double subtotal = 0;
              int totalItems = 0;
              
              for (var currentItem in items) {
                final qty = currentItem['quantityRequested'] ?? 0;
                final product = currentItem['product'] ?? {};
                final priceStr = product['price'];
                final price = priceStr != null ? double.tryParse(priceStr.toString()) ?? 0.0 : 0.0;
                subtotal += (qty * price);
                totalItems += (qty as int);
              }

              final tax = subtotal * 0.075;
              final service = subtotal * 0.10;
              final deliveryFee = 3.0; // Cargo base
              final total = subtotal > 0 ? (subtotal + tax + service + deliveryFee) : 0.0;
              
              if (order['status'] == 'DELIVERING' && !_subscribedOrders.contains(order['id'])) {
                _subscribedOrders.add(order['id']);
                socket.emit('subscribeToOrder', order['id']);
              }
              
              final loc = _driverLocations[order['id']];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.black26,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long, color: Colors.green, size: 28),
                  ),
                  title: Text('Orden #${order['id'].substring(0,8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${_formatDate(order['createdAt'] ?? '')}', style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text('$totalItems arts. • \$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      _buildTimeline(order['status'] ?? ''),
                      if (order['status'] == 'DELIVERING')
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.gps_fixed, size: 16, color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    loc != null 
                                      ? 'Conductor moviéndose - Lat: ${loc["lat"].toStringAsFixed(4)}, Lng: ${loc["lng"].toStringAsFixed(4)}'
                                      : 'Conectando con el GPS del conductor...', 
                                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12)
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Visual indicator simulating movement based on incoming WebSocket data
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    // Use the decimal part of lat to simulate movement back and forth
                                    padding: EdgeInsets.only(left: loc != null ? ((loc["lat"] * 10000) % 100 / 100) * (MediaQuery.of(context).size.width * 0.5) : 0),
                                    child: Icon(Icons.delivery_dining, color: Colors.blue.shade700, size: 32),
                                  ),
                                  LinearProgressIndicator(
                                    value: loc != null ? ((loc["lat"] * 10000) % 100 / 100) : null,
                                    backgroundColor: Colors.blue.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 6,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context, 
                                          isScrollControlled: true, 
                                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                          builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: _ChatWidgetView(socket: socket, orderId: order['id'].toString(), senderRole: 'CUSTOMER'))
                                        );
                                      },
                                      icon: const Icon(Icons.chat),
                                      label: const Text('Chat con Conductor'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100, foregroundColor: Colors.blue.shade800),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      if (order['status'] == 'COMPLETED')
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade100)
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              const Text('Entregado exitosamente', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Detalle de Artículos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ),
                          ...items.map((item) => _OrderItemTile(orderId: order['id'], item: item, orderStatus: order['status'])),
                          if (order['paymentMethod'] != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Método de Pago:', style: TextStyle(color: Colors.grey.shade600)),
                                  Row(
                                    children: [
                                      Icon(order['paymentMethod'] == 'TARJETA' ? Icons.credit_card : Icons.money, size: 16, color: Colors.grey.shade700),
                                      const SizedBox(width: 4),
                                      Text('${order['paymentMethod']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                    if (order['status'] == 'COMPLETED')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(color: Colors.grey.shade50),
                        child: ElevatedButton.icon(
                          onPressed: () => _showRatingDialog(order),
                          icon: const Icon(Icons.star),
                          label: Text(order['shopperRating'] == null ? 'Calificar Entrega' : 'Actualizar Calificación'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
        );
      },
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  String _address = '';
  String _phone = '';
  String _cardInfo = '';
  String _email = 'client1@market.com';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    
    if (email == 'client1@market.com' || email == 'shopper1@market.com') {
      await prefs.setString('userAddress', '2858 Paprika Dr, Orlando, FL 32833');
      await prefs.setString('userPhone', '1234567890');
      await prefs.setString('userCardInfo', '{"number":"4111"}');
    }

    setState(() {
      _email = email.isNotEmpty ? email : 'shopper1@market.com';
      final addr = prefs.getString('userAddress') ?? '';
      _address = addr.isNotEmpty ? addr : 'Ninguna registrada';
      final ph = prefs.getString('userPhone') ?? '';
      _phone = ph.isNotEmpty ? ph : 'Sin teléfono';
      final card = prefs.getString('userCardInfo') ?? '';
      _cardInfo = card.isNotEmpty ? card : 'Sin tarjeta';
      
      if (_cardInfo.isNotEmpty && _cardInfo.startsWith('{')) {
         try {
           final data = jsonDecode(_cardInfo);
           final num = data['number'] ?? '****';
           _cardInfo = 'Terminada en ${num.length > 4 ? num.substring(num.length - 4) : num}';
         } catch (e) {
           _cardInfo = 'Tarjeta Guardada';
         }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.shade50, Colors.white],
          stops: const [0.0, 0.3],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)],
                ),
                child: const CircleAvatar(radius: 55, backgroundColor: Colors.green, child: Icon(Icons.person_outline, size: 60, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              Text('Mi Perfil', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, letterSpacing: 1.5, fontWeight: FontWeight.w500)),
              Text(_email, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 40),
              
              // Cajas de info Material Design
              _buildModernInfoCard(Icons.location_on_rounded, 'Dirección de Entrega', _address),
              const SizedBox(height: 12),
              _buildModernInfoCard(Icons.phone_iphone_rounded, 'Teléfono', _phone),
              const SizedBox(height: 12),
              _buildModernInfoCard(Icons.credit_card_rounded, 'Pago Predeterminado', _cardInfo),
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear(); // Limpiartodo
                    if (context.mounted) context.go('/login');
                  }, 
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(IconData icon, String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.green.shade700),
        ),
        title: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}

class _BrowseView extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> productsFuture;
  final Function(Map<String, dynamic>) onAddToCart;

  const _BrowseView({required this.productsFuture, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No categories found'));

        final products = snapshot.data!;
        final Map<String, List<Map<String, dynamic>>> categories = {};
        for (var p in products) {
          final catName = p['category'] != null ? p['category']['name'] : 'Otros';
          categories.putIfAbsent(catName, () => []).add(p);
        }

        final categoryNames = categories.keys.toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categoryNames.length,
          itemBuilder: (context, index) {
            final title = categoryNames[index];
            final catProducts = categories[title]!;
            
            return Card(
              color: Colors.green[50],
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (ctx) => _CategoryDetailScreen(
                      title: title, 
                      products: catProducts, 
                      onAddToCart: onAddToCart
                    )
                  ));
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category, size: 48, color: Colors.green),
                      const SizedBox(height: 12),
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('${catProducts.length} productos', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Widget de Chat accesible desde cualquier contexto en home_screen.
class _ChatWidgetView extends StatefulWidget {
  final dynamic socket;
  final String orderId;
  final String senderRole;
  const _ChatWidgetView({required this.socket, required this.orderId, required this.senderRole});

  @override
  State<_ChatWidgetView> createState() => _ChatWidgetViewState();
}

class _ChatWidgetViewState extends State<_ChatWidgetView> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.socket.on('chatMessage', (data) {
      if (mounted && data['orderId'] == widget.orderId) {
        setState(() => _messages.add({'text': data['message'], 'sender': data['senderRole']}));
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMsg() {
    if (_msgCtrl.text.trim().isEmpty) return;
    widget.socket.emit('sendChatMessage', {'orderId': widget.orderId, 'message': _msgCtrl.text.trim(), 'senderRole': widget.senderRole});
    setState(() => _messages.add({'text': _msgCtrl.text.trim(), 'sender': 'ME'}));
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('Chat del Pedido', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isMe = m['sender'] == 'ME';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _msgCtrl, decoration: const InputDecoration(hintText: 'Mensaje...'))),
            IconButton(onPressed: _sendMsg, icon: const Icon(Icons.send, color: Colors.green)),
          ]),
        ],
      ),
    );
  }
}
