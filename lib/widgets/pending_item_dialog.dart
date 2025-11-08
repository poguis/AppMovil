import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  PendingItemType _selectedType = PendingItemType.pelicula;
  PendingItemStatus _selectedStatus = PendingItemStatus.pendiente;
  DateTime? _startDate;
  DateTime? _endDate;
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
    _startDate = item.startDate;
    _endDate = item.endDate;
    _isOngoing = item.isOngoing;
    _selectedSeriesFormat = item.seriesFormat;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
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
      // Series y anime requieren fecha de inicio
      if (_startDate == null && !_isOngoing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La fecha de inicio es obligatoria'),
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
      startDate: _selectedType != PendingItemType.pelicula ? _startDate : null,
      endDate: _selectedType != PendingItemType.pelicula && !_isOngoing
          ? _endDate
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
                                _startDate = null;
                                _endDate = null;
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

                      // Fechas (solo para series y anime)
                      if (isSeriesOrAnime) ...[
                        const Text(
                          'Fechas',
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
                                _endDate = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(_startDate != null
                              ? 'Inicio: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'
                              : 'Fecha de inicio'),
                          trailing: _startDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _startDate = null;
                                    });
                                  },
                                )
                              : null,
                          onTap: _selectStartDate,
                        ),
                        if (!_isOngoing)
                          ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(_endDate != null
                                ? 'Fin: ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                                : 'Fecha de terminación (opcional)'),
                            trailing: _endDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _endDate = null;
                                      });
                                    },
                                  )
                                : null,
                            onTap: _selectEndDate,
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

