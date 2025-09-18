import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class PersonService {
  // Obtener todas las personas de deudas y préstamos
  static Future<List<String>> getAllPersons(int userId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT person_name 
      FROM debts_loans 
      WHERE user_id = ? 
      ORDER BY person_name ASC
    ''', [userId]);

    return result.map((row) => row['person_name'] as String).toList();
  }

  // Obtener personas por tipo (deuda o préstamo)
  static Future<List<String>> getPersonsByType(int userId, String type) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT person_name 
      FROM debts_loans 
      WHERE user_id = ? AND type = ?
      ORDER BY person_name ASC
    ''', [userId, type]);

    return result.map((row) => row['person_name'] as String).toList();
  }

  // Obtener información detallada de deudas/préstamos por persona
  static Future<List<Map<String, dynamic>>> getDebtLoanDetailsByPerson(int userId, String personName, String type) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT id, amount, description, date_created, is_paid
      FROM debts_loans 
      WHERE user_id = ? AND person_name = ? AND type = ? AND is_paid = 0
      ORDER BY date_created DESC
    ''', [userId, personName, type]);

    return result;
  }

  // Obtener total pendiente por persona
  static Future<double> getTotalPendingByPerson(int userId, String personName, String type) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM debts_loans 
      WHERE user_id = ? AND person_name = ? AND type = ? AND is_paid = 0
    ''', [userId, personName, type]);

    return result.first['total'] as double? ?? 0.0;
  }
}
