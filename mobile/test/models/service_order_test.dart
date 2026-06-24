import 'package:flutter_test/flutter_test.dart';
import 'package:desentupidora_app/src/models/service_order.dart';

void main() {
  group('ServiceOrder', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': 1,
        'clientName': 'João Cliente',
        'clientAddress': 'Rua Teste, 123',
        'clientPhone': '11999999999',
        'description': 'Desentupimento de pia',
        'status': 'completed',
        'notes': 'Serviço concluído',
        'userId': 1,
        'createdAt': '2026-06-22T10:00:00.000Z',
        'completedAt': '2026-06-22T12:00:00.000Z',
        'Photos': [],
      };

      final order = ServiceOrder.fromJson(json);

      expect(order.id, 1);
      expect(order.clientName, 'João Cliente');
      expect(order.clientAddress, 'Rua Teste, 123');
      expect(order.clientPhone, '11999999999');
      expect(order.description, 'Desentupimento de pia');
      expect(order.status, 'completed');
      expect(order.notes, 'Serviço concluído');
      expect(order.userId, 1);
      expect(order.createdAt, DateTime.utc(2026, 6, 22, 10, 0, 0));
      expect(order.completedAt, DateTime.utc(2026, 6, 22, 12, 0, 0));
      expect(order.photos, isEmpty);
    });

    test('fromJson usa valores padrao para campos nulos', () {
      final json = {
        'clientName': 'Maria',
        'clientAddress': 'Av Paulista',
      };

      final order = ServiceOrder.fromJson(json);

      expect(order.clientName, 'Maria');
      expect(order.clientAddress, 'Av Paulista');
      expect(order.status, 'pending');
      expect(order.userId, 0);
      expect(order.createdAt, isNull);
      expect(order.completedAt, isNull);
    });

    test('toJson retorna apenas campos de envio', () {
      final order = ServiceOrder(
        id: 1,
        clientName: 'João',
        clientAddress: 'Rua A',
        clientPhone: '11988888888',
        description: 'Teste',
        status: 'in_progress',
        notes: 'observação',
        userId: 1,
        createdAt: DateTime(2026, 6, 22),
        completedAt: null,
      );

      final json = order.toJson();

      expect(json, {
        'clientName': 'João',
        'clientAddress': 'Rua A',
        'clientPhone': '11988888888',
        'description': 'Teste',
        'status': 'in_progress',
        'notes': 'observação',
      });
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });

    test('status padrao é pending', () {
      final order = ServiceOrder(
        id: null,
        clientName: 'Teste',
        clientAddress: 'Endereço',
        userId: 1,
      );

      expect(order.status, 'pending');
    });
  });
}
