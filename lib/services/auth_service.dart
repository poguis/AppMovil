import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'user_service.dart';

class AuthService {
  static const String _userIdKey = 'current_user_id';
  static const String _usernameKey = 'current_username';
  
  static User? _currentUser;

  // Obtener usuario actual
  static User? get currentUser => _currentUser;

  // Verificar si hay usuario logueado
  static bool get isLoggedIn => _currentUser != null;

  // Login
  static Future<bool> login(String username, String password) async {
    try {
      final user = await UserService.login(username, password);
      if (user != null) {
        _currentUser = user;
        await _saveUserSession(user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Registro
  static Future<bool> register(String username, String password, {String? email}) async {
    try {
      // Verificar si el usuario ya existe
      if (await UserService.userExists(username)) {
        return false; // Usuario ya existe
      }

      // Crear nuevo usuario
      final userId = await UserService.createUser(username, password, email: email);
      if (userId > 0) {
        // Obtener el usuario creado
        final user = await UserService.getUserById(userId);
        if (user != null) {
          _currentUser = user;
          await _saveUserSession(user);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Logout
  static Future<void> logout() async {
    _currentUser = null;
    await _clearUserSession();
  }

  // Cargar sesión guardada
  static Future<bool> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_userIdKey);
      
      if (userId != null) {
        final user = await UserService.getUserById(userId);
        if (user != null) {
          _currentUser = user;
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Guardar sesión del usuario
  static Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user.id!);
    await prefs.setString(_usernameKey, user.username);
  }

  // Limpiar sesión del usuario
  static Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
