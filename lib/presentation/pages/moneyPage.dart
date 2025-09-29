import 'package:flutter/material.dart';
import '../../data/repositories/moneyRepository.dart';
import 'package:intl/intl.dart';

class MoneyPage extends StatefulWidget {
  final String userId;
  const MoneyPage({super.key, required this.userId});

  @override
  _MoneyPageState createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  final MoneyRepository _moneyRepository = MoneyRepository();

  double currentMoney = 0;
  bool isLoading = true;
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> persons = [];
  List<Map<String, dynamic>> debtsLoans = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final money = await _moneyRepository.getUserMoney(widget.userId);
    final cats = await _moneyRepository.getCategories(widget.userId);
    final pers = await _moneyRepository.getPersons(widget.userId);
    final dl = await _moneyRepository.getDebtsLoans(widget.userId);
    final trans = await _moneyRepository.getTransactions(widget.userId);

    setState(() {
      currentMoney = money ?? 0;
      categories = cats.isEmpty
          ? [
              {'id': -1, 'name': 'Me deben'},
              {'id': -2, 'name': 'Préstamos'}
            ]
          : cats;
      persons = pers;
      debtsLoans = dl;
      transactions = trans;
      isLoading = false;
    });

    if (money == null) {
      _showInitialMoneyDialog();
    }
  }

  Future<void> _showInitialMoneyDialog() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa tu dinero inicial', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount != null) {
                  await _moneyRepository.setUserMoney(widget.userId, amount);
                  setState(() {
                    currentMoney = amount;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            )
          ],
        ),
      ),
    );
  }

  /// -----------------------
  /// AGREGAR / QUITAR DINERO
  /// -----------------------
  void _showAddRemoveMoneyDialog({required bool isAdd}) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAdd ? 'Agregar Dinero' : 'Quitar Dinero',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: categories.map((c) => DropdownMenuItem<String>(
                  value: c['id'].toString(),
                  child: Text(c['name']),
                )).toList(),
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                onChanged: (value) {
                  setModalState(() => selectedCategory = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || selectedCategory == null) return;

                  int catId = int.parse(selectedCategory!);

                  await _moneyRepository.addTransaction(
                    userId: widget.userId,
                    categoryId: catId,
                    type: isAdd ? 'add' : 'remove',
                    amount: amount,
                    description: descriptionController.text,
                  );

                  final newMoney = isAdd ? currentMoney + amount : currentMoney - amount;
                  await _moneyRepository.setUserMoney(widget.userId, newMoney);

                  setState(() {
                    currentMoney = newMoney;
                  });

                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// -----------------------
  /// DEUDAS Y PRÉSTAMOS
  /// -----------------------
  void _showDebtsLoansDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Deudas y Préstamos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Total Debo', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        debtsLoans.where((e) => e['type'] == 'debt').fold(0.0, (sum, e) => sum + (e['amount'] as double)).toStringAsFixed(2),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Total Me Deben', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        debtsLoans.where((e) => e['type'] == 'loan').fold(0.0, (sum, e) => sum + (e['amount'] as double)).toStringAsFixed(2),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddDebtLoanDialog(setModalState),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: debtsLoans.length,
                  itemBuilder: (context, index) {
                    final item = debtsLoans[index];
                    final personName = persons.firstWhere((p) => p['id'] == item['person_id'], orElse: () => {'name': 'Desconocido'})['name'];
                    return ListTile(
                      title: Text(personName),
                      subtitle: Text('${item['type']} \$${item['amount'].toStringAsFixed(2)}'),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDebtLoanDialog(void Function(void Function()) setModalState) {
    String? selectedPerson;
    String type = 'debt';
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Agregar Deuda / Préstamo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedPerson,
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Nueva Persona')),
                  ...persons.map((p) => DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text(p['name']),
                  )),
                ],
                decoration: const InputDecoration(labelText: 'Persona', border: OutlineInputBorder()),
                onChanged: (v) => setStateSheet(() => selectedPerson = v),
              ),
              const SizedBox(height: 10),
              if (selectedPerson == '' || selectedPerson == null)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'debt', child: Text('Deuda')),
                  DropdownMenuItem(value: 'loan', child: Text('Préstamo')),
                ],
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                onChanged: (v) => setStateSheet(() => type = v!),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  int personId;
                  if (selectedPerson == null || selectedPerson == '') {
                    personId = await _moneyRepository.addPerson(widget.userId, nameController.text);
                  } else {
                    personId = int.parse(selectedPerson!);
                  }

                  await _moneyRepository.addDebtLoan(
                    userId: widget.userId,
                    personId: personId,
                    type: type,
                    amount: double.parse(amountController.text),
                    description: descController.text,
                  );

                  final dl = await _moneyRepository.getDebtsLoans(widget.userId);

                  setState(() {
                    debtsLoans = dl;
                  });

                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              )
            ],
          ),
        ),
      ),
    );
  }

  /// -----------------------
  /// HISTORIAL
  /// -----------------------
  Widget _buildHistory() {
    if (transactions.isEmpty) return const Center(child: Text('No hay transacciones'));
    // Agrupar por día y categoría
    Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (var t in transactions) {
      String day = DateFormat('yyyy-MM-dd').format(DateTime.parse(t['created_at']));
      String cat = categories.firstWhere((c) => c['id'] == t['category_id'], orElse: () => {'name': 'Sin categoría'})['name'];
      grouped[day] ??= {};
      grouped[day]![cat] ??= [];
      grouped[day]![cat]!.add(t);
    }

    return Expanded(
      child: ListView(
        children: grouped.entries.map((dayEntry) {
          String day = dayEntry.key;
          Map<String, List<Map<String, dynamic>>> cats = dayEntry.value;
          return ExpansionTile(
            title: Text(day),
            children: cats.entries.map((catEntry) {
              String catName = catEntry.key;
              double total = catEntry.value.fold(0.0, (sum, t) => sum + t['amount']);
              return ExpansionTile(
                title: Text('$catName: \$${total.toStringAsFixed(2)}'),
                children: catEntry.value.map((t) {
                  String time = DateFormat('HH:mm').format(DateTime.parse(t['created_at']));
                  return ListTile(
                    title: Text('${t['type']} \$${t['amount'].toStringAsFixed(2)}'),
                    subtitle: Text('${t['description'] ?? ''} - $time'),
                  );
                }).toList(),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dinero Diario')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    color: Colors.green[100],
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet, size: 40),
                      title: const Text('Dinero Actual', style: TextStyle(fontSize: 18)),
                      subtitle: Text('\$${currentMoney.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _showInitialMoneyDialog,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddRemoveMoneyDialog(isAdd: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddRemoveMoneyDialog(isAdd: false),
                        icon: const Icon(Icons.remove),
                        label: const Text('Quitar'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showDebtsLoansDialog,
                        icon: const Icon(Icons.money_off),
                        label: const Text('Deudas/Préstamos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Historial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildHistory(),
                ],
              ),
            ),
    );
  }
}
