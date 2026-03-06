
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Work Mode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoleCard(
              icon: Icons.shopping_basket,
              title: 'Shopper',
              subtitle: 'Pick & Pack Orders',
              color: Colors.orange,
              onTap: () => context.go('/shopper'),
            ),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.local_shipping,
              title: 'Driver',
              subtitle: 'Deliver to Customers',
              color: Colors.blue,
              onTap: () => context.go('/driver'),
            ),
            const SizedBox(height: 24),
            _RoleCard(
              icon: Icons.rocket_launch,
              title: 'Shop & Deliver',
              subtitle: 'Full Service (Earn More)',
              color: Colors.purple,
              onTap: () => context.go('/shop_and_deliver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 160,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
