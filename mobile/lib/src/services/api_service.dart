import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_order.dart';
import 'api_config.dart';

class _TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration timeout;
  _TimeoutClient(this._inner, this.timeout);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);
  @override
  void close() => _inner.close();
}

class ApiService {
  static String _baseUrl = ApiConfig.defaultBaseUrl;
  static String get baseUrl => _baseUrl;
  static const Duration _timeout = Duration(seconds: 30);
  static http.Client _client = _TimeoutClient(http.Client(), _timeout);

  static void setClient(http.Client client) {
    _client = client;
  }

  static Future<void> init() async {
    _baseUrl = await ApiConfig.getBaseUrl();
  }

  static String get _apiUrl => '$_baseUrl/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, String> data) async {
    final res = await _client.put(
      Uri.parse('$_apiUrl/auth/me'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao atualizar perfil');
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/auth/me'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Token invalido');
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password, String company, String phone) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'company': company,
        'phone': phone,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getOrders({int page = 1, int limit = 50}) async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/orders?page=$page&limit=$limit'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List orders = data['orders'];
      return {
        'orders': orders.map((j) => ServiceOrder.fromJson(j)).toList(),
        'total': data['total'],
        'page': data['page'],
        'totalPages': data['totalPages'],
      };
    }
    throw Exception('Erro ao carregar ordens');
  }

  static Future<ServiceOrder> createOrder(ServiceOrder order) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/orders'),
      headers: await _headers(),
      body: jsonEncode(order.toJson()),
    );
    if (res.statusCode == 201) {
      return ServiceOrder.fromJson(jsonDecode(res.body));
    }
    throw Exception('Erro ao criar ordem');
  }

  static Future<ServiceOrder> getOrder(int id) async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/orders/$id'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return ServiceOrder.fromJson(jsonDecode(res.body));
    }
    throw Exception('Erro ao carregar ordem');
  }

  static Future<ServiceOrder> updateOrder(int id, Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse('$_apiUrl/orders/$id'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return ServiceOrder.fromJson(jsonDecode(res.body));
    }
    throw Exception('Erro ao atualizar ordem');
  }

  static Future<List<dynamic>> uploadPhotos(
      int orderId, List<File> files, String type, double? lat, double? lng,
      {String? annotations}) async {
    final uri = Uri.parse('$_apiUrl/photos/upload/$orderId');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());
    request.fields['type'] = type;
    if (lat != null) request.fields['latitude'] = lat.toString();
    if (lng != null) request.fields['longitude'] = lng.toString();
    request.fields['takenAt'] = DateTime.now().toIso8601String();
    if (annotations != null) request.fields['annotations'] = annotations;

    for (final file in files) {
      if (!await file.exists()) {
        throw Exception('Arquivo nao encontrado: ${file.path}');
      }
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final mimeSubtype = ext == 'png' ? 'png' : 'jpeg';
      request.files.add(http.MultipartFile.fromBytes(
        'photos',
        bytes,
        filename: 'photo_${DateTime.now().millisecondsSinceEpoch}.$ext',
        contentType: http.MediaType('image', mimeSubtype),
      ));
    }

    final streamedRes = await _client.send(request);
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    final errMsg = res.body.isNotEmpty ? res.body : 'Erro ao enviar fotos';
    throw Exception(errMsg);
  }

  static Future<void> deletePhoto(int photoId) async {
    final res = await _client.delete(
      Uri.parse('$_apiUrl/photos/$photoId'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Erro ao remover foto');
    }
  }

  static Future<Map<String, dynamic>> completeOrder(int orderId, {String? clientSignature}) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/orders/$orderId/complete'),
      headers: await _headers(),
      body: jsonEncode({
        if (clientSignature != null) 'clientSignature': clientSignature,
      }),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final msg = res.body.isNotEmpty ? jsonDecode(res.body)['error'] : 'Erro ao concluir';
    throw Exception(msg ?? 'Erro ao concluir');
  }

  static Future<Map<String, dynamic>> generateAndSend(int orderId) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/orders/$orderId/generate-and-send'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final msg = res.body.isNotEmpty ? jsonDecode(res.body)['error'] : 'Erro ao gerar e enviar';
    throw Exception(msg ?? 'Erro ao gerar e enviar');
  }

  static Future<Map<String, dynamic>> shareReport(int orderId) async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/reports/$orderId/share'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Erro ao gerar link');
  }

  static Future<List<int>> downloadPdf(int orderId) async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/reports/$orderId/pdf'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Erro ao gerar PDF');
  }

  static Future<Map<String, dynamic>> updateCompany(Map<String, String> data) async {
    final res = await _client.put(
      Uri.parse('$_apiUrl/companies'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao atualizar empresa');
  }

  static Future<Map<String, dynamic>?> getCompany() async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/companies'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final body = res.body.trim();
      if (body.isEmpty || body == 'null') return null;
      return jsonDecode(body);
    }
    throw Exception('Erro ao carregar empresa');
  }

  static Future<Map<String, dynamic>> getWhatsAppStatus() async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/whatsapp/status'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Erro ao verificar status WhatsApp');
  }

  static Future<Map<String, dynamic>> getWhatsAppQR() async {
    final res = await _client.get(
      Uri.parse('$_apiUrl/whatsapp/qr'),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao obter QR code');
  }

  static Future<void> startWhatsApp() async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/whatsapp/start'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao iniciar WhatsApp');
    }
  }

  static Future<void> logoutWhatsApp() async {
    final res = await _client.post(
      Uri.parse('$_apiUrl/whatsapp/logout'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao desconectar WhatsApp');
    }
  }

  static Future<Map<String, dynamic>> uploadLogo(File file) async {
    final uri = Uri.parse('$_apiUrl/companies/logo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());
    final bytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'logo',
      bytes,
      filename: 'logo.png',
      contentType: http.MediaType('image', 'png'),
    ));
    final streamedRes = await _client.send(request);
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['error'] ?? 'Erro ao enviar logo');
  }
}
