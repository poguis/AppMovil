import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series.dart';

class SeriesDialog extends StatefulWidget {
  final int categoryId;
  final int maxSeries;
  final Series? series;

  const SeriesDialog({
    super.key,
    required this.categoryId,
    required this.maxSeries,
    this.series,
  });

  @override
  State<SeriesDialog> createState() => _SeriesDialogState();
}

class _SeriesDialogState extends State<SeriesDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  SeriesStatus _selectedStatus = SeriesStatus.nueva;
  int _currentSeason = 1;
  int _currentEpisode = 1;
  DateTime? _startWatchingDate;
  DateTime? _finishWatchingDate;
  
  bool _isCreatingSeasons = false;
  List<Map<String, dynamic>> _seasonsData = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.series != null) {
      _initializeWithSeries(widget.series!);
    }
  }

  void _initializeWithSeries(Series series) {
    _nameController.text = series.name;
    _descriptionController.text = series.description ?? '';
    _selectedStatus = series.status;
    _currentSeason = series.currentSeason;
    _currentEpisode = series.currentEpisode;
    _startWatchingDate = series.startWatchingDate;
    _finishWatchingDate = series.finishWatchingDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startWatchingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _startWatchingDate = date;
      });
    }
  }

  Future<void> _selectFinishDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _finishWatchingDate ?? DateTime.now(),
      firstDate: _startWatchingDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _finishWatchingDate = date;
      });
    }
  }

  void _addSeason() {
    setState(() {
      _seasonsData.add({
        'seasonNumber': _seasonsData.length + 1,
        'title': 'Temporada ${_seasonsData.length + 1}',
        'totalEpisodes': 12,
      });
    });
  }

  void _removeSeason(int index) {
    setState(() {
      _seasonsData.removeAt(index);
      // Renumerar temporadas
      for (int i = 0; i < _seasonsData.length; i++) {
        _seasonsData[i]['seasonNumber'] = i + 1;
        _seasonsData[i]['title'] = 'Temporada ${i + 1}';
      }
    });
  }

  void _updateSeason(int index, String field, dynamic value) {
    setState(() {
      _seasonsData[index][field] = value;
    });
  }

  Series _createSeries() {
    final now = DateTime.now();
    
    // Para nueva y en espera: siempre empiezan desde temporada 1, capítulo 1
    int currentSeason = _currentSeason;
    int currentEpisode = _currentEpisode;
    
    if (_selectedStatus == SeriesStatus.nueva || _selectedStatus == SeriesStatus.enEspera) {
      currentSeason = 1;
      currentEpisode = 1;
    }
    
    return Series(
      id: widget.series?.id,
      categoryId: widget.categoryId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      status: _selectedStatus,
      currentSeason: currentSeason,
      currentEpisode: currentEpisode,
      startWatchingDate: _startWatchingDate,
      finishWatchingDate: _finishWatchingDate,
      createdAt: widget.series?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final needsSeasonsData = _selectedStatus == SeriesStatus.nueva || 
                           _selectedStatus == SeriesStatus.mirando || 
                           _selectedStatus == SeriesStatus.terminada ||
                           _selectedStatus == SeriesStatus.enEspera;

    if (needsSeasonsData && (_isCreatingSeasons != true || _seasonsData.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar al menos una temporada para este estado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar progreso para estado "mirando"
    if (_selectedStatus == SeriesStatus.mirando) {
      if (_currentSeason < 1 || _currentEpisode < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes indicar un progreso válido (temporada y capítulo)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validar que el progreso esté dentro del rango de las temporadas definidas
      bool progressValid = false;
      int totalEpisodesBefore = 0;
      
      for (final season in _seasonsData) {
        final seasonNum = season['seasonNumber'] as int;
        final totalEpisodes = season['totalEpisodes'] as int;
        
        if (seasonNum == _currentSeason) {
          if (_currentEpisode <= totalEpisodes) {
            progressValid = true;
          }
          break;
        }
        totalEpisodesBefore += totalEpisodes;
      }
      
      if (!progressValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El progreso seleccionado no está dentro del rango de las temporadas definidas'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Crear la serie con temporadas y episodios si es necesario
    if (needsSeasonsData) {
      Navigator.of(context).pop({
        'series': _createSeries(),
        'seasonsData': _seasonsData,
        'hasSeasonsData': true,
      });
    } else {
      Navigator.of(context).pop(_createSeries());
    }
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado de la serie',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: SeriesStatus.values.map((status) {
            final isSelected = _selectedStatus == status;
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(status == SeriesStatus.nueva ? Icons.play_circle_outline :
                       status == SeriesStatus.mirando ? Icons.play_circle :
                       status == SeriesStatus.terminada ? Icons.check_circle :
                       Icons.pause_circle, size: 16),
                  const SizedBox(width: 4),
                  Text(status.displayName),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedStatus = status;
                });
              },
              selectedColor: status == SeriesStatus.nueva ? Colors.blue :
                           status == SeriesStatus.mirando ? Colors.green :
                           status == SeriesStatus.terminada ? Colors.purple :
                           Colors.orange,
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    // Solo mostrar progreso actual para el estado "Mirando"
    if (_selectedStatus != SeriesStatus.mirando) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progreso actual',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _currentSeason.toString(),
                decoration: const InputDecoration(
                  labelText: 'Temporada actual',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _currentSeason = int.tryParse(value) ?? 1;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa la temporada actual';
                  }
                  final season = int.tryParse(value);
                  if (season == null || season < 1) {
                    return 'La temporada debe ser mayor a 0';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _currentEpisode.toString(),
                decoration: const InputDecoration(
                  labelText: 'Capítulo actual',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _currentEpisode = int.tryParse(value) ?? 1;
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el capítulo actual';
                  }
                  final episode = int.tryParse(value);
                  if (episode == null || episode < 1) {
                    return 'El capítulo debe ser mayor a 0';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Indica en qué capítulo de qué temporada te quedaste viendo',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    // Solo mostrar fechas para terminada
    if (_selectedStatus != SeriesStatus.terminada) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fechas importantes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(_finishWatchingDate != null
                    ? DateFormat('dd/MM/yyyy').format(_finishWatchingDate!)
                    : 'Fecha de finalización'),
                subtitle: const Text('Cuándo terminaste de ver'),
                onTap: _selectFinishDate,
                trailing: _finishWatchingDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _finishWatchingDate = null;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeasonsSection() {
    // Para nueva, mirando, terminada y enEspera la creación de temporadas es obligatoria
    final needsSeasonsData = _selectedStatus == SeriesStatus.nueva || 
                           _selectedStatus == SeriesStatus.mirando || 
                           _selectedStatus == SeriesStatus.terminada ||
                           _selectedStatus == SeriesStatus.enEspera;
    
    // Activar automáticamente si es necesario
    if (needsSeasonsData && !_isCreatingSeasons) {
      setState(() {
        _isCreatingSeasons = true;
        if (_seasonsData.isEmpty) {
          _addSeason();
        }
      });
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Temporadas y capítulos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!needsSeasonsData) ...[
              const Spacer(),
              Switch(
                value: _isCreatingSeasons,
                onChanged: (value) {
                  setState(() {
                    _isCreatingSeasons = value;
                    if (!value) {
                      _seasonsData.clear();
                    } else if (_seasonsData.isEmpty) {
                      _addSeason();
                    }
                  });
                },
              ),
              const Text('Crear temporadas'),
            ] else ...[
              const Spacer(),
              Text(
                'Obligatorio',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (_isCreatingSeasons) ...[
          const SizedBox(height: 16),
          Text(
            _getSeasonsDescription(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_seasonsData.length, (index) {
            final season = _seasonsData[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: season['title'],
                            decoration: const InputDecoration(
                              labelText: 'Título de la temporada',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => _updateSeason(index, 'title', value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: season['totalEpisodes'].toString(),
                            decoration: const InputDecoration(
                              labelText: 'Total de capítulos',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _updateSeason(index, 'totalEpisodes', int.tryParse(value) ?? 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSeason(index),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _addSeason,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Temporada'),
          ),
        ],
      ],
    );
  }

  String _getSeasonsDescription() {
    switch (_selectedStatus) {
      case SeriesStatus.nueva:
        return 'Define todas las temporadas de la serie. Empezará desde la temporada 1, capítulo 1.';
      case SeriesStatus.mirando:
        return 'Define todas las temporadas de la serie y después indica tu progreso actual arriba.';
      case SeriesStatus.terminada:
        return 'Define todas las temporadas de la serie terminada.';
      case SeriesStatus.enEspera:
        return 'Define todas las temporadas de la serie en espera.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.series == null ? 'Agregar Nueva Serie' : 'Editar Serie',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre de la serie
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la serie',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.movie),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre de la serie es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Descripción
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      
                      // Estado
                      _buildStatusSelector(),
                      const SizedBox(height: 24),
                      
                      // Progreso
                      _buildProgressSection(),
                      const SizedBox(height: 24),
                      
                      // Fechas
                      _buildDateSection(),
                      const SizedBox(height: 24),
                      
                      // Temporadas
                      _buildSeasonsSection(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Botones
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
                  child: Text(widget.series == null ? 'Crear Serie' : 'Actualizar Serie'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

