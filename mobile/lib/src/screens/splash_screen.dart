import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fadeIcon;
  late final Animation<double> _fadeText;
  bool _timeout = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.elasticOut)),
    );
    _fadeIcon = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.easeIn)),
    );
    _fadeText = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8, curve: Curves.easeIn)),
    );
    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeIcon.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: child,
                  ),
                );
              },
              child: Icon(
                Icons.plumbing,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _fadeText,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeText.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _fadeText.value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    'FotoLaudo',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Laudo fotografico digital',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            if (_timeout) ...[
              const Icon(Icons.wifi_off, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Servidor indisponivel'),
              const SizedBox(height: 8),
              const Text('Verifique a URL do servidor nas configuracoes',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                label: const Text('Ir para Login'),
              ),
            ] else if (!_ctrl.isAnimating)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
