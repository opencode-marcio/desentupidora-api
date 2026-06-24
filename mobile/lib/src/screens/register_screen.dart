import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showError('Preencha nome, email e senha');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.register(
        _nameCtrl.text, _emailCtrl.text, _passCtrl.text,
        _companyCtrl.text, _phoneCtrl.text,
      );
      if (res.containsKey('token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res['token']);
        await prefs.setInt('userId', res['user']['id']);
        await prefs.setString('userName', res['user']['name']);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError(res['error'] ?? 'Erro ao cadastrar');
      }
    } catch (e) {
      _showError('Erro de conexao: $e');
    }
    setState(() => _loading = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome', border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: const OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              TextField(controller: _passCtrl, obscureText: !_showPass, decoration: InputDecoration(labelText: 'Senha', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPass = !_showPass)))),
              const SizedBox(height: 16),
              TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Nome da Empresa', border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefone', border: const OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _loading ? null : _register, child: _loading ? const CircularProgressIndicator() : const Text('Cadastrar'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
}
