import 'package:flutter/material.dart';
import 'package:appmovil/presentation/pages/loginPage.dart';
import 'package:appmovil/presentation/pages/homePage.dart';

/// Clase para pasar argumentos a HomePage
class HomePageArgs {
  final String username;
  final String userId;

  HomePageArgs({required this.username, required this.userId});
}

class AppRoutes {
  /// Rutas fijas
  static Map<String, WidgetBuilder> routes = {
    '/login': (context) => const LoginPage(),
  };

  /// Rutas dinámicas con argumentos
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/home':
        final args = settings.arguments as HomePageArgs;
        return MaterialPageRoute(
          builder: (context) => HomePage(
            username: args.username,
            userId: args.userId,
          ),
        );
      default:
        return null;
    }
  }
}
