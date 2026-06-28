import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'whatsapp_qr_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _compNameCtrl;
  late TextEditingController _cnpjCtrl;
  late TextEditingController _compPhoneCtrl;
  bool _loading = true;
  bool _uploading = false;
  bool _savingComp = false;
  Map<String, dynamic>? _company;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _compNameCtrl = TextEditingController();
    _cnpjCtrl = TextEditingController();
    _compPhoneCtrl = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final url = await ApiConfig.getBaseUrl();
    _urlCtrl.text = url;
    try {
      _user = (await ApiService.getMe())['user'];
      _company = await ApiService.getCompany();
      if (_company != null) {
        _compNameCtrl.text = _company!['name'] ?? '';
        _cnpjCtrl.text = _company!['cnpj'] ?? '';
        _compPhoneCtrl.text = _company!['phone'] ?? '';
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    await ApiConfig.setBaseUrl(url);
    await ApiService.init();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('URL salva com sucesso'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _saveCompany() async {
    setState(() => _savingComp = true);
    try {
      final body = <String, String>{
        'name': _compNameCtrl.text,
        'cnpj': _cnpjCtrl.text,
        'phone': _compPhoneCtrl.text,
      };
      if (_company != null) {
        await ApiService.updateCompany(body);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Dados salvos!')]),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _savingComp = false);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final result = await ApiService.uploadLogo(File(file.path));
      setState(() {
        _company ??= {};
        _company!['logo'] = result['logo'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Logo atualizada!')]),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _uploading = false);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _compNameCtrl.dispose();
    _cnpjCtrl.dispose();
    _compPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracoes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Editar Perfil'),
                    subtitle: const Text('Nome, email, empresa, telefone'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Dados da Empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        if (_company?['logo'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                '${ApiService.baseUrl}/${_company!['logo']}',
                                height: 64, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Text('Logo nao carregada'),
                              ),
                            ),
                          ),
                        TextField(
                          controller: _compNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nome Fantasia', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cnpjCtrl,
                          decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder()),
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _compPhoneCtrl,
                          decoration: const InputDecoration(labelText: 'Telefone da Empresa', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickLogo,
                            icon: _uploading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.image),
                            label: const Text('Alterar Logo'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: ElevatedButton(
                            onPressed: _savingComp ? null : _saveCompany,
                            child: _savingComp
                                ? const CircularProgressIndicator()
                                : const Text('Salvar Dados da Empresa'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.message, color: Color(0xFF25D366)),
                    title: const Text('WhatsApp'),
                    subtitle: const Text('Conectar numero central para envio de relatorios'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WhatsAppQRScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('URL da API', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Digite o endereco do servidor backend (ex: http://192.168.0.10:3000)'),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL da API',
                    border: OutlineInputBorder(),
                    hintText: 'http://localhost:3000',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(onPressed: _saveUrl, child: const Text('Salvar URL')),
                ),
              ],
            ),
    );
  }
}
