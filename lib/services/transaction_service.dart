import 'package:sqflite/sqflite.dart' as sql;
import '../models/transaction.dart' as model;
import 'database_service.dart';
import 'money_service.dart';
import 'category_service.dart';
import 'debt_loan_service.dart';
import '../models/debt_loan.dart';

class TransactionService {
  // Crear nueva transacción
  static Future<int> createTransaction(model.Transaction transaction, {String? personName}) async {
    final db = await DatabaseService.database;
    
    // Crear la transacción
    final transactionId = await db.insert('transactions', transaction.toMap());
    
    // Actualizar el balance de dinero
    if (transaction.type == 'income') {
      await MoneyService.addMoney(transaction.userId, transaction.amount);
    } else if (transaction.type == 'expense') {
      await MoneyService.subtractMoney(transaction.userId, transaction.amount);
    }
    
    // Si es una categoría especial de deuda/préstamo, actualizar los registros
    if (transaction.categoryId != null && personName != null) {
      await _handleSpecialCategoryTransaction(transaction, personName);
    }
    
    return transactionId;
  }

  // Manejar transacciones de categorías especiales (deudas/préstamos)
  static Future<void> _handleSpecialCategoryTransaction(model.Transaction transaction, String personName) async {
    final category = await CategoryService.getCategoryById(transaction.categoryId!);
    if (category == null) return;

    // Determinar el tipo de deuda/préstamo
    String debtLoanType;
    if (transaction.type == 'income' && category.name == 'Me deben') {
      debtLoanType = 'loan'; // Me prestaron dinero
    } else if (transaction.type == 'expense' && (category.name == 'Debo' || category.name == 'Préstamos')) {
      debtLoanType = 'debt'; // Debo dinero
    } else {
      return; // No es una categoría especial
    }

    // Buscar registros existentes de esta persona
    final existingRecords = await DebtLoanService.getAllDebtsLoans(transaction.userId);
    final personRecords = existingRecords.where((record) => 
      record.personName == personName && record.type == debtLoanType && !record.isPaid
    ).toList();

    if (personRecords.isNotEmpty) {
      // Hay registros existentes, actualizar el monto
      final totalExisting = personRecords.fold(0.0, (sum, record) => sum + record.amount);
      
      if (transaction.type == 'income') {
        // Me dieron dinero, reducir la deuda
        await _reduceDebtLoanAmount(transaction.userId, personName, debtLoanType, transaction.amount);
      } else {
        // Gasté dinero, aumentar la deuda
        await _increaseDebtLoanAmount(transaction.userId, personName, debtLoanType, transaction.amount);
      }
    } else {
      // No hay registros existentes, crear uno nuevo
      final newDebtLoan = DebtLoan(
        userId: transaction.userId,
        personName: personName,
        amount: transaction.amount,
        type: debtLoanType,
        description: transaction.description ?? 'Transacción automática',
        dateCreated: DateTime.now(),
        isPaid: false,
      );
      
      await DebtLoanService.createDebtLoan(newDebtLoan);
    }
  }

  // Reducir el monto de deuda/préstamo
  static Future<void> _reduceDebtLoanAmount(int userId, String personName, String type, double amount) async {
    final db = await DatabaseService.database;
    final records = await db.query(
      'debts_loans',
      where: 'user_id = ? AND person_name = ? AND type = ? AND is_paid = 0',
      whereArgs: [userId, personName, type],
      orderBy: 'date_created ASC',
    );

    double remainingAmount = amount;
    
    for (final record in records) {
      if (remainingAmount <= 0) break;
      
      final currentAmount = record['amount'] as double;
      
      if (remainingAmount >= currentAmount) {
        // Marcar este registro como pagado
        await db.update(
          'debts_loans',
          {'is_paid': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
        remainingAmount -= currentAmount;
      } else {
        // Reducir el monto de este registro
        await db.update(
          'debts_loans',
          {'amount': currentAmount - remainingAmount},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
        remainingAmount = 0;
      }
    }
  }

  // Aumentar el monto de deuda/préstamo
  static Future<void> _increaseDebtLoanAmount(int userId, String personName, String type, double amount) async {
    final newDebtLoan = DebtLoan(
      userId: userId,
      personName: personName,
      amount: amount,
      type: type,
      description: 'Transacción automática',
      dateCreated: DateTime.now(),
      isPaid: false,
    );
    
    await DebtLoanService.createDebtLoan(newDebtLoan);
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
