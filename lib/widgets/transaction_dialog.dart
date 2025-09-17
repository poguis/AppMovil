import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class TransactionDialog extends StatefulWidget {
  final String type; // 'income' o 'expense'
  final double? initialAmount;

  const TransactionDialog({
    super.key,
    required this.type,
    this.initialAmount,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getCategoriesByType(widget.type);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.type == 'income' ? 'Agregar Dinero' : 'Quitar Dinero'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo de cantidad
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  prefixText: widget.type == 'income' ? '+ \$ ' : '- \$ ',
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
                  hintText: 'Ej: Pago de servicios, Venta de producto...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Selección de categoría
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                const Text(
                  'Categoría:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Category>(
                      value: _selectedCategory,
                      hint: const Text('Selecciona una categoría'),
                      isExpanded: true,
                      items: _categories.map((category) {
                        return DropdownMenuItem<Category>(
                          value: category,
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(int.parse(category.color.replaceFirst('#', '0xff'))),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (Category? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                    ),
                  ),
                ),
              ],
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
          onPressed: _selectedCategory == null ? null : _handleSubmit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();

      Navigator.of(context).pop({
        'amount': amount,
        'description': description,
        'category': _selectedCategory,
      });
    }
  }
}
