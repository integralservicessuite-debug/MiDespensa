import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/marketplace/data/products_repository.dart';
import '../../features/marketplace/data/store_repository.dart';
import '../../features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository();
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository();
});

final storeConfigProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.read(storeRepositoryProvider);
  return repository.getStoreSettings();
});

final productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.read(productsRepositoryProvider);
  return repository.getProducts();
});
