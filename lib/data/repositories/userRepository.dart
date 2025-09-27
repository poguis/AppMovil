// ignore: file_names
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

  Future<bool> registerUser(String username, String email, String password) async {
    // Verificar si ya existe el usuario
    final existingUserByUsername = await userDao.getUserByUsername(username);
    // Verificar si ya existe el email
    final existingUserByEmail = await userDao.getUserByEmail(email);

    if (existingUserByUsername != null || existingUserByEmail != null) {
      // Si ya existe usuario o correo, no permitir registro
      return false;
    }

    // Hashear contraseña
    final hashedPassword = _hashPassword(password);

    // Crear usuario nuevo
    final user = UserModel(username: username, email: email, password: hashedPassword);
    await userDao.insertUser(user);
    return true;
  }


  Future<bool> loginUser(String username, String password) async {
    final user = await userDao.getUserByUsername(username);
    if (user == null) return false;

    final hashedPassword = _hashPassword(password);
    return user.password == hashedPassword;
  }
}
