import '../models/userModel.dart';
import '../datasources/userDao.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserRepository {
  final UserDao userDao = UserDao();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // Registrar usuario
  Future<bool> registerUser(String username, String email, String password) async {
    final existingUserByUsername = await userDao.getUserByUsername(username);
    final existingUserByEmail = await userDao.getUserByEmail(email);

    if (existingUserByUsername != null || existingUserByEmail != null) {
      return false;
    }

    final hashedPassword = _hashPassword(password);
    final user = UserModel(username: username, email: email, password: hashedPassword);
    await userDao.insertUser(user);
    return true;
  }

  // Login ahora devuelve el usuario completo o null
  Future<UserModel?> loginUser(String username, String password) async {
    final user = await userDao.getUserByUsername(username);
    if (user == null) return null;

    final hashedPassword = _hashPassword(password);
    if (user.password == hashedPassword) {
      return user;
    }
    return null;
  }
}
