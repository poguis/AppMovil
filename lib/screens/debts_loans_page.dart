import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/auth_service.dart';
import '../services/debt_loan_service.dart';
import '../services/database_service.dart';
import '../models/debt_loan.dart';
import '../widgets/debt_loan_dialog.dart';

class DebtsLoansPage extends StatefulWidget {
  const DebtsLoansPage({super.key});

  @override
  State<DebtsLoansPage> createState() => _DebtsLoansPageState();
}

class _DebtsLoansPageState extends State<DebtsLoansPage> {
  List<DebtLoan> _debts = [];
  List<DebtLoan> _loans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar datos cuando se regrese de otra pantalla
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final debts = await DebtLoanService.getUserDebts(currentUser.id!);
      final loans = await DebtLoanService.getUserLoans(currentUser.id!);
      
      setState(() {
        _debts = debts;
        _loans = loans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatMoney(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getTypeColor(String type) {
    return type == 'debt' ? Colors.red : Colors.green;
  }

  String _getTypeText(String type) {
    return type == 'debt' ? 'Debo' : 'Me deben';
  }

  Future<void> _showAddDebtLoanDialog(String type) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DebtLoanDialog(type: type),
    );

    if (result != null) {
      final currentUser = AuthService.currentUser;
      if (currentUser != null) {
        try {
          final isExistingPerson = result['isExistingPerson'] as bool? ?? false;
          final existingAmount = result['existingAmount'] as double? ?? 0.0;
          
          if (isExistingPerson && existingAmount > 0) {
            // Consolidar con la deuda existente
            await _consolidateDebtLoan(
              currentUser.id!,
              result['personName'] as String,
              type,
              result['amount'] as double,
              existingAmount,
              result['description'] as String?,
            );
          } else {
            // Crear nueva deuda/préstamo
            final debtLoan = DebtLoan(
              userId: currentUser.id!,
              personName: result['personName'] as String,
              amount: result['amount'] as double,
              type: type,
              description: result['description'] as String?,
              dateCreated: DateTime.now(),
              isPaid: false,
            );

            await DebtLoanService.createDebtLoan(debtLoan);
          }
          
          await _loadData(); // Recargar los datos

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  type == 'debt' 
                    ? 'Deuda agregada exitosamente' 
                    : 'Préstamo agregado exitosamente'
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al agregar el registro'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _showEditDebtLoanDialog(DebtLoan debtLoan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DebtLoanDialog(
        type: debtLoan.type,
        initialData: {
          'personName': debtLoan.personName,
          'amount': debtLoan.amount,
          'description': debtLoan.description,
        },
      ),
    );

    if (result != null) {
      try {
        final updatedDebtLoan = DebtLoan(
          id: debtLoan.id,
          userId: debtLoan.userId,
          personName: result['personName'] as String,
          amount: result['amount'] as double,
          type: debtLoan.type,
          description: result['description'] as String?,
          dateCreated: debtLoan.dateCreated,
          isPaid: debtLoan.isPaid,
        );

        await DebtLoanService.updateDebtLoan(updatedDebtLoan);
        await _loadData(); // Recargar los datos

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al actualizar el registro'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteDebtLoan(DebtLoan debtLoan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar este registro de ${debtLoan.personName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DebtLoanService.deleteDebtLoan(debtLoan.id!);
        await _loadData(); // Recargar los datos

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar el registro'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Consolidar deudas/préstamos existentes
  Future<void> _consolidateDebtLoan(int userId, String personName, String type, double newAmount, double existingAmount, String? description) async {
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
      description: description ?? 'Deuda consolidada',
      dateCreated: DateTime.now(),
      isPaid: false,
    );
    
    await DebtLoanService.createDebtLoan(consolidatedDebtLoan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Deudas y Préstamos'),
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
                // Resumen de totales
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.1),
                        Colors.green.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Total Debo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatMoney(_debts.fold(0.0, (sum, debt) => sum + debt.amount)),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      Column(
                        children: [
                          const Text(
                            'Total Me Deben',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatMoney(_loans.fold(0.0, (sum, loan) => sum + loan.amount)),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista de deudas y préstamos
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TabBar(
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: 'Debo'),
                              Tab(text: 'Me Deben'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab de Deudas (Debo)
                              _buildDebtsList(),
                              // Tab de Préstamos (Me Deben)
                              _buildLoansList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Agregar Nuevo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddDebtLoanDialog('debt');
                          },
                          icon: const Icon(Icons.money_off),
                          label: const Text('Deuda'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddDebtLoanDialog('loan');
                          },
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Préstamo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  Widget _buildDebtsList() {
    if (_debts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.money_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No tienes deudas registradas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _debts.length,
      itemBuilder: (context, index) {
        final debt = _debts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(Icons.money_off, color: Colors.red),
            ),
            title: Text(
              debt.personName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (debt.description != null && debt.description!.isNotEmpty)
                  Text(debt.description!),
                Text(
                  'Fecha: ${_formatDate(debt.dateCreated)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(debt.amount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    if (debt.isPaid)
                      const Text(
                        'PAGADO',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _showEditDebtLoanDialog(debt);
                    } else if (value == 'delete') {
                      await _deleteDebtLoan(debt);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoansList() {
    if (_loans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No tienes préstamos registrados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _loans.length,
      itemBuilder: (context, index) {
        final loan = _loans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: const Icon(Icons.account_balance_wallet, color: Colors.green),
            ),
            title: Text(
              loan.personName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loan.description != null && loan.description!.isNotEmpty)
                  Text(loan.description!),
                Text(
                  'Fecha: ${_formatDate(loan.dateCreated)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(loan.amount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (loan.isPaid)
                      const Text(
                        'PAGADO',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _showEditDebtLoanDialog(loan);
                    } else if (value == 'delete') {
                      await _deleteDebtLoan(loan);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
