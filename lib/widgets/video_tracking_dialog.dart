import 'package:flutter/material.dart';
import '../models/video_tracking.dart';
import '../models/series_anime_category.dart';

class VideoTrackingDialog extends StatefulWidget {
  final VideoTracking? tracking;
  final SeriesAnimeCategory? category;
  final List<SeriesAnimeCategory> categories;

  const VideoTrackingDialog({
    super.key,
    this.tracking,
    this.category,
    required this.categories,
  });

  @override
  State<VideoTrackingDialog> createState() => _VideoTrackingDialogState();
}

class _VideoTrackingDialogState extends State<VideoTrackingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  List<int> _selectedDays = [];
  Map<String, int> _frequency = {};
  SeriesAnimeCategory? _selectedCategory;
  bool _isLoading = false;

  // Opciones de frecuencia
  final List<Map<String, dynamic>> _frequencyOptions = [
    {'key': 'daily', 'label': 'Por día', 'icon': Icons.today},
    {'key': 'every_2_days', 'label': 'Cada 2 días', 'icon': Icons.calendar_today},
    {'key': 'every_3_days', 'label': 'Cada 3 días', 'icon': Icons.calendar_view_week},
    {'key': 'weekly', 'label': 'Por semana', 'icon': Icons.date_range},
  ];

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
    _initializeData();
  }

  void _initializeData() {
    if (widget.tracking != null) {
      _nameController.text = widget.tracking!.name;
      _descriptionController.text = widget.tracking!.description ?? '';
      _startDate = widget.tracking!.startDate;
      _selectedDays = List.from(widget.tracking!.selectedDays);
      _frequency = Map.from(widget.tracking!.frequency);
      _selectedCategory = widget.categories.firstWhere(
        (cat) => cat.id == widget.tracking!.categoryId,
        orElse: () => widget.categories.first,
      );
    } else {
      _selectedCategory = widget.category ?? widget.categories.first;
      _frequency['daily'] = 1; // Valor por defecto
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.tracking == null ? 'Agregar Registro de Video' : 'Editar Registro de Video',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la serie/anime',
                  hintText: 'Ej: Attack on Titan, Breaking Bad...',
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

              // Selector de categoría
              DropdownButtonFormField<SeriesAnimeCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          category.type == 'video' 
                              ? Icons.play_circle_outline 
                              : Icons.menu_book,
                          color: category.type == 'video' ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona una categoría';
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
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
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

              // Configuración de frecuencia
              const Text(
                'Frecuencia de capítulos:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ..._frequencyOptions.map((option) {
                final currentValue = _frequency[option['key']] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(option['icon'], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(option['label']),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: currentValue.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cant.',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (value) {
                            final intValue = int.tryParse(value) ?? 0;
                            if (intValue > 0) {
                              _frequency[option['key']] = intValue;
                            } else {
                              _frequency.remove(option['key']);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Campo de descripción (opcional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Notas adicionales...',
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
          onPressed: _isLoading ? null : _saveTracking,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.tracking == null ? 'Agregar' : 'Guardar'),
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

  Future<void> _saveTracking() async {
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

    // Validar que se haya configurado al menos una frecuencia
    if (_frequency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configura al menos una frecuencia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tracking = VideoTracking(
        id: widget.tracking?.id,
        categoryId: _selectedCategory!.id!,
        name: _nameController.text.trim(),
        startDate: _startDate,
        selectedDays: _selectedDays,
        frequency: _frequency,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        createdAt: widget.tracking?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Navigator.of(context).pop(tracking);
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
