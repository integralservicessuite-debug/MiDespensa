
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../shop_and_deliver/presentation/shop_and_deliver_dashboard.dart';

class ShopperDashboard extends ConsumerStatefulWidget {
  const ShopperDashboard({super.key});

  @override
  ConsumerState<ShopperDashboard> createState() => _ShopperDashboardState();
}

class _ShopperDashboardState extends ConsumerState<ShopperDashboard> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ref.read(ordersRepositoryProvider).getOrdersForShopper();
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
            const Text('Shopper Mode'),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}')); 
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active orders'));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.list_alt, color: Colors.white),
                  ),
                  title: Text('Order #${order['id'].substring(0, 8)}'),
                  subtitle: Text('${order['items']?.length ?? 0} Items • Status: ${order['status']}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Navigate to picking screen (reusing ShopAndDeliverDashboard for MVP logic)
                      // Ideally we should pass the Order ID to load specifically that order.
                      // For MVP, ShopAndDeliverDashboard loads "first" order. 
                      // Let's pass the order via constructor or just route.
                      
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShopAndDeliverDashboard(),
                        ),
                      ).then((_) {
                        // Refresh list when coming back
                        setState(() {
                          _ordersFuture = ref.read(ordersRepositoryProvider).getOrdersForShopper();
                        });
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Start Pick', style: TextStyle(color: Colors.white)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
