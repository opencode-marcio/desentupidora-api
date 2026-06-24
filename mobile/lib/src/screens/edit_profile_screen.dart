import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getMe();
      final user = data['user'];
      _nameCtrl.text = user['name'] ?? '';
      _emailCtrl.text = user['email'] ?? '';
      _companyCtrl.text = user['company'] ?? '';
      _phoneCtrl.text = user['phone'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      _showError('Nome deve ter no minimo 2 caracteres');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, String>{
        'name': _nameCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_emailCtrl.text.trim().isNotEmpty) {
        body['email'] = _emailCtrl.text.trim();
      }
      await ApiService.updateProfile(body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erro: $e');
    }
    setState(() => _saving = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(labelText: 'Empresa', border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
