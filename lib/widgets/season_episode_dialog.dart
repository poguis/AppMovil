import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series.dart';
import '../models/season.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../services/series_anime_category_service.dart';

class SeasonEpisodeDialog extends StatefulWidget {
  final Series series;

  const SeasonEpisodeDialog({
    super.key,
    required this.series,
  });

  @override
  State<SeasonEpisodeDialog> createState() => _SeasonEpisodeDialogState();
}

class _SeasonEpisodeDialogState extends State<SeasonEpisodeDialog> {
  List<Season> _seasons = [];
  Map<int, List<Episode>> _episodesBySeason = {};
  bool _isLoading = true;
  String? _categoryType; // 'video' o 'lectura'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el tipo de categoría
      final category = await SeriesAnimeCategoryService.getCategoryById(widget.series.categoryId);
      final categoryType = category?.type;

      final seasons = await SeriesService.getSeasonsBySeries(widget.series.id!);
      final episodesBySeason = <int, List<Episode>>{};

      for (final season in seasons) {
        final episodes = await SeriesService.getEpisodesBySeason(season.id!);
        episodesBySeason[season.id!] = episodes;
      }

      setState(() {
        _categoryType = categoryType;
        _seasons = seasons;
        _episodesBySeason = episodesBySeason;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addSeason() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SeasonCreationDialog(
        nextSeasonNumber: _seasons.isEmpty ? 1 : _seasons.last.seasonNumber + 1,
        categoryType: _categoryType,
      ),
    );

    if (result != null) {
      try {
        final season = Season(
          seriesId: widget.series.id!,
          seasonNumber: result['seasonNumber'] as int,
          title: result['title'] as String?,
          totalEpisodes: result['totalEpisodes'] as int,
          watchedEpisodes: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final seasonId = await SeriesService.createSeason(season);

        // Crear capítulos
        final episodes = <Episode>[];
        for (int i = 1; i <= season.totalEpisodes; i++) {
          final episode = Episode(
            seasonId: seasonId,
            episodeNumber: i,
            title: 'Capítulo $i',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: EpisodeStatus.noVisto,
          );
          await SeriesService.createEpisode(episode);
          episodes.add(episode);
        }

        // Si la serie está terminada o en espera, cambiar automáticamente a "Mirando"
        bool statusChanged = false;
        if (widget.series.status == SeriesStatus.terminada || 
            widget.series.status == SeriesStatus.enEspera) {
          // Al agregar un nuevo tomo/temporada, establecer un nuevo startWatchingDate
          // para marcar el inicio de la nueva temporada. Mantener finishWatchingDate
          // para distinguir series que fueron activas (tienen finishWatchingDate) de
          // series que fueron creadas como terminadas (no tienen finishWatchingDate)
          final updatedSeries = widget.series.copyWith(
            status: SeriesStatus.mirando,
            startWatchingDate: DateTime.now(), // Nuevo punto de inicio para la nueva temporada
            // Mantener finishWatchingDate para que los capítulos antiguos sigan contando
            currentSeason: season.seasonNumber,
            currentEpisode: 1,
            updatedAt: DateTime.now(),
          );
          await SeriesService.updateSeries(updatedSeries);
          statusChanged = true;
        }

        setState(() {
          _seasons.add(season.copyWith(id: seasonId));
          _episodesBySeason[seasonId] = episodes;
        });

        final isReading = _categoryType == 'lectura';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                statusChanged 
                  ? (isReading 
                      ? 'Tomo agregado. El manga/libro ahora está en estado "Mirando"'
                      : 'Temporada agregada. La serie ahora está en estado "Mirando"')
                  : (isReading 
                      ? 'Tomo agregado exitosamente'
                      : 'Temporada agregada exitosamente')
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          // Si cambió el estado, cerrar el diálogo para refrescar la vista
          if (statusChanged) {
            Navigator.of(context).pop(true); // Retornar true para indicar que se actualizó
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar temporada: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _markEpisodeAsWatched(Episode episode) async {
    try {
      await SeriesService.markEpisodeAsWatched(episode.id!);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capítulo marcado como visto.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al marcar capítulo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editEpisode(Episode episode) async {
    final result = await showDialog<Episode>(
      context: context,
      builder: (context) => _EpisodeEditDialog(episode: episode),
    );

    if (result != null) {
      try {
        await SeriesService.updateEpisode(result);
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Capítulo actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar capítulo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildSeasonCard(Season season) {
    final episodes = _episodesBySeason[season.id] ?? [];
    final watchedEpisodes = episodes.where((e) => e.isWatched).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: season.statusColor.withValues(alpha: 0.1),
          child: Icon(season.statusIcon, color: season.statusColor),
        ),
        title: Text(
          season.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progreso: $watchedEpisodes/${episodes.length} capítulos'),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: episodes.isEmpty ? 0 : watchedEpisodes / episodes.length,
              backgroundColor: Colors.grey.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(season.statusColor),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Información de la temporada
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Estado',
                        season.status,
                        season.statusIcon,
                        season.statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoCard(
                        'Progreso',
                        '${season.progressPercentage.toInt()}%',
                        Icons.percent,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Lista de capítulos
                if (episodes.isEmpty)
                  const Text(
                    'No hay capítulos en esta temporada',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      return _buildEpisodeCard(episode);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    return GestureDetector(
      onTap: () => _editEpisode(episode),
      child: Container(
        decoration: BoxDecoration(
          color: episode.statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: episode.statusColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              episode.statusIcon,
              color: episode.statusColor,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              '${episode.episodeNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: episode.statusColor,
              ),
            ),
          ],
        ),
      ),
    );
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
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gestionar: ${widget.series.name}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Información de la serie
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.series.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.series.statusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.series.statusIcon,
                    color: widget.series.statusColor,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estado: ${widget.series.status.displayName}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: widget.series.statusColor,
                          ),
                        ),
                        Text('Progreso: ${widget.series.currentProgress}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Botón para agregar temporada/tomo
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addSeason,
                    icon: const Icon(Icons.add),
                    label: Text(_categoryType == 'lectura' ? 'Agregar Tomo' : 'Agregar Temporada'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lista de temporadas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _seasons.isEmpty
                      ? Center(
                          child: Text(
                            _categoryType == 'lectura'
                                ? 'No hay tomos registrados\nAgrega un tomo para comenzar'
                                : 'No hay temporadas registradas\nAgrega una temporada para comenzar',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _seasons.length,
                          itemBuilder: (context, index) {
                            return _buildSeasonCard(_seasons[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonCreationDialog extends StatefulWidget {
  final int nextSeasonNumber;
  final String? categoryType;

  const _SeasonCreationDialog({
    required this.nextSeasonNumber,
    this.categoryType,
  });

  @override
  State<_SeasonCreationDialog> createState() => _SeasonCreationDialogState();
}

class _SeasonCreationDialogState extends State<_SeasonCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _episodesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isReading = widget.categoryType == 'lectura';
    _titleController.text = isReading 
        ? 'Tomo ${widget.nextSeasonNumber}' 
        : 'Temporada ${widget.nextSeasonNumber}';
    _episodesController.text = '12';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _episodesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'seasonNumber': widget.nextSeasonNumber,
      'title': _titleController.text.trim(),
      'totalEpisodes': int.parse(_episodesController.text),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isReading = widget.categoryType == 'lectura';
    return AlertDialog(
      title: Text(isReading ? 'Nuevo Tomo' : 'Nueva Temporada'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isReading ? 'Título del tomo' : 'Título de la temporada',
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _episodesController,
              decoration: InputDecoration(
                labelText: isReading ? 'Número de capítulos del tomo' : 'Número de capítulos',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El número de capítulos es obligatorio';
                }
                final episodes = int.tryParse(value);
                if (episodes == null || episodes < 1) {
                  return 'Debe ser un número mayor a 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _EpisodeEditDialog extends StatefulWidget {
  final Episode episode;

  const _EpisodeEditDialog({required this.episode});

  @override
  State<_EpisodeEditDialog> createState() => _EpisodeEditDialogState();
}

class _EpisodeEditDialogState extends State<_EpisodeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  EpisodeStatus _selectedStatus = EpisodeStatus.noVisto;
  double _watchProgress = 0.0;
  int? _rating;
  DateTime? _watchDate;

  @override
  void initState() {
    super.initState();
    _initializeWithEpisode(widget.episode);
  }

  void _initializeWithEpisode(Episode episode) {
    _titleController.text = episode.title ?? '';
    _descriptionController.text = episode.description ?? '';
    _notesController.text = episode.notes ?? '';
    _selectedStatus = episode.status;
    _watchProgress = episode.watchProgress ?? 0.0;
    _rating = episode.rating;
    _watchDate = episode.watchDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectWatchDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _watchDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _watchDate = date;
      });
    }
  }

  Episode _createEpisode() {
    return widget.episode.copyWith(
      title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      status: _selectedStatus,
      watchProgress: _selectedStatus == EpisodeStatus.visto ? 1.0 : 
                    _selectedStatus == EpisodeStatus.parcialmenteVisto ? _watchProgress : null,
      watchDate: _selectedStatus == EpisodeStatus.visto ? (_watchDate ?? DateTime.now()) : null,
      rating: _rating,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_createEpisode());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar Capítulo ${widget.episode.episodeNumber}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del capítulo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Estado del capítulo
              const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: EpisodeStatus.values.map((status) {
                  final isSelected = _selectedStatus == status;
                  return FilterChip(
                    selected: isSelected,
                    label: Text(status.displayName),
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
                    selectedColor: status == EpisodeStatus.noVisto ? Colors.grey :
                                 status == EpisodeStatus.parcialmenteVisto ? Colors.orange :
                                 Colors.green,
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              
              // Progreso de visualización
              if (_selectedStatus == EpisodeStatus.parcialmenteVisto) ...[
                const SizedBox(height: 16),
                Text('Progreso: ${(_watchProgress * 100).toInt()}%'),
                Slider(
                  value: _watchProgress,
                  onChanged: (value) {
                    setState(() {
                      _watchProgress = value;
                    });
                  },
                  divisions: 100,
                ),
              ],
              
              // Calificación
              const SizedBox(height: 16),
              const Text('Calificación:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final starNumber = index + 1;
                  final isSelected = _rating != null && _rating! >= starNumber;
                  
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        _rating = _rating == starNumber ? null : starNumber;
                      });
                    },
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: isSelected ? Colors.amber : Colors.grey,
                    ),
                  );
                }),
              ),
              
              // Fecha de visualización
              if (_selectedStatus == EpisodeStatus.visto) ...[
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_watchDate != null
                      ? DateFormat('dd/MM/yyyy').format(_watchDate!)
                      : 'Fecha de visualización'),
                  onTap: _selectWatchDate,
                  trailing: _watchDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _watchDate = null;
                            });
                          },
                        )
                      : null,
                ),
              ],
              
              // Notas
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
