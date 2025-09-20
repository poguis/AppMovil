import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/person_service.dart';

class DebtLoanDialog extends StatefulWidget {
  final String type; // 'debt' o 'loan'
  final Map<String, dynamic>? initialData; // Para edición

  const DebtLoanDialog({
    super.key,
    required this.type,
    this.initialData,
  });

  @override
  State<DebtLoanDialog> createState() => _DebtLoanDialogState();
}

class _DebtLoanDialogState extends State<DebtLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Para selector de personas existentes
  List<String> _existingPersons = [];
  String? _selectedExistingPerson;
  bool _isLoadingPersons = false;
  bool _showPersonSelector = false;
  double _existingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Pre-llenar campos si estamos editando
    if (widget.initialData != null) {
      _personNameController.text = widget.initialData!['personName'] ?? '';
      _amountController.text = widget.initialData!['amount']?.toString() ?? '';
      _descriptionController.text = widget.initialData!['description'] ?? '';
    }
    
    // Cargar personas existentes si no estamos editando
    if (widget.initialData == null) {
      _loadExistingPersons();
    }
  }

  Future<void> _loadExistingPersons() async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingPersons = true;
    });

    try {
      // Cargar personas que ya tienen deudas/préstamos del mismo tipo
      final persons = await PersonService.getPersonsByType(currentUser.id!, widget.type);
      
      setState(() {
        _existingPersons = persons;
        _isLoadingPersons = false;
        _showPersonSelector = persons.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _isLoadingPersons = false;
        _showPersonSelector = false;
      });
    }
  }

  Future<void> _loadExistingAmount(String personName) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      final amount = await PersonService.getTotalPendingByPerson(currentUser.id!, personName, widget.type);
      setState(() {
        _existingAmount = amount;
      });
    } catch (e) {
      setState(() {
        _existingAmount = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _personNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDebt = widget.type == 'debt';
    final isEditing = widget.initialData != null;
    final title = isEditing 
        ? (isDebt ? 'Editar Deuda' : 'Editar Préstamo')
        : (isDebt ? 'Agregar Deuda' : 'Agregar Préstamo');
    final personLabel = isDebt ? 'Persona a la que debo' : 'Persona que me debe';

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selector de personas existentes (solo si no estamos editando y hay personas existentes)
              if (_showPersonSelector && !isEditing) ...[
                const Text(
                  'Personas existentes:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingPersons)
                  const CircularProgressIndicator()
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedExistingPerson,
                        hint: const Text('Selecciona una persona existente'),
                        isExpanded: true,
                        items: _existingPersons.map((person) {
                          return DropdownMenuItem<String>(
                            value: person,
                            child: Text(person),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedExistingPerson = newValue;
                            if (newValue != null) {
                              _personNameController.text = newValue;
                              _loadExistingAmount(newValue);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'O agregar nueva persona:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Campo de nombre de persona
              TextFormField(
                controller: _personNameController,
                decoration: InputDecoration(
                  labelText: personLabel,
                  border: const OutlineInputBorder(),
                  hintText: 'Ej: Juan Pérez',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre de la persona';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de cantidad
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una cantidad';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null) {
                    return 'Por favor ingresa un número válido';
                  }
                  if (amount <= 0) {
                    return 'La cantidad debe ser mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Información de la persona seleccionada
              if (_selectedExistingPerson != null && _existingAmount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.type == 'debt' 
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    border: Border.all(
                      color: widget.type == 'debt' ? Colors.red : Colors.green,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deuda actual con $_selectedExistingPerson:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.type == 'debt' ? 'Le debes' : 'Te debe'}: \$${_existingAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.type == 'debt' ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se sumará al monto existente',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Campo de descripción
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Préstamo para emergencia, Deuda de comida...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final personName = _personNameController.text.trim();
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();

      Navigator.of(context).pop({
        'personName': personName,
        'amount': amount,
        'description': description,
        'isExistingPerson': _selectedExistingPerson != null,
        'existingAmount': _existingAmount,
      });
    }
  }
}

