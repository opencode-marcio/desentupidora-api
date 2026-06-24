import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _timeout = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 600));
    try {
      await ApiService.getMe().timeout(const Duration(seconds: 5));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException catch (_) {
      if (mounted) setState(() => _timeout = true);
    } catch (_) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.plumbing,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Desentupidora App',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Comprovacao de servico',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            if (_timeout) ...[
              const Icon(Icons.wifi_off, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Servidor indisponivel'),
              const SizedBox(height: 8),
              const Text('Verifique a URL do servidor nas configuracoes', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                label: const Text('Ir para Login'),
              ),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
