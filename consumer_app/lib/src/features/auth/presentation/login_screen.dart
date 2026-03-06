
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/api_service.dart';
import '../../../shared/providers/repository_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _storeConfig;

  @override
  void initState() {
    super.initState();
    _loadStoreConfig();
  }

  void _loadStoreConfig() async {
    final config = await ref.read(storeRepositoryProvider).getStoreSettings();
    if (mounted && config != null) {
      setState(() {
        _storeConfig = config;
      });
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authRepositoryProvider).login(
        _emailController.text, 
        _passwordController.text
      );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MiDespensa logo - top left corner
          Positioned(
            top: 40,
            left: 16,
            child: Image.asset('assets/logo.jpg', height: 30),
          ),
          // Main login content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store logo - centered and prominent
                  _storeConfig != null && _storeConfig!['logoUrl'] != null
                      ? Image.network('${ApiService.baseUrl}${_storeConfig!['logoUrl']}', height: 100)
                      : const Icon(Icons.shopping_basket, size: 80, color: Colors.green),
                  const SizedBox(height: 20),
                  Text(
                    _storeConfig?['name'] ?? 'MiDespensa',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to Register
                },
                child: const Text('Don\'t have an account? Register'),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}
