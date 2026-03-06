import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/shopper/data/orders_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});
