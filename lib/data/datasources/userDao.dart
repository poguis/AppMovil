//import 'package:sqflite/sqflite.dart';
import '../../core/database/appDatabase.dart';
import '../models/userModel.dart';

class UserDao {
  Future<int> insertUser(UserModel user) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('users', user.toMap());
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (result.isNotEmpty) {
      return UserModel.fromMap(result.first);
    }
    return null;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await AppDatabase.instance.database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (result.isNotEmpty) {
      return UserModel.fromMap(result.first);
    }
    return null;
  }


}
