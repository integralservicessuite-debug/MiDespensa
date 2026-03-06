
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/repository_providers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

class ShopAndDeliverDashboard extends ConsumerStatefulWidget {
  const ShopAndDeliverDashboard({super.key});

  @override
  ConsumerState<ShopAndDeliverDashboard> createState() => _ShopAndDeliverDashboardState();
}

class _ShopAndDeliverDashboardState extends ConsumerState<ShopAndDeliverDashboard> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  bool _isPickingPhase = true;
  
  // Track picked items
  final Set<String> _pickedItems = {};
  
  // Track substituted items: itemId -> substitute product name
  final Map<String, String> _substitutedItems = {};
  
  late IO.Socket socket;
  Timer? _locationTimer;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ref.read(ordersRepositoryProvider).getOrdersForShopper();
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io('https://midespensa.onrender.com', IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());
    socket.connect();
    socket.onConnect((_) {
      print('Connected to location socket');
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    socket.disconnect();
    socket.dispose();
    super.dispose();
  }

  void _startEmittingLocation(String orderId) {
    _currentOrderId = orderId;
    socket.emit('subscribeToOrder', orderId);
    
    // Simulate moving coordinates
    double lat = 19.4326;
    double lng = -99.1332;
    
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      lat += 0.0001; // simulate moving
      socket.emit('updateLocation', {
        'orderId': orderId,
        'lat': lat,
        'lng': lng,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Image.asset('assets/logo.jpg', height: 40), 
            ),
            const SizedBox(width: 10),
            Text(_isPickingPhase ? 'Phase 1: Shopping' : 'Phase 2: Delivery'),
          ],
        ),
        backgroundColor: _isPickingPhase ? Colors.purple : Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isPickingPhase 
        ? FutureBuilder<List<Map<String, dynamic>>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No active orders'));
              // For MVP, just show the first order's items
              return _buildPickingView(snapshot.data!.first);
            }
          ) 
        : _buildDeliveryView(),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status: ${_isPickingPhase ? "Picking in progress" : "En route to customer"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_isPickingPhase)
                FloatingActionButton.extended(
                  onPressed: () async {
                    // Update status to DELIVERING
                    // Hack: We are showing the first order. Let's get its ID.
                    final orders = await _ordersFuture;
                    if (orders.isNotEmpty) {
                      final orderId = orders.first['id'];
                      await ref.read(ordersRepositoryProvider).updateStatus(orderId, 'DELIVERING');
                      _startEmittingLocation(orderId);
                    }
                    
                    setState(() {
                      _isPickingPhase = false;
                    });
                  },
                  label: const Text('Finish Shopping'),
                  icon: const Icon(Icons.check),
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                )
              else
                FloatingActionButton.extended(
                  onPressed: () async {
                    // Update status to COMPLETED
                    final orders = await _ordersFuture;
                    if (orders.isNotEmpty) {
                      final orderId = orders.first['id'];
                      await ref.read(ordersRepositoryProvider).updateStatus(orderId, 'COMPLETED');
                    }
                    
                    _locationTimer?.cancel();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order Completed! Earned \$15.00')),
                    );
                    
                    // Refresh orders list
                    setState(() {
                       _isPickingPhase = true;
                       _ordersFuture = ref.read(ordersRepositoryProvider).getOrdersForShopper();
                    });

                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) Navigator.of(context).pop();
                    });
                  },
                  label: const Text('Complete Delivery'),
                  icon: const Icon(Icons.done_all),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickingView(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final deliveryAddress = order['deliveryAddress'] ?? 'No address';
    final contactPhone = order['contactPhone'] ?? 'No phone';
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Customer Info Card
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Información del Cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(deliveryAddress, style: const TextStyle(fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(contactPhone, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement phone call using url_launcher
                        // For now, show a snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Llamando a $contactPhone...')),
                        );
                      },
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Llamar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Order Items Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order['id'].substring(0,8)} - ${items.length} Items', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                ...items.map((item) => _buildChecklistItem(order['id'], item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String orderId, Map<String, dynamic> itemData) {
    final product = itemData['product'];
    final productName = product?['name'] ?? 'Unknown Item';
    final productId = product?['id'] ?? 'unknown';
    final orderItemId = itemData['id'] ?? '';

    // Product image - using placeholder for now
    final imageUrl = product?['imageUrl'] ?? 'https://via.placeholder.com/60x60.png?text=${Uri.encodeComponent(productName.substring(0, 1))}';

    // Location Data
    final aisle = product?['aisle'] ?? 'N/A';
    final section = product?['section'] ?? '';
    final shelf = product?['shelf'] ?? '';
    final locationInfo = 'Pasillo $aisle • Sección $section • Nivel $shelf';

    final isPicked = _pickedItems.contains(productId);
    final isSubstituted = _substitutedItems.containsKey(productId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          backgroundColor: Colors.grey[200],
          onBackgroundImageError: (_, __) {},
          child: const Icon(Icons.shopping_bag, color: Colors.grey),
        ),
        title: Text(
          isSubstituted ? '${_substitutedItems[productId]} (Sustituto)' : productName,
          style: TextStyle(
            decoration: isPicked ? TextDecoration.lineThrough : null,
            color: isPicked ? Colors.grey : (isSubstituted ? Colors.orange[700] : Colors.black),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locationInfo,
              style: TextStyle(
                color: isPicked ? Colors.grey[400] : Colors.blueGrey,
                fontSize: 12
              ),
            ),
            if (isSubstituted)
              Text(
                'Original: $productName',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPicked && !isSubstituted)
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                onPressed: () => _showSubstitutionDialog(orderId, orderItemId, productId, productName),
                tooltip: 'Sustituir producto',
              ),
            Checkbox(
              value: isPicked,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _pickedItems.add(productId);
                  } else {
                    _pickedItems.remove(productId);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryView() {
    return Column(
      children: [
        Container(
          height: 200,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 80, color: Colors.grey),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _showLabelPrintingDialog,
                icon: const Icon(Icons.print),
                label: const Text('Imprimir Etiquetas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Customer: Juan Pérez'),
                subtitle: Text('Rating: 4.8'),
              ),
              ListTile(
                leading: Icon(Icons.location_on),
                title: Text('123 Main St, Apt 4B'),
                subtitle: Text('Note: Access code 1234'),
              ),
              ListTile(
                leading: Icon(Icons.phone),
                title: Text('Call Customer'),
                trailing: Icon(Icons.phone_in_talk, color: Colors.green),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showLabelPrintingDialog() async {
    final bagsController = TextEditingController(text: '1');
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Imprimir Etiquetas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Cuántas bolsas son?'),
              const SizedBox(height: 10),
              TextField(
                controller: bagsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Bolsas',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(bagsController.text) ?? 1;
                Navigator.of(context).pop();
                _generateAndPrintLabels(qty);
              },
              child: const Text('Imprimir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAndPrintLabels(int quantity) async {
    // Determine status: Using first order for MVP data
    final orders = await ref.read(ordersRepositoryProvider).getOrdersForShopper();
    // Ideally pass order data securely, but mock data is fine for prototype
    final customerName = "Juan Pérez"; 
    final address = "123 Main St";
    
    final pdf = pw.Document();

    for (var i = 1; i <= quantity; i++) {
        pdf.addPage(
        pw.Page(
            pageFormat: PdfPageFormat.roll80,
            build: (pw.Context context) {
            return pw.Center(
                child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                    pw.Text('MiDespensa', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Orden: #12345'), // Placeholder
                    pw.Text('Cliente: $customerName'),
                    pw.Text(address),
                    pw.Divider(),
                    pw.Text('Bolsa $i de $quantity', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'ORDER-12345-BAG-$i',
                    width: 80,
                    height: 80,
                    ),
                ],
                ),
            );
            },
        ),
        );
    }

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Show substitution dialog
  void _showSubstitutionDialog(String orderId, String orderItemId, String productId, String originalProductName) {
    // TODO: Fetch real alternatives from backend based on product category
    // For now, using mock data
    final mockAlternatives = [
      {'id': 'alt1', 'name': '$originalProductName (Marca Alternativa)', 'price': 2.99},
      {'id': 'alt2', 'name': 'Producto Similar 1', 'price': 3.49},
      {'id': 'alt3', 'name': 'Producto Similar 2', 'price': 2.79},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sustituir Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto no disponible:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(originalProductName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Selecciona un sustituto:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...mockAlternatives.map((alt) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: const Icon(Icons.shopping_bag, color: Colors.orange, size: 20),
              ),
              title: Text(alt['name'] as String),
              subtitle: Text('\$${alt['price']}'),
              onTap: () async {
                try {
                  await ref.read(ordersRepositoryProvider).updateOrderItem(
                    orderId,
                    orderItemId,
                    {
                      'status': 'SUBSTITUTED',
                      // Send the real product ID of the replacement from mockAlternatives
                      'replacementProductId': '3f1e94b2-a4e5-4f36-829d-bb5d378ee01a' // Replace with proper mocked ID temporarily since DB expects valid productId
                    }
                  );
                  setState(() {
                    _substitutedItems[productId] = alt['name'] as String;
                  });
                  if(mounted) Navigator.pop(ctx);
                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Producto sustituido: ${alt['name']}'), backgroundColor: Colors.orange),
                    );
                  }
                } catch (e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            )),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              title: const Text('No sustituir (marcar como no disponible)'),
              onTap: () async {
                try {
                  await ref.read(ordersRepositoryProvider).updateOrderItem(
                    orderId,
                    orderItemId,
                    {'status': 'NOT_FOUND'}
                  );
                  setState(() {
                    _substitutedItems[productId] = 'NO DISPONIBLE';
                  });
                  if(mounted) Navigator.pop(ctx);
                  if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Producto marcado como no disponible'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
