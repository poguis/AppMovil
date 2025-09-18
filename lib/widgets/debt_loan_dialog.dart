import 'package:flutter/material.dart';

class DebtLoanDialog extends StatefulWidget {
  final String type; // 'debt' o 'loan'

  const DebtLoanDialog({
    super.key,
    required this.type,
  });

  @override
  State<DebtLoanDialog> createState() => _DebtLoanDialogState();
}

class _DebtLoanDialogState extends State<DebtLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _personNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

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
    final title = isDebt ? 'Agregar Deuda' : 'Agregar Préstamo';
    final personLabel = isDebt ? 'Persona a la que debo' : 'Persona que me debe';

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

              // Campo de descripción
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
      });
    }
  }
}
