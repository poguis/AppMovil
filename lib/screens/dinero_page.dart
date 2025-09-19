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
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _filteredTransactions = [];

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
      _filteredTransactions = transactions;
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
          await TransactionService.createTransaction(
            transaction,
            personName: result['person'] as String?,
          );
          
          // Recargar el dinero actual y las transacciones
                final newMoney = await MoneyService.getCurrentMoney(currentUser.id!);
                final newTransactions = await TransactionService.getTransactionsWithCategory(currentUser.id!, limit: 10);
                setState(() {
                  _currentMoney = newMoney;
                  _transactions = newTransactions;
                });
                _applyDateFilter(); // Aplicar filtro después de agregar nueva transacción

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

  void _applyDateFilter() {
    if (_startDate == null && _endDate == null) {
      _filteredTransactions = _transactions;
    } else {
      _filteredTransactions = _transactions.where((transaction) {
        final transactionDate = DateTime.parse(transaction['date'] as String);
        
        if (_startDate != null && transactionDate.isBefore(_startDate!)) {
          return false;
        }
        
        if (_endDate != null && transactionDate.isAfter(_endDate!.add(const Duration(days: 1)))) {
          return false;
        }
        
        return true;
      }).toList();
    }
    setState(() {});
  }

  Future<void> _selectDateRange() async {
    // Obtener la fecha del primer registro
    DateTime firstDate = DateTime(2020);
    if (_transactions.isNotEmpty) {
      final firstTransaction = _transactions.reduce((a, b) {
        final dateA = DateTime.parse(a['date'] as String);
        final dateB = DateTime.parse(b['date'] as String);
        return dateA.isBefore(dateB) ? a : b;
      });
      firstDate = DateTime.parse(firstTransaction['date'] as String);
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyDateFilter();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredTransactions = _transactions;
    });
  }

  void _setLast7DaysFilter() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    setState(() {
      _startDate = sevenDaysAgo;
      _endDate = now;
    });
    _applyDateFilter();
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Historial',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_startDate != null || _endDate != null) ...[
                                  IconButton(
                                    onPressed: _clearDateFilter,
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: 'Limpiar filtro',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                      minimumSize: const Size(36, 36),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                IconButton(
                                  onPressed: _setLast7DaysFilter,
                                  icon: const Icon(Icons.calendar_today, size: 18),
                                  tooltip: 'Últimos 7 días',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: _selectDateRange,
                                  icon: const Icon(Icons.date_range, size: 18),
                                  tooltip: 'Filtrar por fecha',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_startDate != null || _endDate != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _startDate != null && _endDate != null
                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                  : _startDate != null
                                      ? 'Desde: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                      : 'Hasta: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: _filteredTransactions.isEmpty
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
                                  itemCount: _filteredTransactions.length,
                                  itemBuilder: (context, index) {
                                    final transaction = _filteredTransactions[index];
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

