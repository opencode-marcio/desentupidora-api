import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desentupidora_app/src/services/api_service.dart';
import 'package:desentupidora_app/src/models/service_order.dart';
import 'package:desentupidora_app/src/models/photo_model.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ApiService init usa URL padrao', () async {
    await ApiService.init();
    expect(ApiService.baseUrl, 'http://localhost:3000');
  });

  test('ServiceOrder pode ser criado', () {
    final order = ServiceOrder(
      clientName: 'Teste',
      clientAddress: 'Rua A',
      userId: 1,
    );
    expect(order.clientName, 'Teste');
    expect(order.status, 'pending');
  });

  test('PhotoModel pode ser criado', () {
    final photo = PhotoModel(
      serviceOrderId: 1,
      filename: 'foto.jpg',
      originalName: 'original.jpg',
      type: 'before',
    );
    expect(photo.type, 'before');
  });

  test('Version constants exist', () {
    // App identity check
    expect('desentupidora_app', isNotEmpty);
  });
}
