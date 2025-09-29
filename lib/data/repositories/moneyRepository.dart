//import 'package:sqflite/sqflite.dart';
import '../../core/database/appDatabase.dart';

class MoneyRepository {
  final dbProvider = AppDatabase.instance;

  // -------------------------
  // DINERO ACTUAL
  // -------------------------
  Future<double?> getUserMoney(String userId) async {
    final db = await dbProvider.database;
    final result = await db.query(
      'user_money',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['amount'] as double;
    }
    return null;
  }

  Future<void> setUserMoney(String userId, double amount) async {
    final db = await dbProvider.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'user_money',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('user_money', {
        'user_id': userId,
        'amount': amount,
        'updated_at': now,
      });
    } else {
      await db.update(
        'user_money',
        {'amount': amount, 'updated_at': now},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
  }

  // -------------------------
  // CATEGORÍAS
  // -------------------------
  Future<int> addCategory(String userId, String name, String type) async {
    final db = await dbProvider.database;
    return await db.insert('categories', {
      'user_id': userId,
      'name': name,
      'type': type, // base o custom
    });
  }

  Future<List<Map<String, dynamic>>> getCategories(String userId) async {
    final db = await dbProvider.database;
    return await db.query('categories', where: 'user_id = ?', whereArgs: [userId]);
  }

  // -------------------------
  // PERSONAS (Deudas/Préstamos)
  // -------------------------
  Future<int> addPerson(String userId, String name) async {
    final db = await dbProvider.database;
    // Verificar si ya existe
    final existing = await db.query(
      'persons',
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, name],
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    return await db.insert('persons', {'user_id': userId, 'name': name});
  }

  Future<List<Map<String, dynamic>>> getPersons(String userId) async {
    final db = await dbProvider.database;
    return await db.query('persons', where: 'user_id = ?', whereArgs: [userId]);
  }

  // -------------------------
  // DEUDAS / PRÉSTAMOS
  // -------------------------
  Future<int> addDebtLoan({
    required String userId,
    required int personId,
    required String type, // "debt" o "loan"
    required double amount,
    String? description,
  }) async {
    final db = await dbProvider.database;
    final now = DateTime.now().toIso8601String();

    // Verificar si ya existe un registro para esa persona y tipo
    final existing = await db.query(
      'debts_loans',
      where: 'user_id = ? AND person_id = ? AND type = ?',
      whereArgs: [userId, personId, type],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Sumar cantidad existente
      final currentAmount = existing.first['amount'] as double;
      return await db.update(
        'debts_loans',
        {'amount': currentAmount + amount, 'description': description, 'created_at': now},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      return await db.insert('debts_loans', {
        'user_id': userId,
        'person_id': personId,
        'type': type,
        'amount': amount,
        'description': description,
        'created_at': now,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getDebtsLoans(String userId) async {
    final db = await dbProvider.database;
    return await db.query('debts_loans', where: 'user_id = ?', whereArgs: [userId]);
  }

  // -------------------------
  // TRANSACCIONES (HISTORIAL)
  // -------------------------
  Future<int> addTransaction({
    required String userId,
    required int categoryId,
    int? personId,
    required String type, // "add" o "remove"
    required double amount,
    String? description,
  }) async {
    final db = await dbProvider.database;
    final now = DateTime.now().toIso8601String();

    return await db.insert('transactions', {
      'user_id': userId,
      'category_id': categoryId,
      'person_id': personId,
      'type': type,
      'amount': amount,
      'description': description,
      'created_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    final db = await dbProvider.database;
    return await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }
}
