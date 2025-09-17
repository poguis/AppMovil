import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/debt_loan_service.dart';
import '../models/debt_loan.dart';

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
            trailing: Column(
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
            trailing: Column(
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
          ),
        );
      },
    );
  }
}
