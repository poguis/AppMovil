import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';
import 'database_service.dart';

class UserService {
  // Crear un nuevo usuario
  static Future<int> createUser(String username, String password, {String? email}) async {
    final db = await DatabaseService.database;
    final passwordHash = _hashPassword(password);
    
    final user = User(
      username: username,
      passwordHash: passwordHash,
      email: email,
      createdAt: DateTime.now(),
    );

    return await db.insert('users', user.toMap());
  }

  // Verificar login
  static Future<User?> login(String username, String password) async {
    final db = await DatabaseService.database;
    final passwordHash = _hashPassword(password);
    
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );

    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  // Verificar si el usuario existe
  static Future<bool> userExists(String username) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    return result.isNotEmpty;
  }

  // Obtener usuario por ID
  static Future<User?> getUserById(int id) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  // Hash de contraseña
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
