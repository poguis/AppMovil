import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../services/person_service.dart';
import '../services/auth_service.dart';

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
  bool _showCreateCategory = false;
  final _newCategoryController = TextEditingController();
  
  // Para selector de personas
  List<String> _persons = [];
  String? _selectedPerson;
  bool _isLoadingPersons = false;
  double _pendingAmount = 0.0;

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
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      // Solo cargar categorías normales, no las de deuda/préstamo
      final allCategories = await CategoryService.getCategoriesByType(widget.type);
      final normalCategories = allCategories.where((cat) => 
        !cat.name.toLowerCase().contains('deuda') && 
        !cat.name.toLowerCase().contains('debo') &&
        !cat.name.toLowerCase().contains('préstamo') &&
        !cat.name.toLowerCase().contains('me deben')
      ).toList();
      
      // Agregar la categoría especial de deuda/préstamo
      final specialCategory = Category(
        id: -1, // ID especial para identificar
        name: widget.type == 'income' ? 'Me deben' : 'Debo',
        type: widget.type,
        color: widget.type == 'income' ? '#4CAF50' : '#F44336',
        icon: widget.type == 'income' ? 'account_balance_wallet' : 'money_off',
        isDefault: false,
        userId: null,
        createdAt: DateTime.now(),
      );
      
      setState(() {
        _categories = [...normalCategories, specialCategory];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewCategory() async {
    if (_newCategoryController.text.trim().isEmpty) return;

    try {
      final categoryId = await CategoryService.createCategory(Category(
        name: _newCategoryController.text.trim(),
        type: widget.type,
        color: widget.type == 'income' ? '#4CAF50' : '#F44336',
        icon: 'category',
        isDefault: false,
        userId: null,
        createdAt: DateTime.now(),
      ));

      // Crear la categoría con el ID asignado
      final newCategory = Category(
        id: categoryId,
        name: _newCategoryController.text.trim(),
        type: widget.type,
        color: widget.type == 'income' ? '#4CAF50' : '#F44336',
        icon: 'category',
        isDefault: false,
        userId: null,
        createdAt: DateTime.now(),
      );

      setState(() {
        _categories.add(newCategory);
        _selectedCategory = newCategory;
        _showCreateCategory = false;
        _newCategoryController.clear();
      });
    } catch (e) {
      // Error al crear categoría
    }
  }

  Future<void> _loadPersonsForCategory(Category category) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingPersons = true;
    });

    try {
      List<String> persons = [];
      
      // Determinar el tipo según la categoría especial
      if (category.id == -1) {
        if (widget.type == 'income') {
          // "Me deben" - cargar personas de préstamos
          persons = await PersonService.getPersonsByType(currentUser.id!, 'loan');
        } else {
          // "Debo" - cargar personas de deudas
          persons = await PersonService.getPersonsByType(currentUser.id!, 'debt');
        }
      }

      setState(() {
        _persons = persons;
        _selectedPerson = null;
        _isLoadingPersons = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPersons = false;
      });
    }
  }

  Future<void> _loadPendingAmount(String personName) async {
    final currentUser = AuthService.currentUser;
    if (currentUser == null) return;

    try {
      String type = 'loan'; // Por defecto
      if (widget.type == 'expense') {
        type = 'debt';
      }

      final amount = await PersonService.getTotalPendingByPerson(currentUser.id!, personName, type);
      setState(() {
        _pendingAmount = amount;
      });
    } catch (e) {
      setState(() {
        _pendingAmount = 0.0;
      });
    }
  }

  bool _shouldShowPersonSelector() {
    if (_selectedCategory == null) return false;
    
    // Solo mostrar selector para la categoría especial de deuda/préstamo
    return _selectedCategory!.id == -1;
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categoría:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showCreateCategory = !_showCreateCategory;
                        });
                      },
                      icon: Icon(_showCreateCategory ? Icons.close : Icons.add),
                      label: Text(_showCreateCategory ? 'Cancelar' : 'Nueva'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Campo para crear nueva categoría
                if (_showCreateCategory) ...[
                  TextFormField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la nueva categoría',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: _createNewCategory,
                        icon: const Icon(Icons.check),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Dropdown de categorías
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
                        if (newValue != null) {
                          _loadPersonsForCategory(newValue);
                        }
                      },
                    ),
                  ),
                ),
                
                // Selector de personas (solo para categorías de deuda/préstamo)
                if (_shouldShowPersonSelector()) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Persona:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingPersons)
                    const CircularProgressIndicator()
                  else if (_persons.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No hay personas registradas para esta categoría. Ve a "Deudas y Préstamos" para agregar personas.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    )
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
                          value: _selectedPerson,
                          hint: const Text('Selecciona una persona'),
                          isExpanded: true,
                          items: _persons.map((person) {
                            return DropdownMenuItem<String>(
                              value: person,
                              child: Text(person),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedPerson = newValue;
                            });
                            if (newValue != null) {
                              _loadPendingAmount(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                
                // Información de la persona seleccionada
                if (_selectedPerson != null && _pendingAmount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.type == 'income' 
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      border: Border.all(
                        color: widget.type == 'income' ? Colors.green : Colors.red,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información de $_selectedPerson:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.type == 'income' 
                              ? 'Te debe: \$${_pendingAmount.toStringAsFixed(2)}'
                              : 'Le debes: \$${_pendingAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.type == 'income' ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cantidad sugerida: \$${_pendingAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ],
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
          onPressed: _canSubmit() ? _handleSubmit : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  bool _canSubmit() {
    if (_selectedCategory == null) return false;
    
    // Si es una categoría de deuda/préstamo, también debe seleccionar una persona
    if (_shouldShowPersonSelector() && _selectedPerson == null) {
      return false;
    }
    
    return true;
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate() && _canSubmit()) {
      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();

      final result = {
        'amount': amount,
        'description': description,
        'category': _selectedCategory,
      };

      // Si hay persona seleccionada, agregarla al resultado
      if (_selectedPerson != null) {
        result['person'] = _selectedPerson;
      }

      Navigator.of(context).pop(result);
    }
  }
}
