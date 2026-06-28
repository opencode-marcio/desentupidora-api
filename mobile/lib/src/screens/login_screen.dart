import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPass = prefs.getString('saved_password') ?? '';
    if (savedEmail.isNotEmpty) {
      _emailCtrl.text = savedEmail;
      if (savedPass.isNotEmpty) {
        _passCtrl.text = savedPass;
      }
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.login(_emailCtrl.text, _passCtrl.text);
      if (res.containsKey('token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res['token']);
        await prefs.setInt('userId', res['user']['id']);
        await prefs.setString('userName', res['user']['name']);
        await prefs.setString('userRole', res['user']['role'] ?? 'technician');
        if (_remember) {
          await prefs.setString('saved_email', _emailCtrl.text);
          await prefs.setString('saved_password', _passCtrl.text);
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(res['error'] ?? 'Erro ao fazer login');
      }
    } catch (e) {
      _showError('Erro de conexao: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _showServerConfig() async {
    final controller = TextEditingController(text: ApiConfig.defaultBaseUrl);
    final current = await ApiConfig.getBaseUrl();
    controller.text = current;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL do servidor',
            hintText: 'http://192.168.0.100:3000',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ApiConfig.setBaseUrl(result);
      await ApiService.init();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar servidor',
            onPressed: () => _showServerConfig(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.plumbing, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 16),
                Text('FotoLaudo', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Laudo fotografico digital', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: const OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                TextField(controller: _passCtrl, obscureText: !_showPass, decoration: InputDecoration(labelText: 'Senha', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPass = !_showPass)))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? true),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _remember = !_remember),
                      child: const Text('Lembrar dados'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : _login, child: _loading ? const CircularProgressIndicator() : const Text('Entrar'))),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: const Text('Criar conta')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
