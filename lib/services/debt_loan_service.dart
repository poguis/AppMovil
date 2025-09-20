import 'package:sqflite/sqflite.dart';
import '../models/debt_loan.dart';
import 'database_service.dart';

class DebtLoanService {
  // Crear nueva deuda o préstamo
  static Future<int> createDebtLoan(DebtLoan debtLoan) async {
    final db = await DatabaseService.database;
    return await db.insert('debts_loans', debtLoan.toMap());
  }

  // Obtener deudas del usuario (lo que debe)
  static Future<List<DebtLoan>> getUserDebts(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'debts_loans',
      where: 'user_id = ? AND type = ?',
      whereArgs: [userId, 'debt'],
      orderBy: 'date_created DESC',
    );

    return result.map((map) => DebtLoan.fromMap(map)).toList();
  }

  // Obtener préstamos del usuario (lo que le deben)
  static Future<List<DebtLoan>> getUserLoans(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'debts_loans',
      where: 'user_id = ? AND type = ?',
      whereArgs: [userId, 'loan'],
      orderBy: 'date_created DESC',
    );

    return result.map((map) => DebtLoan.fromMap(map)).toList();
  }

  // Obtener todas las deudas y préstamos
  static Future<List<DebtLoan>> getAllDebtsLoans(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'debts_loans',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'type ASC, date_created DESC',
    );

    return result.map((map) => DebtLoan.fromMap(map)).toList();
  }

  // Marcar como pagado
  static Future<void> markAsPaid(int debtLoanId, int userId) async {
    final db = await DatabaseService.database;
    await db.update(
      'debts_loans',
      {'is_paid': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [debtLoanId, userId],
    );
  }

  // Marcar como no pagado
  static Future<void> markAsUnpaid(int debtLoanId, int userId) async {
    final db = await DatabaseService.database;
    await db.update(
      'debts_loans',
      {'is_paid': 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: [debtLoanId, userId],
    );
  }

  // Actualizar deuda o préstamo
  static Future<void> updateDebtLoan(DebtLoan debtLoan) async {
    final db = await DatabaseService.database;
    await db.update(
      'debts_loans',
      debtLoan.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [debtLoan.id, debtLoan.userId],
    );
  }

  // Eliminar deuda o préstamo
  static Future<void> deleteDebtLoan(int debtLoanId) async {
    final db = await DatabaseService.database;
    await db.delete(
      'debts_loans',
      where: 'id = ?',
      whereArgs: [debtLoanId],
    );
  }

  // Obtener total de deudas
  static Future<double> getTotalDebts(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM debts_loans
      WHERE user_id = ? AND type = ? AND is_paid = 0
    ''', [userId, 'debt']);

    return result.first['total'] as double? ?? 0.0;
  }

  // Obtener total de préstamos
  static Future<double> getTotalLoans(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM debts_loans
      WHERE user_id = ? AND type = ? AND is_paid = 0
    ''', [userId, 'loan']);

    return result.first['total'] as double? ?? 0.0;
  }

  // Limpiar registros pagados (método de utilidad)
  static Future<void> cleanPaidRecords(int userId) async {
    final db = await DatabaseService.database;
    await db.delete(
      'debts_loans',
      where: 'user_id = ? AND is_paid = 1',
      whereArgs: [userId],
    );
  }
}
