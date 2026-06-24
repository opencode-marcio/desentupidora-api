import 'package:flutter/material.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/register_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/order_detail_screen.dart';
import 'src/screens/splash_screen.dart';
import 'src/services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(const DesentupidoraApp());
}

class DesentupidoraApp extends StatelessWidget {
  const DesentupidoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FotoLaudo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      themeMode: ThemeMode.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/order-detail') {
          final orderId = settings.arguments as int;
          return MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId));
        }
        return null;
      },
    );
  }
}
