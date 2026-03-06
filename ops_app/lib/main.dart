
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'src/features/auth/presentation/role_selection_screen.dart';
import 'src/features/shopper/presentation/shopper_dashboard.dart';
import 'src/features/driver/presentation/driver_dashboard.dart';
import 'src/features/shop_and_deliver/presentation/shop_and_deliver_dashboard.dart';
import 'src/features/auth/presentation/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: OpsApp()));
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/shopper',
      builder: (context, state) => const ShopperDashboard(),
    ),
    GoRoute(
      path: '/driver',
      builder: (context, state) => const DriverDashboard(),
    ),
    GoRoute(
      path: '/shop_and_deliver',
      builder: (context, state) => const ShopAndDeliverDashboard(),
    ),
  ],
);

class OpsApp extends StatelessWidget {
  const OpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MiDespensa Ops',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
