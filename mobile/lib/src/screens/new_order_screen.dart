import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/service_order.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _clientNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _recommendationsCtrl = TextEditingController();
  String? _serviceCategory;
  bool _preExistingDamage = false;
  bool _loading = false;

  Future<void> _save() async {
    if (_clientNameCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preencha nome e endereco'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;
      final order = ServiceOrder(
        clientName: _clientNameCtrl.text,
        clientAddress: _addressCtrl.text,
        clientPhone: _phoneCtrl.text,
        description: _descCtrl.text,
        serviceCategory: _serviceCategory,
        preExistingDamage: _preExistingDamage,
        recommendations: _recommendationsCtrl.text.isNotEmpty
            ? _recommendationsCtrl.text
            : null,
        userId: userId,
      );
      await ApiService.createOrder(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Ordem criada com sucesso!'),
            ],
          ),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Ordem')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _clientNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Cliente *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Endereco *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Telefone / WhatsApp',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _serviceCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria do Servico',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'preventive', child: Text('Preventiva')),
                DropdownMenuItem(value: 'corrective', child: Text('Corretiva')),
                DropdownMenuItem(value: 'budget', child: Text('Orcamento')),
              ],
              onChanged: (v) => setState(() => _serviceCategory = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descricao do servico',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Dano Pre-existente?'),
              value: _preExistingDamage,
              onChanged: (v) => setState(() => _preExistingDamage = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recommendationsCtrl,
              decoration: const InputDecoration(
                labelText: 'Recomendacoes Futuras',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Criar Ordem'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _recommendationsCtrl.dispose();
    super.dispose();
  }
}
