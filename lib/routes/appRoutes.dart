import 'package:flutter/material.dart';
import '../presentation/pages/loginPage.dart';
import '../presentation/pages/homePage.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    home: (context) => const HomePage(),
  };
}
