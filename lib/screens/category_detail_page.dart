import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series_anime_category.dart';
import '../models/series.dart';
import '../models/season.dart';
import '../models/episode.dart';
import '../services/series_service.dart';
import '../widgets/series_dialog.dart';
import '../widgets/season_episode_dialog.dart';

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
  String _selectedStatus = 'all'; // 'all', 'nueva', 'mirando', 'terminada', 'enEspera'

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
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => SeriesDialog(
        categoryId: widget.category.id!,
        maxSeries: widget.category.numberOfSeries,
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
    if (_selectedStatus == 'all') return _series;
    return _series.where((series) => series.status.name == _selectedStatus).toList();
  }

  bool get _canAddMoreSeries {
    return _series.length < widget.category.numberOfSeries;
  }

  Widget _buildSeriesView() {
    if (_filteredSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.category.type == 'video' 
                  ? Icons.play_circle_outline
                  : Icons.menu_book,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == 'all'
                  ? 'No hay series registradas'
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredSeries.length,
      itemBuilder: (context, index) {
        final series = _filteredSeries[index];
        return Card(
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
                    '${_series.length}/${widget.category.numberOfSeries}',
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
            _buildFilterChip('terminada', 'Terminada', Icons.check_circle, Colors.purple),
            const SizedBox(width: 8),
            _buildFilterChip('enEspera', 'En Espera', Icons.pause_circle, Colors.orange),
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
          ? FloatingActionButton(
              onPressed: _showAddSeriesDialog,
              child: const Icon(Icons.add),
              tooltip: 'Agregar Serie',
            )
          : null,
    );
  }
}

