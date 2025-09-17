import 'package:sqflite/sqflite.dart' as sql;
import '../models/transaction.dart' as model;
import 'database_service.dart';
import 'money_service.dart';

class TransactionService {
  // Crear nueva transacción
  static Future<int> createTransaction(model.Transaction transaction) async {
    final db = await DatabaseService.database;
    
    // Crear la transacción
    final transactionId = await db.insert('transactions', transaction.toMap());
    
    // Actualizar el balance de dinero
    if (transaction.type == 'income') {
      await MoneyService.addMoney(transaction.userId, transaction.amount);
    } else if (transaction.type == 'expense') {
      await MoneyService.subtractMoney(transaction.userId, transaction.amount);
    }
    
    return transactionId;
  }

  // Obtener transacciones del usuario
  static Future<List<model.Transaction>> getUserTransactions(int userId, {int? limit}) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
      limit: limit,
    );

    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  // Obtener transacciones por tipo
  static Future<List<model.Transaction>> getTransactionsByType(int userId, String type) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'transactions',
      where: 'user_id = ? AND type = ?',
      whereArgs: [userId, type],
      orderBy: 'date DESC',
    );

    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  // Obtener transacciones por categoría
  static Future<List<model.Transaction>> getTransactionsByCategory(int userId, int categoryId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'transactions',
      where: 'user_id = ? AND category_id = ?',
      whereArgs: [userId, categoryId],
      orderBy: 'date DESC',
    );

    return result.map((map) => model.Transaction.fromMap(map)).toList();
  }

  // Obtener transacciones con información de categoría
  static Future<List<Map<String, dynamic>>> getTransactionsWithCategory(int userId, {int? limit}) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        c.color as category_color,
        c.icon as category_icon
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ?
      ORDER BY t.date DESC
      ${limit != null ? 'LIMIT $limit' : ''}
    ''', [userId]);

    return result;
  }

  // Eliminar transacción
  static Future<void> deleteTransaction(int transactionId, int userId) async {
    final db = await DatabaseService.database;
    
    // Obtener la transacción antes de eliminarla
    final transaction = await db.query(
      'transactions',
      where: 'id = ? AND user_id = ?',
      whereArgs: [transactionId, userId],
    );

    if (transaction.isNotEmpty) {
      final trans = model.Transaction.fromMap(transaction.first);
      
      // Revertir el cambio en el balance
      if (trans.type == 'income') {
        await MoneyService.subtractMoney(userId, trans.amount);
      } else if (trans.type == 'expense') {
        await MoneyService.addMoney(userId, trans.amount);
      }
      
      // Eliminar la transacción
      await db.delete(
        'transactions',
        where: 'id = ? AND user_id = ?',
        whereArgs: [transactionId, userId],
      );
    }
  }
}
