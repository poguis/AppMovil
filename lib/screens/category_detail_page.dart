import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series_anime_category.dart';
import '../models/series.dart';
import '../models/season.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../widgets/series_dialog.dart';
import '../widgets/season_episode_dialog.dart';
import 'episode_log_page.dart';

class CategoryDetailPage extends StatefulWidget {
  final SeriesAnimeCategory category;

  const CategoryDetailPage({
    super.key,
    required this.category,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<Series> _series = [];
  bool _isLoading = true;
  String _selectedStatus = 'all'; // 'all', 'nueva', 'mirando', 'terminada', 'enEspera', 'historial'

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
      final series = await SeriesService.getSeriesByCategory(widget.category.id!);
      setState(() {
        _series = series;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar series: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddSeriesDialog() async {
    // Determinar qué estados permitir según el espacio disponible
    List<SeriesStatus>? allowedStatuses;
    final activeWatchingCount = _series.where((series) => series.status == SeriesStatus.mirando).length;
    
    // Si el límite de series "mirando" está lleno, solo permitir "En Espera" y "Terminado"
    if (activeWatchingCount >= widget.category.numberOfSeries) {
      allowedStatuses = [SeriesStatus.enEspera, SeriesStatus.terminada];
    }
    
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => SeriesDialog(
        categoryId: widget.category.id!,
        maxSeries: widget.category.numberOfSeries,
        allowedStatuses: allowedStatuses, // Todos los estados o solo En Espera y Terminado según el espacio
      ),
    );

    if (result != null) {
      try {
        if (result is Map<String, dynamic> && result['hasSeasonsData'] == true) {
          // Crear serie con temporadas y episodios
          final series = result['series'] as Series;
          final seasonsData = result['seasonsData'] as List<Map<String, dynamic>>;
          
          // Determinar el estado final (cambiar nueva → mirando automáticamente)
          final finalStatus = series.status == SeriesStatus.nueva 
              ? SeriesStatus.mirando  
              : series.status;
          
          await SeriesService.createCompleteSeries(
            categoryId: series.categoryId,
            name: series.name,
            status: finalStatus,
            seasonsData: seasonsData,
            description: series.description,
            startSeason: finalStatus == SeriesStatus.mirando ? series.currentSeason : null,
            startEpisode: finalStatus == SeriesStatus.mirando ? series.currentEpisode : null,
          );
        } else {
          // Crear serie simple
          await SeriesService.createSeries(result as Series);
        }
        
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Serie agregada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar serie: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditSeriesDialog(Series series) async {
    final result = await showDialog<Series>(
      context: context,
      builder: (context) => SeriesDialog(
        categoryId: widget.category.id!,
        maxSeries: widget.category.numberOfSeries,
        series: series,
      ),
    );

    if (result != null) {
      try {
        await SeriesService.updateSeries(result);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Serie actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar serie: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showManageSeasonsDialog(Series series) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SeasonEpisodeDialog(series: series),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteSeries(Series series) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Serie'),
        content: Text('¿Estás seguro de que quieres eliminar la serie "${series.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SeriesService.deleteSeries(series.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Serie eliminada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar serie: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _advanceEpisode(Series series) async {
    try {
      await SeriesService.advanceToNextEpisode(series.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capítulo avanzado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al avanzar capítulo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Series> get _filteredSeries {
    if (_selectedStatus == 'all') {
      // En "Todas" no mostrar las terminadas (van al historial)
      return _series.where((series) => series.status != SeriesStatus.terminada).toList();
    } else if (_selectedStatus == 'historial') {
      // En "Historial" solo mostrar las terminadas
      return _series.where((series) => series.status == SeriesStatus.terminada).toList();
    } else {
      // Para otros filtros, mostrar según el estado seleccionado
      return _series.where((series) => series.status.name == _selectedStatus).toList();
    }
  }

  bool get _canAddMoreSeries {
    // Solo las series "mirando" cuentan para el límite total
    final activeWatchingCount = _series.where((series) => series.status == SeriesStatus.mirando).length;
    return activeWatchingCount < widget.category.numberOfSeries;
  }

  Future<void> _updateSeriesOrder() async {
    try {
      await SeriesService.updateSeriesOrder(_filteredSeries);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el orden: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSeriesView() {
    if (_filteredSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedStatus == 'historial' 
                  ? Icons.history
                  : widget.category.type == 'video' 
                      ? Icons.play_circle_outline
                      : Icons.menu_book,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == 'all'
                  ? 'No hay series registradas'
                  : _selectedStatus == 'historial'
                      ? 'No hay series en el historial'
                      : 'No hay series con estado "${SeriesStatus.values.firstWhere((s) => s.name == _selectedStatus).displayName}"',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega una nueva serie para comenzar',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Vista especial para historial
    if (_selectedStatus == 'historial') {
      return _buildHistoryView();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredSeries.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _filteredSeries.removeAt(oldIndex);
          _filteredSeries.insert(newIndex, item);
          
          // Actualizar el orden en la base de datos
          _updateSeriesOrder();
        });
      },
      itemBuilder: (context, index) {
        final series = _filteredSeries[index];
        return Card(
          key: ValueKey(series.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: series.statusColor.withValues(alpha: 0.1),
              child: Icon(
                series.statusIcon,
                color: series.statusColor,
              ),
            ),
            title: Text(
              series.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (series.description != null)
                  Text(series.description!),
                const SizedBox(height: 4),
                Text(
                  'Estado: ${series.status.displayName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: series.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Progreso: ${series.currentProgress}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  series.statusSummary,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    await _showEditSeriesDialog(series);
                    break;
                  case 'seasons':
                    await _showManageSeasonsDialog(series);
                    break;
                  case 'advance':
                    await _advanceEpisode(series);
                    break;
                  case 'delete':
                    await _deleteSeries(series);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'seasons',
                  child: Row(
                    children: [
                      Icon(Icons.list),
                      SizedBox(width: 8),
                      Text('Gestionar Temporadas'),
                    ],
                  ),
                ),
                if (series.isActive)
                  const PopupMenuItem(
                    value: 'advance',
                    child: Row(
                      children: [
                        Icon(Icons.skip_next),
                        SizedBox(width: 8),
                        Text('Avanzar Capítulo'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showManageSeasonsDialog(series),
          ),
        );
      },
    );
  }

  Widget _buildHistoryView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredSeries.length,
      itemBuilder: (context, index) {
        final series = _filteredSeries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: series.statusColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.check_circle,
                        color: series.statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (series.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              series.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'delete') {
                          await _deleteSeries(series);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Información de la serie',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHistoryInfoItem(
                              'Progreso Final',
                              'Temporada ${series.currentSeason}, Capítulo ${series.currentEpisode}',
                              Icons.flag,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildHistoryInfoItem(
                              'Fecha de Finalización',
                              series.finishWatchingDate != null 
                                  ? DateFormat('dd/MM/yyyy').format(series.finishWatchingDate!)
                                  : 'No especificada',
                              Icons.calendar_today,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildHistoryInfoItem(
                              'Duración Total',
                              series.finishWatchingDate != null && series.startWatchingDate != null
                                  ? '${_getDaysBetween(series.startWatchingDate!, series.finishWatchingDate!)} días'
                                  : 'No calculable',
                              Icons.schedule,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildHistoryInfoItem(
                              'Estado',
                              'Completada',
                              Icons.check_circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryInfoItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  int _getDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  Widget _buildCategoryInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.category.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.category.description!,
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Series',
                    '${_series.where((s) => s.status == SeriesStatus.mirando).length}/${widget.category.numberOfSeries}',
                    Icons.playlist_play,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoCard(
                    'Atrasado',
                    widget.category.getDaysBehind() > 0 
                        ? '${widget.category.getDaysBehind()} días\n${widget.category.getChaptersBehind()} capítulos'
                        : 'Al día',
                    Icons.warning,
                    widget.category.getDaysBehind() > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'Todas', Icons.list),
            const SizedBox(width: 8),
            _buildFilterChip('nueva', 'Nueva', Icons.play_circle_outline, Colors.blue),
            const SizedBox(width: 8),
            _buildFilterChip('mirando', 'Mirando', Icons.play_circle, Colors.green),
            const SizedBox(width: 8),
            _buildFilterChip('enEspera', 'En Espera', Icons.pause_circle, Colors.orange),
            const SizedBox(width: 8),
            _buildFilterChip('historial', 'Historial', Icons.history, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, [Color? color]) {
    final isSelected = _selectedStatus == value;
    final chipColor = color ?? Colors.grey;
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : chipColor),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedStatus = value;
        });
      },
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.category.name),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Regresar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información de la categoría
          _buildCategoryInfo(),
          
          // Filtros de estado
          _buildStatusFilter(),
          const SizedBox(height: 16),
          
          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildSeriesView(),
          ),
        ],
      ),
      floatingActionButton: _canAddMoreSeries
          ? Builder(
              builder: (context) {
                // Determinar el tooltip según el espacio
                final activeWatchingCount = _series.where((series) => series.status == SeriesStatus.mirando).length;
                final tooltip = activeWatchingCount >= widget.category.numberOfSeries 
                    ? 'Agregar Serie (Solo En Espera y Terminado)' 
                    : 'Agregar Serie';
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: "episode_log",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EpisodeLogPage(
                              categoryId: widget.category.id!,
                              categoryName: widget.category.name,
                            ),
                          ),
                        );
                      },
                      backgroundColor: Colors.purple,
                      child: const Icon(Icons.list_alt, color: Colors.white),
                      tooltip: 'Registro de Episodios',
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton(
                      heroTag: "add_series",
                      onPressed: _showAddSeriesDialog,
                      child: const Icon(Icons.add),
                      tooltip: tooltip,
                    ),
                  ],
                );
              },
            )
          : null,
    );
  }
}

