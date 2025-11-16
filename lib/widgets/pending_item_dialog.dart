import 'package:flutter/material.dart';
import '../models/pending_item.dart';

class PendingItemDialog extends StatefulWidget {
  final PendingItem? item;
  final PendingItemType? initialType;

  const PendingItemDialog({
    super.key,
    this.item,
    this.initialType,
  });

  @override
  State<PendingItemDialog> createState() => _PendingItemDialogState();
}

class _PendingItemDialogState extends State<PendingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();

  PendingItemType _selectedType = PendingItemType.pelicula;
  PendingItemStatus _selectedStatus = PendingItemStatus.pendiente;
  bool _isOngoing = false;
  SeriesFormat? _selectedSeriesFormat;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _initializeWithItem(widget.item!);
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
  }

  void _initializeWithItem(PendingItem item) {
    _titleController.text = item.title;
    _selectedType = item.type;
    _selectedStatus = item.status;
    _yearController.text = item.year?.toString() ?? '';
    _startYearController.text = item.startYear?.toString() ?? '';
    _endYearController.text = item.endYear?.toString() ?? '';
    _isOngoing = item.isOngoing;
    _selectedSeriesFormat = item.seriesFormat;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validaciones específicas según tipo
    if (_selectedType == PendingItemType.pelicula) {
      if (_yearController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El año es obligatorio para películas'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Series y anime requieren año de inicio (opcional si está en emisión)
      if (_startYearController.text.trim().isEmpty && !_isOngoing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El año de inicio es obligatorio (o marca "En emisión")'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final now = DateTime.now();
    // Si el estado es "visto", mantener la fecha existente o asignar una nueva
    // Si cambia a otro estado, limpiar la fecha
    DateTime? watchedDate;
    if (_selectedStatus == PendingItemStatus.visto) {
      // Si ya tenía fecha de visualización, mantenerla; si no, asignar fecha actual
      watchedDate = widget.item?.watchedDate ?? now;
    } else {
      // Si cambia a pendiente o mirando, limpiar la fecha
      watchedDate = null;
    }

    final item = PendingItem(
      id: widget.item?.id,
      type: _selectedType,
      title: _titleController.text.trim(),
      year: _selectedType == PendingItemType.pelicula
          ? int.tryParse(_yearController.text.trim())
          : null,
      startYear: _selectedType != PendingItemType.pelicula
          ? (_startYearController.text.trim().isNotEmpty
              ? int.tryParse(_startYearController.text.trim())
              : null)
          : null,
      endYear: _selectedType != PendingItemType.pelicula && !_isOngoing
          ? (_endYearController.text.trim().isNotEmpty
              ? int.tryParse(_endYearController.text.trim())
              : null)
          : null,
      isOngoing: _selectedType != PendingItemType.pelicula ? _isOngoing : false,
      seriesFormat: _selectedType == PendingItemType.serie ? _selectedSeriesFormat : null,
      status: _selectedStatus,
      watchedDate: watchedDate,
      createdAt: widget.item?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final isPelicula = _selectedType == PendingItemType.pelicula;
    final isSeriesOrAnime = !isPelicula;

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                widget.item == null
                    ? 'Agregar ${_selectedType.displayName}'
                    : 'Editar ${_selectedType.displayName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tipo (solo en creación)
                      if (widget.item == null) ...[
                        const Text(
                          'Tipo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: PendingItemType.values.map((type) {
                            final isSelected = _selectedType == type;
                            return FilterChip(
                              selected: isSelected,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(type == PendingItemType.pelicula
                                      ? Icons.movie
                                      : type == PendingItemType.serie
                                          ? Icons.tv
                                          : Icons.animation),
                                  const SizedBox(width: 4),
                                  Text(type.displayName),
                                ],
                              ),
                              onSelected: (selected) {
                                setState(() {
                              _selectedType = type;
                              if (type == PendingItemType.pelicula) {
                                _startYearController.clear();
                                _endYearController.clear();
                                _isOngoing = false;
                                _selectedSeriesFormat = null;
                              } else if (type != PendingItemType.serie) {
                                // Si cambia a anime, limpiar el formato
                                _selectedSeriesFormat = null;
                              }
                            });
                          },
                              selectedColor: type == PendingItemType.pelicula
                                  ? Colors.purple
                                  : type == PendingItemType.serie
                                      ? Colors.blue
                                      : Colors.pink,
                              checkmarkColor: Colors.white,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Título
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El título es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Formato (solo para series)
                      if (_selectedType == PendingItemType.serie) ...[
                        const Text(
                          'Formato',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: SeriesFormat.values.map((format) {
                            final isSelected = _selectedSeriesFormat == format;
                            return FilterChip(
                              selected: isSelected,
                              label: Text(format.displayName),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSeriesFormat = selected ? format : null;
                                });
                              },
                              selectedColor: Colors.blue,
                              checkmarkColor: Colors.white,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Año (solo para películas)
                      if (isPelicula) ...[
                        TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Año',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El año es obligatorio';
                            }
                            final year = int.tryParse(value.trim());
                            if (year == null || year < 1900 || year > 2100) {
                              return 'Ingresa un año válido (1900-2100)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Años (solo para series y anime)
                      if (isSeriesOrAnime) ...[
                        const Text(
                          'Años',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('En emisión'),
                          value: _isOngoing,
                          onChanged: (value) {
                            setState(() {
                              _isOngoing = value ?? false;
                              if (_isOngoing) {
                                _endYearController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _startYearController,
                          decoration: const InputDecoration(
                            labelText: 'Año de inicio',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                            helperText: 'Opcional si está en emisión',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final year = int.tryParse(value.trim());
                              if (year == null || year < 1900 || year > 2100) {
                                return 'Ingresa un año válido (1900-2100)';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!_isOngoing)
                          TextFormField(
                            controller: _endYearController,
                            decoration: const InputDecoration(
                              labelText: 'Año de terminación (opcional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                final year = int.tryParse(value.trim());
                                if (year == null || year < 1900 || year > 2100) {
                                  return 'Ingresa un año válido (1900-2100)';
                                }
                                // Validar que el año de fin no sea menor que el de inicio
                                final startYear = int.tryParse(_startYearController.text.trim());
                                if (startYear != null && year < startYear) {
                                  return 'El año de fin debe ser mayor o igual al de inicio';
                                }
                              }
                              return null;
                            },
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Estado
                      const Text(
                        'Estado',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PendingItemStatus.values.map((status) {
                          final isSelected = _selectedStatus == status;
                          return FilterChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(status == PendingItemStatus.pendiente
                                    ? Icons.pending
                                    : status == PendingItemStatus.mirando
                                        ? Icons.play_circle
                                        : Icons.check_circle),
                                const SizedBox(width: 4),
                                Text(status.displayName),
                              ],
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedStatus = status;
                              });
                            },
                            selectedColor: status == PendingItemStatus.pendiente
                                ? Colors.grey
                                : status == PendingItemStatus.mirando
                                    ? Colors.blue
                                    : Colors.green,
                            checkmarkColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(widget.item == null ? 'Agregar' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

