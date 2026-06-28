import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/service_order.dart';
import 'photo_annotation_screen.dart';
import 'signature_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  ServiceOrder? _order;
  bool _loading = true;
  bool _sendingPhoto = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    try {
      final order = await ApiService.getOrder(widget.orderId);
      setState(() => _order = order);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _takePhoto(String type) async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissao de GPS necessaria')));
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAnnotationScreen(
          imagePath: file.path,
          photoType: type,
        ),
      ),
    );

    if (result == null) return;

    setState(() => _sendingPhoto = true);
    try {
      Position position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (_) {
        position = Position(
          longitude: 0, latitude: 0, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, altitudeAccuracy: 0,
          heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
        );
      }

      await ApiService.uploadPhotos(
        widget.orderId,
        [File(result['imagePath'])],
        type,
        position.latitude,
        position.longitude,
        annotations: result['annotations'],
      );

      await _loadOrder();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Foto salva!')]),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    }
    setState(() => _sendingPhoto = false);
  }

  Future<void> _startOrder() async {
    setState(() => _updatingStatus = true);
    try {
      await ApiService.updateOrder(widget.orderId, {'status': 'in_progress'});
      await _loadOrder();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Servico iniciado!')]),
        backgroundColor: Colors.orange,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    setState(() => _updatingStatus = false);
  }

  Future<void> _completeOrder() async {
    final signature = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SignatureScreen()),
    );

    if (signature == null) return;

    setState(() => _updatingStatus = true);
    try {
      await ApiService.completeOrder(widget.orderId, clientSignature: signature);
      await _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('Ordem concluida!')]),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    setState(() => _updatingStatus = false);
  }

  Future<void> _generateAndSend() async {
    setState(() => _updatingStatus = true);
    try {
      final result = await ApiService.generateAndSend(widget.orderId);

      if (mounted) {
        final message = result['message'] as String? ?? 'Relatorio enviado!';
        final sendMethod = result['sendMethod'] as String?;
        final isSuccess = sendMethod == 'whatsapp_interno' || sendMethod == 'webhook' || sendMethod == 'falha_whatsapp_webhook_ok';

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(isSuccess ? Icons.check_circle : Icons.warning_amber, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ]),
          backgroundColor: isSuccess ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ));
      }

      final prefs = await SharedPreferences.getInstance();
      final autoSave = prefs.getBool('auto_save_pdf') ?? true;
      if (autoSave) {
        final pdfBytes = await ApiService.downloadPdf(widget.orderId);
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) dir = null;
        }
        dir ??= await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/relatorio_${widget.orderId}.pdf');
        await file.writeAsBytes(pdfBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(children: [Icon(Icons.save_alt, color: Colors.white), SizedBox(width: 8), Text('PDF salvo em ${dir.path.replaceAll('/storage/emulated/0', '')}')]),
            backgroundColor: Colors.blue,
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
    setState(() => _updatingStatus = false);
  }

  Future<void> _sendToClient() async {
    if (_order?.clientPhone == null || _order!.clientPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente sem telefone cadastrado')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.shareReport(widget.orderId);
      if (mounted) Navigator.pop(context);

      final link = result['link'] as String;
      final phone = _order!.clientPhone!.replaceAll(RegExp(r'[^\d]'), '');
      final msg = Uri.encodeComponent(
        'Ola! *Segue o relatorio do servico realizado:*\n$link',
      );
      final waApp = 'whatsapp://send?phone=55$phone&text=$msg';
      final waWeb = 'https://wa.me/55$phone?text=$msg';
      try {
        await launchUrl(Uri.parse(waApp), mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(Uri.parse(waWeb), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _deletePhoto(int photoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto'),
        content: const Text('Tem certeza que deseja remover esta foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deletePhoto(photoId);
      await _loadOrder();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto removida')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao remover: $e')));
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'preventive': return 'Preventiva';
      case 'corrective': return 'Corretiva';
      case 'budget': return 'Orcamento';
      default: return cat;
    }
  }

  void _openPhoto(String url) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }),
          ),
        ),
      ),
    ));
  }

  Widget _photoGrid(List<dynamic>? photos, String type, {bool deletable = false}) {
    if (photos == null || photos.isEmpty) return const SizedBox.shrink();
    final filtered = photos.where((p) => p['type'] == type).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(type == 'before' ? 'ANTES' : type == 'after' ? 'DEPOIS' : 'DURANTE',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final p = filtered[index];
              final url = '${ApiService.baseUrl}/uploads/${p['filename']}';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _openPhoto(url),
                        child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(width: 100, height: 100, color: Colors.grey[300], child: const Icon(Icons.broken_image))),
                      ),
                      if (deletable)
                        Positioned(
                          top: 0, right: 0,
                          child: GestureDetector(
                            onTap: () => _deletePhoto(p['id']),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final order = _order!;
    final date = order.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!) : '';

    return Scaffold(
      appBar: AppBar(title: Text(order.clientName)),
      body: RefreshIndicator(
        onRefresh: _loadOrder,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.clientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Endereco: ${order.clientAddress}'),
                      if (order.clientPhone != null) Text('Telefone: ${order.clientPhone}'),
                      Text('Data: $date'),
                      if (order.serviceCategory != null) Text('Categoria: ${_categoryLabel(order.serviceCategory!)}'),
                      if (order.description != null && order.description!.isNotEmpty) Text('Descricao: ${order.description}'),
                      if (order.preExistingDamage) Text('Dano pre-existente: Sim', style: const TextStyle(color: Colors.red)),
                      if (order.recommendations != null && order.recommendations!.isNotEmpty)
                        Text('Recomendacoes: ${order.recommendations}'),
                      const SizedBox(height: 8),
                      Chip(label: Text(order.status == 'completed' ? 'Concluido' : order.status == 'pending' ? 'Pendente' : 'Em andamento')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (order.photos != null) ...[
                _photoGrid(order.photos, 'before', deletable: order.status != 'completed'),
                _photoGrid(order.photos, 'during', deletable: order.status != 'completed'),
                _photoGrid(order.photos, 'after', deletable: order.status != 'completed'),
              ],

              if (order.status != 'completed') ...[
                const Divider(),
                if (_sendingPhoto)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.camera_alt), onPressed: _updatingStatus ? null : () => _takePhoto('before'), label: const Text('ANTES'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.camera_alt), onPressed: _updatingStatus ? null : () => _takePhoto('during'), label: const Text('DURANTE'))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.camera_alt), onPressed: _updatingStatus ? null : () => _takePhoto('after'), label: const Text('DEPOIS'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (order.status == 'pending')
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(
                      icon: _updatingStatus ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
                      onPressed: _updatingStatus ? null : _startOrder,
                      label: const Text('Iniciar Servico'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    )),
                  if (order.status == 'in_progress')
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(
                      icon: _updatingStatus ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle),
                      onPressed: _updatingStatus ? null : _completeOrder,
                      label: const Text('Concluir'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    )),
                ],
              ],
              if (order.status == 'completed') ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  icon: _updatingStatus ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                  onPressed: _updatingStatus ? null : _generateAndSend,
                  label: const Text('Gerar Relatorio e Enviar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
