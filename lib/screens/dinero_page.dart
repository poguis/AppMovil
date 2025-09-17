import 'package:flutter/material.dart';
import '../services/money_service.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction.dart' as model;
import '../widgets/money_input_dialog.dart';
import '../widgets/transaction_dialog.dart';
import 'debts_loans_page.dart';

class DineroPage extends StatefulWidget {
  const DineroPage({super.key});

  @override
  State<DineroPage> createState() => _DineroPageState();
}

class _DineroPageState extends State<DineroPage> {
  double _currentMoney = 0.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadMoney();
  }

  Future<void> _loadMoney() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    final money = await MoneyService.getCurrentMoney(currentUser.id!);
    final hasMoney = await MoneyService.hasMoneyRegistered(currentUser.id!);
    final transactions = await TransactionService.getTransactionsWithCategory(currentUser.id!, limit: 10);
    
    setState(() {
      _currentMoney = money;
      _transactions = transactions;
      _isLoading = false;
    });

    // Si no hay dinero registrado o está en cero, mostrar el diálogo
    if (!hasMoney || money == 0.0) {
      _showMoneyInputDialog();
    }
  }

  Future<void> _showMoneyInputDialog() async {
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (context) => const MoneyInputDialog(),
    );

    if (result != null) {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await MoneyService.setCurrentMoney(currentUser.id!, result);
        setState(() {
          _currentMoney = result;
        });
      }
    }
  }

  Future<void> _showEditMoneyDialog() async {
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (context) => MoneyInputDialog(initialValue: _currentMoney),
    );

    if (result != null) {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        await MoneyService.setCurrentMoney(currentUser.id!, result);
        setState(() {
          _currentMoney = result;
        });
      }
    }
  }

  Future<void> _showTransactionDialog(String type) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TransactionDialog(type: type),
    );

    if (result != null) {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        try {
          // Crear la transacción
          final transaction = model.Transaction(
            userId: currentUser.id!,
            amount: result['amount'] as double,
            type: type,
            categoryId: (result['category'] as dynamic).id,
            description: result['description'] as String?,
            date: DateTime.now(),
          );

          // Guardar la transacción (esto también actualiza el dinero automáticamente)
          await TransactionService.createTransaction(transaction);
          
          // Recargar el dinero actual y las transacciones
          final newMoney = await MoneyService.getCurrentMoney(currentUser.id!);
          final newTransactions = await TransactionService.getTransactionsWithCategory(currentUser.id!, limit: 10);
          setState(() {
            _currentMoney = newMoney;
            _transactions = newTransactions;
          });

          // Mostrar mensaje de éxito
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  type == 'income' 
                    ? 'Dinero agregado exitosamente' 
                    : 'Dinero quitado exitosamente'
                ),
                backgroundColor: type == 'income' ? Colors.green : Colors.orange,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al procesar la transacción'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  String _formatMoney(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Dinero'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Regresar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mostrar dinero actual en la parte superior central
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dinero Actual',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          IconButton(
                            onPressed: _showEditMoneyDialog,
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Editar dinero',
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatMoney(_currentMoney),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botón de Deudas y Préstamos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DebtsLoansPage()),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Deudas y Préstamos'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botones de Aumentar/Disminuir
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showTransactionDialog('income'),
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showTransactionDialog('expense'),
                          icon: const Icon(Icons.remove),
                          label: const Text('Quitar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Historial de transacciones
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historial de Transacciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _transactions.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No hay transacciones registradas',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _transactions.length,
                                  itemBuilder: (context, index) {
                                    final transaction = _transactions[index];
                                    final isIncome = transaction['type'] == 'income';
                                    final amount = transaction['amount'] as double;
                                    final categoryName = transaction['category_name'] as String? ?? 'Sin categoría';
                                    final description = transaction['description'] as String?;
                                    final date = DateTime.parse(transaction['date'] as String);
                                    
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isIncome 
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : Colors.red.withValues(alpha: 0.1),
                                          child: Icon(
                                            isIncome ? Icons.add : Icons.remove,
                                            color: isIncome ? Colors.green : Colors.red,
                                          ),
                                        ),
                                        title: Text(
                                          categoryName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (description != null && description.isNotEmpty)
                                              Text(description),
                                            Text(
                                              '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        trailing: Text(
                                          '${isIncome ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

