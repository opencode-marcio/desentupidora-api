import 'package:flutter_test/flutter_test.dart';
import 'package:desentupidora_app/src/models/photo_model.dart';

void main() {
  group('PhotoModel', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': 1,
        'serviceOrderId': 1,
        'filename': 'foto_123.jpg',
        'originalName': 'foto.jpg',
        'type': 'before',
        'latitude': -23.561,
        'longitude': -46.656,
        'annotations': '{"marks":[]}',
        'takenAt': '2026-06-22T10:30:00.000Z',
      };

      final photo = PhotoModel.fromJson(json);

      expect(photo.id, 1);
      expect(photo.serviceOrderId, 1);
      expect(photo.filename, 'foto_123.jpg');
      expect(photo.originalName, 'foto.jpg');
      expect(photo.type, 'before');
      expect(photo.latitude, -23.561);
      expect(photo.longitude, -46.656);
      expect(photo.annotations, '{"marks":[]}');
      expect(photo.takenAt, DateTime.utc(2026, 6, 22, 10, 30, 0));
    });

    test('fromJson usa valores padrao para campos nulos', () {
      final json = {
        'serviceOrderId': 1,
        'filename': 'foto.jpg',
        'originalName': 'original.jpg',
        'type': 'during',
      };

      final photo = PhotoModel.fromJson(json);

      expect(photo.id, isNull);
      expect(photo.serviceOrderId, 1);
      expect(photo.filename, 'foto.jpg');
      expect(photo.originalName, 'original.jpg');
      expect(photo.type, 'during');
      expect(photo.latitude, isNull);
      expect(photo.longitude, isNull);
      expect(photo.annotations, isNull);
      expect(photo.takenAt, isNull);
    });

    test('fromJson converte latitude para double', () {
      final json = {
        'serviceOrderId': 1,
        'filename': 'f.jpg',
        'originalName': 'f.jpg',
        'type': 'after',
        'latitude': 10,
        'longitude': 20,
      };

      final photo = PhotoModel.fromJson(json);

      expect(photo.latitude, isA<double>());
      expect(photo.longitude, isA<double>());
    });

    test('type padrao é during', () {
      final json = {
        'serviceOrderId': 1,
        'filename': 'f.jpg',
        'originalName': 'f.jpg',
      };

      final photo = PhotoModel.fromJson(json);

      expect(photo.type, 'during');
    });
  });
}
