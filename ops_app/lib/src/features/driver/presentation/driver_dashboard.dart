
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/repository_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> with SingleTickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _activeFuture;
  late Future<List<Map<String, dynamic>>> _completedFuture;
  final Set<String> _loadedOrders = {};
  late TabController _tabController;
  Timer? _pollingTimer;
  bool _isShowingOffer = false;
  
  late IO.Socket socket;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Helper para leer el deliveryFee de una orden
  double _getDeliveryFee(Map<String, dynamic> order) {
    final raw = order['deliveryFee'];
    if (raw == null) return 3.0;
    return double.tryParse(raw.toString()) ?? 3.0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshActive();
    _refreshCompleted();
    _startBatchPolling();
    _initNotificationsAndSocket();
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
        _showNotification(data['title'] ?? 'Notificación', data['body'] ?? 'Tienes un nuevo mensaje');
        _refreshActive();
      }
    });
  }

  Future<void> _showNotification(String title, String body) async {
    if (!kIsWeb) {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'midespensa_driver', 'Alertas de Conductor',
        importance: Importance.max, priority: Priority.high, showWhen: true);
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);
      try {
        await (flutterLocalNotificationsPlugin as dynamic).show(DateTime.now().millisecond, title, body, platformChannelSpecifics);
      } catch (_) {}
    }
  }

  void _startBatchPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isShowingOffer) return;
      try {
        final batches = await ref.read(ordersRepositoryProvider).getAvailableBatches();
        if (batches.isNotEmpty && !_isShowingOffer) {
          _showOfferDialog(batches.first);
        }
      } catch (e) {
        debugPrint('Error polling batches: $e');
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _refreshActive() {
    setState(() {
      _activeFuture = ref.read(ordersRepositoryProvider).getOrdersForDriver();
    });
  }

  void _refreshCompleted() {
    setState(() {
      _completedFuture = ref.read(ordersRepositoryProvider).getOrdersForDriverCompleted();
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    } catch (_) { return isoString; }
  }

  void _showScanBagsDialog(String orderId, {bool isDelivery = false}) {
    int totalBags = 2;
    int scannedBags = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isDelivery ? 'Escanear bolsas a entregar' : 'Escanear bolsas a cargar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text('Escaneadas: $scannedBags / $totalBags bolsas', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: scannedBags / totalBags),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: scannedBags >= totalBags
                    ? null
                    : () async {
                        setDialogState(() { scannedBags++; });
                        if (scannedBags >= totalBags) {
                          if (isDelivery) {
                            await ref.read(ordersRepositoryProvider).updateStatus(orderId, 'COMPLETED');
                            if (mounted) {
                              _refreshActive();
                              _refreshCompleted();
                            }
                          } else {
                            if (mounted) setState(() { _loadedOrders.add(orderId); });
                          }
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isDelivery ? '✅ ¡Entrega confirmada! Revisa tus ganancias en la pestaña de historial.' : 'Todas las bolsas cargadas. ¡Puedes navegar!')),
                              );
                              if (isDelivery) _tabController.animateTo(1); // Ir a pestaña Ganancias
                            }
                          });
                        }
                      },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: Text(scannedBags >= totalBags ? (isDelivery ? 'Completando...' : 'Cargando...') : 'Escanear Siguiente'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showOfferDialog(Map<String, dynamic> batch) {
    if (_isShowingOffer) return;
    _isShowingOffer = true;
    
    final earnings = double.tryParse(batch['estimatedEarnings'].toString()) ?? 3.0;
    final List<dynamic> orders = batch['orders'] ?? [];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.airport_shuttle, color: Colors.blue, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Text('¡Nueva Oferta Disponible!', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 18))),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ganancia Estimada', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('\$${earnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green)),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ruta: Tienda -> Cliente(s)'),
                  Text('${orders.length} entrega(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 120, // Simulador de mapa en UI
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  image: const DecorationImage(
                    image: NetworkImage('https://maps.googleapis.com/maps/api/staticmap?center=25.7617,-80.1918&zoom=13&size=400x120&maptype=roadmap&markers=color:blue%7Clabel:S%7C25.7617,-80.1918&markers=color:green%7Clabel:D%7C25.7517,-80.2018&key=PLACEHOLDER'),
                    fit: BoxFit.cover,
                  )
                ),
                child: const Center(child: Icon(Icons.map, size: 40, color: Colors.black26)),
              )
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () {
                _isShowingOffer = false;
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: const Text('Rechazar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final orderIds = orders.map((o) => o['id'].toString()).toList();
                try {
                  // TODO: Use true driver ID from auth state, null triggers fallback in backend
                  await ref.read(ordersRepositoryProvider).acceptBatch('', orderIds);
                  _isShowingOffer = false;
                  if (mounted) {
                    Navigator.pop(context);
                    _refreshActive();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Oferta aceptada! Procede a la tienda.')));
                  }
                } catch (e) {
                  _isShowingOffer = false;
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al aceptar: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: const Text('¡Aceptar!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
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
            const Text('Driver Mode'),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade200,
          tabs: const [
            Tab(icon: Icon(Icons.delivery_dining), text: 'Entregas Activas'),
            Tab(icon: Icon(Icons.attach_money), text: 'Ganancias'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveDeliveriesTab(),
          _buildEarningsTab(),
        ],
      ),
    );
  }

  // ====================
  // TAB 1: Activas
  // ====================
  Widget _buildActiveDeliveriesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text('No hay entregas activas.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('¡Todo al día!', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final orders = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refreshActive(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final customer = order['customer'] ?? {};
              final isLoaded = _loadedOrders.contains(order['id']);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: isLoaded ? Colors.green.shade100 : Colors.blue.shade100,
                        child: Icon(
                          isLoaded ? Icons.local_shipping : Icons.location_on,
                          color: isLoaded ? Colors.green : Colors.blue,
                        ),
                      ),
                      title: Text('Entrega #${order['id'].substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(customer['email'] ?? 'Cliente', style: const TextStyle(fontSize: 13)),
                          ]),
                          if (order['deliveryAddress'] != null) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(order['deliveryAddress'], style: const TextStyle(fontSize: 12, color: Colors.grey))),
                            ]),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLoaded ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isLoaded ? Colors.green.shade200 : Colors.orange.shade200),
                            ),
                            child: Text(
                              isLoaded ? '🚗 En Camino' : '📦 Esperando Carga',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isLoaded ? Colors.green.shade700 : Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text('\$${_getDeliveryFee(order).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade600)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: isLoaded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context, 
                                          isScrollControlled: true, 
                                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                          builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: _ChatWidget(socket: socket, orderId: order['id'], senderRole: 'DRIVER'))
                                        );
                                      },
                                      icon: const Icon(Icons.chat),
                                      label: const Text('Chat'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final address = order['deliveryAddress'] ?? customer['address'] ?? '';
                                        if (address.isEmpty) return;
                                        final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}');
                                        try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (_) {}
                                      },
                                      icon: const Icon(Icons.map),
                                      label: const Text('Navegar'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showScanBagsDialog(order['id'], isDelivery: true),
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Escanear y Entregar'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showScanBagsDialog(order['id']),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Escanear Bolsas para Cargar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ====================
  // TAB 2: Ganancias
  // ====================
  Widget _buildEarningsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _completedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];
        final totalEarnings = orders.fold<double>(0, (sum, o) => sum + _getDeliveryFee(o));

        // Órdenes de hoy
        final today = DateTime.now();
        final todayOrders = orders.where((o) {
          final d = DateTime.tryParse(o['updatedAt'] ?? '');
          return d != null && d.day == today.day && d.month == today.month && d.year == today.year;
        }).toList();
        final todayEarnings = todayOrders.fold<double>(0, (sum, o) => sum + _getDeliveryFee(o));

        return RefreshIndicator(
          onRefresh: () async => _refreshCompleted(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tarjeta de Resumen de Ganancias
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Total Acumulado', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('\$${totalEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _buildEarningStat('Hoy', '\$${todayEarnings.toStringAsFixed(2)}', Icons.today)),
                        Container(width: 1, height: 50, color: Colors.white24),
                        Expanded(child: _buildEarningStat('Entregas', '${orders.length}', Icons.local_shipping)),
                        Container(width: 1, height: 50, color: Colors.white24),
                        Expanded(child: _buildEarningStat('Hoy', '${todayOrders.length}', Icons.check_circle)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (orders.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Aún no tienes entregas completadas.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                )
              else ...[
                const Text('Historial de Entregas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...orders.map((order) {
                  final customer = order['customer'] ?? {};
                  final items = order['items'] as List? ?? [];
                  final completedAt = _formatDate(order['updatedAt']);
                  final orderFee = _getDeliveryFee(order);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.check_circle, color: Colors.green.shade600),
                      ),
                      title: Text('Entrega #${order['id'].substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer['email'] ?? 'Cliente', style: const TextStyle(fontSize: 12)),
                          Text('${items.length} artículo(s) • $completedAt', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${orderFee.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade600)),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Text('Completada', style: TextStyle(fontSize: 10, color: Colors.green)),
                          )
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _ChatWidget extends StatefulWidget {
  final IO.Socket socket;
  final String orderId;
  final String senderRole;

  const _ChatWidget({required this.socket, required this.orderId, required this.senderRole});

  @override
  State<_ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<_ChatWidget> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.socket.on('chatMessage', _handleMessage);
  }

  @override
  void dispose() {
    widget.socket.off('chatMessage', _handleMessage);
    _controller.dispose();
    super.dispose();
  }

  void _handleMessage(dynamic data) {
    if (data['orderId'] == widget.orderId) {
      if (mounted) setState(() => _messages.add(Map<String, dynamic>.from(data)));
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.socket.emit('sendChatMessage', {
      'orderId': widget.orderId,
      'senderRole': widget.senderRole,
      'text': text,
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 16),
          Text('Chat de la Orden #${widget.orderId.substring(0,6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg['senderRole'] == widget.senderRole;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green.shade500 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                        bottomLeft: !isMe ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje al cliente...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.green,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage)
              )
            ],
          )
        ],
      ),
    );
  }
}

