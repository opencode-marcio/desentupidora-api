import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desentupidora_app/src/services/api_service.dart';
import 'package:desentupidora_app/src/models/service_order.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    mockClient = MockHttpClient();
    ApiService.setClient(mockClient);
    SharedPreferences.setMockInitialValues({});
  });

  group('login', () {
    test('retorna dados no sucesso', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'token': 'abc123',
          'user': {'id': 1, 'name': 'Teste', 'email': 'teste@teste.com'},
        }),
        200,
      ));

      final result = await ApiService.login('teste@teste.com', '123456');

      expect(result['token'], 'abc123');
      expect(result['user']['name'], 'Teste');
    });

    test('retorna erro com credenciais invalidas', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Email ou senha invalidos'}),
        401,
      ));

      final result = await ApiService.login('teste@teste.com', 'errada');

      expect(result['error'], 'Email ou senha invalidos');
    });
  });

  group('register', () {
    test('retorna dados no cadastro', () async {
      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'token': 'token123',
          'user': {'id': 2, 'name': 'Novo', 'email': 'novo@teste.com'},
        }),
        201,
      ));

      final result = await ApiService.register(
          'Novo', 'novo@teste.com', '123456', 'Empresa', '11999999999');

      expect(result['token'], 'token123');
      expect(result['user']['name'], 'Novo');
    });
  });

  group('getMe', () {
    test('retorna dados do usuario', () async {
      SharedPreferences.setMockInitialValues({'token': 'valid_token'});

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'user': {'id': 1, 'name': 'Teste', 'email': 'teste@teste.com'},
        }),
        200,
      ));

      final result = await ApiService.getMe();

      expect(result['user']['name'], 'Teste');
    });

    test('lanca excecao sem token', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Token nao fornecido'}),
        401,
      ));

      expect(() => ApiService.getMe(), throwsException);
    });
  });

  group('getOrders', () {
    test('retorna lista paginada de ordens', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'orders': [
            {'id': 1, 'clientName': 'Cliente A', 'clientAddress': 'Rua A'},
            {'id': 2, 'clientName': 'Cliente B', 'clientAddress': 'Rua B'},
          ],
          'total': 2,
          'page': 1,
          'totalPages': 1,
        }),
        200,
      ));

      final result = await ApiService.getOrders();

      expect(result['total'], 2);
      expect(result['orders'].length, 2);
      expect(result['orders'][0].clientName, 'Cliente A');
      expect(result['orders'][1].clientName, 'Cliente B');
    });
  });

  group('createOrder', () {
    test('cria ordem com sucesso', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});
      final order = ServiceOrder(
        clientName: 'Novo Cliente',
        clientAddress: 'Rua Nova',
        userId: 1,
      );

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'id': 1,
          'clientName': 'Novo Cliente',
          'clientAddress': 'Rua Nova',
          'status': 'pending',
          'userId': 1,
        }),
        201,
      ));

      final result = await ApiService.createOrder(order);

      expect(result.id, 1);
      expect(result.clientName, 'Novo Cliente');
    });
  });

  group('shareReport', () {
    test('retorna link compartilhavel', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'link': 'http://localhost:3000/r/uuid-123',
          'token': 'uuid-123',
        }),
        200,
      ));

      final result = await ApiService.shareReport(1);

      expect(result['link'], contains('/r/'));
      expect(result['token'], 'uuid-123');
    });
  });

  group('downloadPdf', () {
    test('retorna bytes do PDF', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response.bytes(
        [37, 80, 68, 70],
        200,
      ));

      final result = await ApiService.downloadPdf(1);

      expect(result, [37, 80, 68, 70]);
    });
  });

  group('deletePhoto', () {
    test('remove foto com sucesso', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.delete(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({'message': 'Foto removida'}),
        200,
      ));

      await expectLater(ApiService.deletePhoto(1), completes);
    });

    test('lanca excecao quando falha', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.delete(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({'error': 'Nao encontrada'}),
        404,
      ));

      expect(() => ApiService.deletePhoto(999), throwsException);
    });
  });

  group('updateProfile', () {
    test('atualiza perfil com sucesso', () async {
      SharedPreferences.setMockInitialValues({'token': 'token'});

      when(() => mockClient.put(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'user': {'id': 1, 'name': 'Atualizado', 'email': 'teste@teste.com'},
        }),
        200,
      ));

      final result = await ApiService.updateProfile({'name': 'Atualizado'});

      expect(result['user']['name'], 'Atualizado');
    });
  });

  group('init / baseUrl', () {
    test('usa URL padrao quando nao configurada', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiService.init();
      expect(ApiService.baseUrl, 'http://localhost:3000');
    });

    test('carrega URL salva', () async {
      SharedPreferences.setMockInitialValues(
          {'api_base_url': 'http://meu-servidor:8080'});
      await ApiService.init();
      expect(ApiService.baseUrl, 'http://meu-servidor:8080');
    });
  });
}
