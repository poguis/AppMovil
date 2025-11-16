import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series_anime_category.dart';
import '../models/series.dart';
import '../models/season.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../services/series_anime_category_service.dart';
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
  Map<String, int>? _delayInfo; // Para almacenar el atraso real calculado

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
      // Calcular el atraso real considerando episodios vistos
      final delayInfo = await SeriesAnimeCategoryService.calculateRealDelay(widget.category.id!);
      setState(() {
        _series = series;
        _delayInfo = delayInfo;
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

  // Método para recargar solo el atraso (más rápido que recargar todo)
  Future<void> _refreshDelay() async {
    try {
      final delayInfo = await SeriesAnimeCategoryService.calculateRealDelay(widget.category.id!);
      if (mounted) {
        setState(() {
          _delayInfo = delayInfo;
        });
      }
    } catch (e) {
      print('Error actualizando atraso: $e');
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
        categoryType: widget.category.type, // Pasar el tipo de categoría
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
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => SeriesDialog(
        categoryId: widget.category.id!,
        maxSeries: widget.category.numberOfSeries,
        series: series,
        categoryType: widget.category.type, // Pasar el tipo de categoría
      ),
    );

    if (result != null) {
      try {
        final isEditing = series != null;
        
        // Si es edición y hay temporadas modificadas
        if (isEditing && result is Map<String, dynamic> && result['hasSeasonsData'] == true) {
          final updatedSeries = result['series'] as Series;
          final seasonsData = result['seasonsData'] as List<Map<String, dynamic>>;
          
          // Actualizar la serie y las temporadas
          await SeriesService.updateSeriesWithSeasons(updatedSeries, seasonsData);
        } else {
          // Actualizar solo la serie
          await SeriesService.updateSeries(result is Map ? result['series'] as Series : result as Series);
        }
        
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

    // Recargar datos si se cerró el diálogo (puede haber agregado temporadas)
    if (result == true || result == null) {
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
      // Obtener todas las series de la categoría (no solo las filtradas)
      final allSeries = await SeriesService.getSeriesByCategory(widget.category.id!);
      
      // Crear un mapa para acceso rápido por ID
      final Map<int, Series> seriesMap = {};
      for (final s in allSeries) {
        if (s.id != null) {
          seriesMap[s.id!] = s;
        }
      }
      
      // Crear lista final con el nuevo orden: primero las reordenadas, luego las demás
      final List<Series> reorderedAllSeries = [];
      
      // Agregar las series filtradas en su nuevo orden
      final Set<int> filteredIds = _filteredSeries.map((s) => s.id!).where((id) => id != null).cast<int>().toSet();
      for (final filteredSeries in _filteredSeries) {
        if (filteredSeries.id != null) {
          reorderedAllSeries.add(seriesMap[filteredSeries.id!]!);
        }
      }
      
      // Agregar las series que no están en el filtro, manteniendo su orden original relativo
      for (final series in allSeries) {
        if (series.id != null && !filteredIds.contains(series.id)) {
          reorderedAllSeries.add(series);
        }
      }
      
      // Actualizar el orden de todas las series
      await SeriesService.updateSeriesOrder(reorderedAllSeries);
      
      // Recargar datos para reflejar el nuevo orden
      _loadData();
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
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _filteredSeries.removeAt(oldIndex);
          _filteredSeries.insert(newIndex, item);
        });
        
        // Actualizar el orden en la base de datos (asíncrono, sin await para no bloquear UI)
        _updateSeriesOrder();
      },
      itemBuilder: (context, index) {
        final series = _filteredSeries[index];
        return Card(
          key: ValueKey('series_${series.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drag_handle,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: series.statusColor.withValues(alpha: 0.1),
                  child: Icon(
                    series.statusIcon,
                    color: series.statusColor,
                  ),
                ),
              ],
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
                  widget.category.type == 'lectura'
                      ? 'Progreso: Tomo ${series.currentSeason}, Capítulo ${series.currentEpisode}'
                      : 'Progreso: ${series.currentProgress}',
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
                PopupMenuItem(
                  value: 'seasons',
                  child: Row(
                    children: [
                      const Icon(Icons.list),
                      const SizedBox(width: 8),
                      Text(widget.category.type == 'lectura' 
                          ? 'Gestionar Tomos' 
                          : 'Gestionar Temporadas'),
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
            // Remover onTap para permitir el drag & drop
            // El usuario puede usar el menú de opciones para gestionar temporadas
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
                        if (value == 'seasons') {
                          await _showManageSeasonsDialog(series);
                        } else if (value == 'delete') {
                          await _deleteSeries(series);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'seasons',
                          child: Row(
                            children: [
                              const Icon(Icons.list),
                              const SizedBox(width: 8),
                              Text(widget.category.type == 'lectura' 
                                  ? 'Gestionar Tomos' 
                                  : 'Gestionar Temporadas'),
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
                            child: FutureBuilder<Map<String, int>?>(
                              future: SeriesService.getLastWatchedEpisode(series.id!),
                              builder: (context, snapshot) {
                                String progressText;
                                if (snapshot.hasData && snapshot.data != null) {
                                  final lastWatched = snapshot.data!;
                                  if (widget.category.type == 'lectura') {
                                    progressText = 'Tomo ${lastWatched['season']}, Capítulo ${lastWatched['episode']}';
                                  } else {
                                    progressText = 'Temporada ${lastWatched['season']}, Capítulo ${lastWatched['episode']}';
                                  }
                                } else {
                                  // Si no hay episodios vistos, usar el progreso actual
                                  if (widget.category.type == 'lectura') {
                                    progressText = 'Tomo ${series.currentSeason}, Capítulo ${series.currentEpisode}';
                                  } else {
                                    progressText = 'Temporada ${series.currentSeason}, Capítulo ${series.currentEpisode}';
                                  }
                                }
                                return _buildHistoryInfoItem(
                                  'Progreso Final',
                                  progressText,
                                  Icons.flag,
                                );
                              },
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
                  child: _buildDelayInfoCard(),
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

  Widget _buildDelayInfoCard() {
    final daysBehind = _delayInfo?['daysBehind'] ?? 0;
    final chaptersBehind = _delayInfo?['chaptersBehind'] ?? 0;
    final hasDelay = daysBehind > 0 || chaptersBehind > 0;
    final color = hasDelay ? Colors.red : Colors.green;
    
    final isReading = widget.category.type == 'lectura';
    final value = hasDelay 
        ? (isReading
            ? '$daysBehind ${daysBehind == 1 ? 'día' : 'días'}\n$chaptersBehind ${chaptersBehind == 1 ? 'tomo' : 'tomos'}'
            : '$daysBehind ${daysBehind == 1 ? 'día' : 'días'}\n$chaptersBehind ${chaptersBehind == 1 ? 'capítulo' : 'capítulos'}')
        : 'Al día';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning, color: color, size: 20),
          const SizedBox(height: 4),
            Text(
              widget.category.type == 'lectura' ? 'Atraso' : 'Atrasado',
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
    
    // Contar series terminadas para el historial
    int? count;
    if (value == 'historial') {
      count = _series.where((series) => series.status == SeriesStatus.terminada).length;
    }
    
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : chipColor),
          const SizedBox(width: 4),
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : chipColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : chipColor,
                ),
              ),
            ),
          ],
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
      floatingActionButton: Builder(
        builder: (context) {
          // Determinar el tooltip según el espacio
          final activeWatchingCount = _series.where((series) => series.status == SeriesStatus.mirando).length;
          final canAdd = activeWatchingCount < widget.category.numberOfSeries;
          final tooltip = canAdd 
              ? 'Agregar Serie' 
              : 'Límite alcanzado (${widget.category.numberOfSeries}). Puedes editar o finalizar series.';

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: "episode_log",
                onPressed: () async {
                  // Navegar a la página de registro de episodios y esperar a que regrese
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EpisodeLogPage(
                        categoryId: widget.category.id!,
                        categoryName: widget.category.name,
                      ),
                    ),
                  );
                  // Cuando regresa, actualizar el atraso
                  _refreshDelay();
                },
                backgroundColor: Colors.purple,
                child: const Icon(Icons.list_alt, color: Colors.white),
                tooltip: 'Registro de Episodios',
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: "add_series",
                onPressed: canAdd ? _showAddSeriesDialog : null,
                child: const Icon(Icons.add),
                tooltip: tooltip,
              ),
            ],
          );
        },
      ),
    );
  }
}

