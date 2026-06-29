import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WhatsAppQRScreen extends StatefulWidget {
  const WhatsAppQRScreen({super.key});

  @override
  State<WhatsAppQRScreen> createState() => _WhatsAppQRScreenState();
}

class _WhatsAppQRScreenState extends State<WhatsAppQRScreen> {
  String _status = 'verificando';
  String? _qr;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Timer? _pollTimer;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    try {
      final status = await ApiService.getWhatsAppStatus();
      setState(() {
        _status = status['status'] ?? 'desconhecido';
        _qr = null;
      });

      if (_status == 'connected') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('WhatsApp ja conectado')]),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() => _loading = false);
      } else {
        await ApiService.startWhatsApp();
        await Future.delayed(const Duration(seconds: 2));
        _startTimeout();
        _pollQR();
      }
    } catch (e) {
      setState(() => _status = 'erro');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
      setState(() => _loading = false);
    }
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _loading = false;
        _status = 'timeout';
      });
    });
  }

  void _pollQR() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        if (_status == 'connected') {
          _pollTimer?.cancel();
          _timeoutTimer?.cancel();
          return;
        }

        final result = await ApiService.getWhatsAppQR();
        if (!mounted) return;

        if (result['qr'] != null) {
          _pollTimer?.cancel();
          _timeoutTimer?.cancel();
          setState(() {
            _qr = result['qr'];
            _status = 'awaiting_scan';
            _loading = false;
          });
          _pollConnection();
        } else if (result['status'] == 'connected') {
          _pollTimer?.cancel();
          _timeoutTimer?.cancel();
          setState(() {
            _qr = null;
            _status = 'connected';
            _loading = false;
          });
        }
      } catch (_) {}
    });
  }

  void _pollConnection() {
    Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await ApiService.getWhatsAppStatus();
        if (!mounted) return;
        if (status['status'] == 'connected') {
          _pollTimer?.cancel();
          _timeoutTimer?.cancel();
          setState(() {
            _status = 'connected';
            _qr = null;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _qr = null;
      _status = 'verificando';
    });
    await _checkStatus();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconectar WhatsApp'),
        content: const Text('Tem certeza? Voce precisara escanear o QR code novamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desconectar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.logoutWhatsApp();
      setState(() {
        _qr = null;
        _status = 'disconnected';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp desconectado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          _status == 'connected' ? Icons.check_circle : Icons.message,
                          size: 64,
                          color: _status == 'connected' ? Colors.green : const Color(0xFF25D366),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _status == 'connected' ? 'Conectado' :
                          _status == 'awaiting_scan' ? 'Escaneie o QR Code' :
                          _status == 'connecting' ? 'Conectando...' :
                          _status == 'disconnected' ? 'Desconectado' :
                          _status == 'erro' ? 'Erro de conexao' :
                          _status == 'timeout' ? 'Servidor incompativel' :
                          'Verificando...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _status == 'connected' ? Colors.green : Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status == 'connected'
                              ? 'WhatsApp conectado e pronto para enviar relatorios'
                              : _status == 'awaiting_scan'
                                  ? 'Abra o WhatsApp no seu celular, va em Menu > WhatsApp Web e escaneie o QR code abaixo'
                                  : _status == 'timeout'
                                      ? 'O servidor Railway nao suporta conexao WhatsApp direta. Use um webhook externo ou atualize para o plano Hobby.'
                                      : 'Inicie a conexao com o WhatsApp para enviar relatorios automaticamente',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_qr != null) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Image.memory(
                        base64Decode(_qr!.split(',').last),
                        width: 280,
                        height: 280,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Abra o WhatsApp no seu celular',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '2. Toque em Menu (3 pontos) > WhatsApp Web',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '3. Aponte a camera para o QR code',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Verificar novamente'),
                  ),
                ],
                if (_status == 'connected')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Desconectar WhatsApp', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                if (_status == 'erro' || _status == 'disconnected' || _status == 'timeout')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
              ],
            ),
    );
  }
}
