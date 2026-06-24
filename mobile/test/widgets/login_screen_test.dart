import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desentupidora_app/src/screens/login_screen.dart';
import 'package:desentupidora_app/src/services/api_service.dart';

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

  testWidgets('rende o icone e campo de email', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.byIcon(Icons.plumbing), findsOneWidget);
    expect(find.text('Desentupidora App'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  testWidgets('mostra campos de email e senha', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('mostra erro ao tentar login com campos vazios', (tester) async {
    when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => http.Response(
      '{"error": "Email ou senha invalidos"}',
      401,
    ));

    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Email'), findsWidgets);
  });

  testWidgets('botao Entrar esta presente', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    final button = find.widgetWithText(ElevatedButton, 'Entrar');
    expect(button, findsOneWidget);
  });

  testWidgets('link Criar conta navega para register', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const Scaffold(
            body: Text('Register Screen'),
          ),
        },
      ),
    );

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Register Screen'), findsOneWidget);
  });
}
