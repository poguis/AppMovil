import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class MoneyService {
  // Obtener el dinero actual del usuario
  static Future<double> getCurrentMoney(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'money_balance',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      return result.first['amount'] as double;
    }
    return 0.0;
  }

  // Establecer el dinero actual del usuario
  static Future<void> setCurrentMoney(int userId, double amount) async {
    final db = await DatabaseService.database;
    
    // Verificar si ya existe un registro
    final existing = await db.query(
      'money_balance',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (existing.isNotEmpty) {
      // Actualizar registro existente
      await db.update(
        'money_balance',
        {
          'amount': amount,
          'last_updated': DateTime.now().toIso8601String(),
        },
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } else {
      // Crear nuevo registro
      await db.insert('money_balance', {
        'user_id': userId,
        'amount': amount,
        'last_updated': DateTime.now().toIso8601String(),
      });
    }
  }

  // Agregar dinero
  static Future<void> addMoney(int userId, double amount) async {
    final currentMoney = await getCurrentMoney(userId);
    await setCurrentMoney(userId, currentMoney + amount);
  }

  // Restar dinero
  static Future<void> subtractMoney(int userId, double amount) async {
    final currentMoney = await getCurrentMoney(userId);
    final newAmount = (currentMoney - amount).clamp(0.0, double.infinity);
    await setCurrentMoney(userId, newAmount);
  }

  // Verificar si hay dinero registrado
  static Future<bool> hasMoneyRegistered(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'money_balance',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result.isNotEmpty && (result.first['amount'] as double) > 0;
  }

  // Migrar datos de SharedPreferences (para compatibilidad)
  static Future<void> migrateFromSharedPreferences(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMoney = prefs.getDouble('current_money') ?? 0.0;
    
    if (currentMoney > 0) {
      await setCurrentMoney(userId, currentMoney);
      await prefs.remove('current_money');
    }
  }
}