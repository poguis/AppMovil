import 'package:flutter/material.dart';

class MoneyInputDialog extends StatefulWidget {
  final String? title;
  final String? prefixText;
  final double? initialValue;

  const MoneyInputDialog({
    super.key,
    this.title,
    this.prefixText,
    this.initialValue,
  });

  @override
  State<MoneyInputDialog> createState() => _MoneyInputDialogState();
}

class _MoneyInputDialogState extends State<MoneyInputDialog> {
  final TextEditingController _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Ingresar Dinero Inicial'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title == null 
                ? '¿Cuánto dinero tienes actualmente?'
                : 'Ingresa la cantidad:',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                prefixText: widget.prefixText ?? '\$ ',
                border: const OutlineInputBorder(),
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
                if (amount < 0) {
                  return 'La cantidad no puede ser negativa';
                }
                return null;
              },
            ),
          ],
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = double.parse(_controller.text);
              Navigator.of(context).pop(amount);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
