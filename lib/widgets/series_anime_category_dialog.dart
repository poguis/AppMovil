import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series_anime_category.dart';
import '../models/series.dart';
import '../services/series_service.dart';

class SeriesAnimeCategoryDialog extends StatefulWidget {
  final SeriesAnimeCategory? category;
  final String? initialType;

  const SeriesAnimeCategoryDialog({
    super.key,
    this.category,
    this.initialType,
  });

  @override
  State<SeriesAnimeCategoryDialog> createState() => _SeriesAnimeCategoryDialogState();
}

class _SeriesAnimeCategoryDialogState extends State<SeriesAnimeCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _numberOfSeriesController = TextEditingController();
  
  String _selectedType = 'video';
  DateTime _startDate = DateTime.now();
  List<int> _selectedDays = [];
  bool _isLoading = false;

  // Días de la semana
  final List<Map<String, dynamic>> _weekDays = [
    {'number': 1, 'name': 'Lunes', 'short': 'L'},
    {'number': 2, 'name': 'Martes', 'short': 'M'},
    {'number': 3, 'name': 'Miércoles', 'short': 'X'},
    {'number': 4, 'name': 'Jueves', 'short': 'J'},
    {'number': 5, 'name': 'Viernes', 'short': 'V'},
    {'number': 6, 'name': 'Sábado', 'short': 'S'},
    {'number': 7, 'name': 'Domingo', 'short': 'D'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _selectedType = widget.category!.type;
      _startDate = widget.category!.startDate;
      _selectedDays = List.from(widget.category!.selectedDays);
      _frequencyController.text = widget.category!.frequency.toString();
      _numberOfSeriesController.text = widget.category!.numberOfSeries.toString();
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
      _frequencyController.text = '1';
      _numberOfSeriesController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _frequencyController.dispose();
    _numberOfSeriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.category == null ? 'Agregar Categoría' : 'Editar Categoría',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo de nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la categoría',
                  hintText: 'Ej: Acción, Romance, Comedia...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (value.trim().length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Selector de tipo
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'video',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Video'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'lectura',
                    child: Row(
                      children: [
                        Icon(Icons.menu_book, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Lectura'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecciona un tipo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Selector de fecha de inicio
              InkWell(
                onTap: _selectStartDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de inicio',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_startDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selector de días de la semana
              const Text(
                'Días de la semana:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day['number']);
                  return FilterChip(
                    label: Text(day['short']),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day['number']);
                        } else {
                          _selectedDays.remove(day['number']);
                        }
                      });
                    },
                    tooltip: day['name'],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Campo de frecuencia
              TextFormField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Frecuencia (capítulos por día)',
                  hintText: 'Ej: 2',
                  border: OutlineInputBorder(),
                  helperText: 'Número de capítulos que verás por día',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La frecuencia es requerida';
                  }
                  final intValue = int.tryParse(value);
                  if (intValue == null || intValue < 1) {
                    return 'La frecuencia debe ser un número mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de número de series
              TextFormField(
                controller: _numberOfSeriesController,
                decoration: const InputDecoration(
                  labelText: 'Número de series',
                  hintText: 'Ej: 2',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El número de series es requerido';
                  }
                  final intValue = int.tryParse(value);
                  if (intValue == null || intValue < 1) {
                    return 'El número de series debe ser mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de descripción (opcional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Descripción de la categoría...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCategory,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.category == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que se hayan seleccionado días
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un día de la semana'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validación del número de series
    if (widget.category != null) {
      final newNumberOfSeries = int.parse(_numberOfSeriesController.text);
      final currentNumberOfSeries = widget.category!.numberOfSeries;
      
      if (newNumberOfSeries < currentNumberOfSeries) {
        // Solo se puede reducir si el número de series en estado "Mirando" es menor al nuevo límite
        
        try {
          final allSeries = await SeriesService.getSeriesByCategory(widget.category!.id!);
          final mirandoCount = allSeries.where((s) => s.status == SeriesStatus.mirando).length;
          
          if (mirandoCount > newNumberOfSeries) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No puedes reducir el número de series a $newNumberOfSeries porque ya tienes $mirandoCount series en estado "Mirando".\nSolo puedes agregar más series.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
        } catch (e) {
          // En caso de error, mostrar mensaje básico
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No puedes reducir el número de series si ya tienes series registradas.\nSolo puedes agregar más series.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final category = SeriesAnimeCategory(
        id: widget.category?.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startDate: _startDate,
        selectedDays: _selectedDays,
        frequency: int.parse(_frequencyController.text),
        numberOfSeries: int.parse(_numberOfSeriesController.text),
        createdAt: widget.category?.createdAt ?? DateTime.now(),
      );

      Navigator.of(context).pop(category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

