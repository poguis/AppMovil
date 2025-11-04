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
    
    // Validación de saldo suficiente para egresos
    if (transaction.type == 'expense') {
      final current = await MoneyService.getCurrentMoney(transaction.userId);
      if (transaction.amount > current) {
        throw Exception('Fondos insuficientes: saldo actual \$${current.toStringAsFixed(2)}');
      }
    }

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
      debtLoanType = 'loan'; // Me pagaron dinero que me debían (reducir lo que me deben)
    } else if (transaction.type == 'income' && category.name == 'Préstamos') {
      debtLoanType = 'debt'; // Pedí préstamo (aumentar lo que debo)
    } else if (transaction.type == 'expense' && category.name == 'Préstamo') {
      debtLoanType = 'debt'; // Pago mi deuda (reducir lo que debo)
    } else if (transaction.type == 'expense' && category.name == 'Me deben') {
      debtLoanType = 'loan'; // Presto dinero (aumentar lo que me deben)
    } else {
      return; // No es una categoría especial
    }

    // Buscar registros existentes de esta persona
    final existingRecords = await DebtLoanService.getAllDebtsLoans(transaction.userId);
    final personRecords = existingRecords.where((record) => 
      record.personName == personName && record.type == debtLoanType && !record.isPaid
    ).toList();

    if (personRecords.isNotEmpty) {
      // Hay registros existentes, consolidar en un solo registro
      final totalExisting = personRecords.fold(0.0, (sum, record) => sum + record.amount);
      
      if (transaction.type == 'income') {
        if (category.name == 'Me deben') {
          // Para "Me deben": me pagaron dinero que me debían, reducir la deuda
          await _reduceDebtLoanAmount(transaction.userId, personName, debtLoanType, transaction.amount);
        } else if (category.name == 'Préstamos') {
          // Para "Préstamos": pedí préstamo, consolidar en un solo registro
          await _consolidateDebtLoan(transaction.userId, personName, debtLoanType, transaction.amount, totalExisting, transaction.description);
        }
      } else {
        // Para expense (QUITAR)
        if (category.name == 'Préstamo') {
          // Para "Préstamo": pago mi deuda, reducir el monto
          await _reduceDebtLoanAmount(transaction.userId, personName, debtLoanType, transaction.amount);
        } else if (category.name == 'Me deben') {
          // Para "Me deben": presto dinero, consolidar en un solo registro (aumentar lo que me deben)
          await _consolidateDebtLoan(transaction.userId, personName, debtLoanType, transaction.amount, totalExisting, transaction.description);
        }
      }
    } else {
      // No hay registros existentes
      if ((transaction.type == 'income' && category.name == 'Me deben') ||
          (transaction.type == 'expense' && category.name == 'Préstamo')) {
        // Para "Me deben" (income) o "Préstamo" (expense), si no hay registros existentes, no hacer nada
        // (no se puede recibir pago de alguien que no te debe nada, ni pagar a alguien que no le debes nada)
        return;
      } else {
        // Para "Préstamos" (income) y "Me deben" (expense), crear uno nuevo
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
        // Eliminar este registro completamente ya que está pagado
        await db.delete(
          'debts_loans',
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

  // Consolidar deudas/préstamos en un solo registro
  static Future<void> _consolidateDebtLoan(int userId, String personName, String type, double newAmount, double existingAmount, String? description) async {
    final db = await DatabaseService.database;
    
    // Eliminar todos los registros existentes de esta persona
    await db.delete(
      'debts_loans',
      where: 'user_id = ? AND person_name = ? AND type = ? AND is_paid = 0',
      whereArgs: [userId, personName, type],
    );
    
    // Crear un nuevo registro con el monto total
    final totalAmount = existingAmount + newAmount;
    final consolidatedDebtLoan = DebtLoan(
      userId: userId,
      personName: personName,
      amount: totalAmount,
      type: type,
      description: description ?? 'Transacción consolidada',
      dateCreated: DateTime.now(),
      isPaid: false,
    );
    
    await DebtLoanService.createDebtLoan(consolidatedDebtLoan);
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
