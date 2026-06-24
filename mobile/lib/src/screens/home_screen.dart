import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../models/service_order.dart';
import 'new_order_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceOrder> _orders = [];
  bool _loading = true;
  Map<String, dynamic>? _company;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('userName') ?? '';
      final results = await Future.wait([
        ApiService.getOrders(),
        ApiService.getCompany().catchError((_) => null),
      ]);
      setState(() {
        _orders = (results[0] as Map)['orders'] as List<ServiceOrder>;
        _company = results[1] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pendente';
      case 'in_progress': return 'Em andamento';
      case 'completed': return 'Concluido';
      case 'cancelled': return 'Cancelado';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_company?['logo'] != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    '${ApiService.baseUrl}/${_company!['logo']}',
                    height: 32, width: 32, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 24),
                  ),
                ),
              ),
            Expanded(
              child: Text(_company?['name'] ?? 'Ordens de Servico'),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _load())),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen())).then((_) => _load()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('Nenhuma ordem encontrada'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final date = order.createdAt != null
                          ? DateFormat('dd/MM/yyyy').format(order.createdAt!)
                          : '';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(order.status),
                            child: Text((order.clientName.isNotEmpty ? order.clientName[0] : '?').toUpperCase()),
                          ),
                          title: Text(order.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${order.clientAddress}\n$date'),
                          trailing: Chip(
                            label: Text(_statusLabel(order.status), style: const TextStyle(color: Colors.white, fontSize: 11)),
                            backgroundColor: _statusColor(order.status),
                            padding: EdgeInsets.zero,
                          ),
                          onTap: () => Navigator.pushNamed(context, '/order-detail', arguments: order.id),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
