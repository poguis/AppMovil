import 'package:flutter/material.dart';
import '../models/episode_log_entry.dart';
import '../services/episode_log_service.dart';
import '../services/series_service.dart';
import '../services/series_anime_category_service.dart';
import '../models/series.dart';
import '../models/episode.dart';

class EpisodeLogPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const EpisodeLogPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<EpisodeLogPage> createState() => _EpisodeLogPageState();
}

class _EpisodeLogPageState extends State<EpisodeLogPage> {
  List<EpisodeLogEntry> _allEpisodes = [];
  List<EpisodeLogEntry> _allEpisodesIntercalated = []; // Todos los episodios intercalados (vistos + pendientes)
  List<EpisodeLogEntry> _filteredEpisodes = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending'; // 'all', 'pending', 'watched'
  bool _isEditMode = false;
  String? _categoryType; // 'video' o 'lectura'
  int? _lastServedSeriesId; // serie que acaba de consumir un capítulo/tomo
  int _chaptersBehind = 0; // Capítulos/tomos de atraso para resaltar visualmente

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener tipo de categoría para decidir intercalado
      final category = await SeriesAnimeCategoryService.getCategoryById(widget.categoryId);
      _categoryType = category?.type;
      
      // Obtener el atraso para resaltar visualmente
      final delayInfo = await SeriesAnimeCategoryService.calculateRealDelay(widget.categoryId);
      final chaptersBehind = delayInfo['chaptersBehind'] ?? 0;
      
      final episodes = await EpisodeLogService.getEpisodesByCategory(widget.categoryId);
      setState(() {
        _allEpisodes = episodes;
        _chaptersBehind = chaptersBehind;
        // Intercalar TODOS los episodios una sola vez (vistos + pendientes)
        _allEpisodesIntercalated = (_categoryType == 'lectura')
            ? _intercalateByVolumes(episodes)
            : _intercalateEpisodes(episodes);
        // En Lectura NO rotamos: se debe completar el tomo antes de pasar a la siguiente serie.
        // Solo aplicamos la rotación round-robin en Video.
        final shouldRotate = _categoryType != 'lectura';
        if (shouldRotate && _lastServedSeriesId != null && _allEpisodesIntercalated.isNotEmpty) {
          _allEpisodesIntercalated = _rotateStartByNextSeries(_allEpisodesIntercalated, _lastServedSeriesId!);
        }
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar episodios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      // Mostrar todos los episodios intercalados (vistos + pendientes)
      _filteredEpisodes = _allEpisodesIntercalated;
    } else if (_selectedFilter == 'pending') {
      // Filtrar solo pendientes, pero manteniendo el orden relativo de la lista intercalada completa
      _filteredEpisodes = _allEpisodesIntercalated.where((e) => 
        e.status == EpisodeStatus.noVisto || e.status == EpisodeStatus.parcialmenteVisto
      ).toList();
    } else if (_selectedFilter == 'watched') {
      // Filtrar solo vistos, manteniendo el orden relativo de la lista intercalada completa
      _filteredEpisodes = _allEpisodesIntercalated.where((e) => 
        e.status == EpisodeStatus.visto
      ).toList();
    } else {
      _filteredEpisodes = _allEpisodesIntercalated;
    }
  }

  // Método para intercalar episodios de diferentes series
  // Este método mantiene el orden round-robin dinámico basado en los episodios disponibles
  List<EpisodeLogEntry> _intercalateEpisodes(List<EpisodeLogEntry> episodes) {
    if (episodes.isEmpty) return episodes;

    // Agrupar episodios por serie ID
    final Map<int, List<EpisodeLogEntry>> seriesGroups = {};
    final Map<int, int> seriesOrderMap = {};
    
    for (final episode in episodes) {
      final seriesId = episode.seriesId;
      if (!seriesGroups.containsKey(seriesId)) {
        seriesGroups[seriesId] = [];
        seriesOrderMap[seriesId] = episode.seriesDisplayOrder;
      }
      seriesGroups[seriesId]!.add(episode);
    }

    // Ordenar las series por display_order
    final sortedSeriesIds = seriesGroups.keys.toList()
      ..sort((a, b) {
        final orderA = seriesOrderMap[a] ?? 0;
        final orderB = seriesOrderMap[b] ?? 0;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        return a.compareTo(b);
      });
    
    // Obtener listas de episodios por serie, ordenadas por temporada y episodio
    final List<List<EpisodeLogEntry>> seriesLists = sortedSeriesIds.map((seriesId) {
      final list = List<EpisodeLogEntry>.from(seriesGroups[seriesId]!);
      list.sort((a, b) {
        final seasonCmp = a.seasonNumber.compareTo(b.seasonNumber);
        if (seasonCmp != 0) return seasonCmp;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });
      return list;
    }).toList();
    
    // Intercalar episodios: un capítulo de cada serie en orden round-robin
    // Este algoritmo mantiene la coherencia dinámica: siempre toma el siguiente disponible de cada serie
    final List<EpisodeLogEntry> intercalatedEpisodes = [];
    
    if (seriesLists.isEmpty) return episodes;
    
    // Encontrar la longitud máxima entre todas las series
    int maxLength = 0;
    for (final list in seriesLists) {
      if (list.length > maxLength) {
        maxLength = list.length;
      }
    }
    
    // Intercalar episodios en orden round-robin dinámico
    // Esto asegura que si una serie tiene menos episodios, simplemente se omita en esa ronda
    for (int i = 0; i < maxLength; i++) {
      for (final seriesList in seriesLists) {
        if (i < seriesList.length) {
          intercalatedEpisodes.add(seriesList[i]);
        }
      }
    }

    return intercalatedEpisodes;
  }

  // Intercalar por tomos (lectura): todos los capítulos de un tomo, luego el siguiente tomo de la siguiente serie
  List<EpisodeLogEntry> _intercalateByVolumes(List<EpisodeLogEntry> episodes) {
    if (episodes.isEmpty) return episodes;

    // Agrupar por serie
    final Map<int, List<EpisodeLogEntry>> seriesGroups = {};
    final Map<int, int> seriesOrderMap = {};
    for (final e in episodes) {
      if (!seriesGroups.containsKey(e.seriesId)) {
        seriesGroups[e.seriesId] = [];
        seriesOrderMap[e.seriesId] = e.seriesDisplayOrder;
      }
      seriesGroups[e.seriesId]!.add(e);
    }

    // Ordenar por temporada y capítulo dentro de cada serie
    for (final list in seriesGroups.values) {
      list.sort((a, b) {
        final s = a.seasonNumber.compareTo(b.seasonNumber);
        if (s != 0) return s;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });
    }

    // Agrupar por temporada (tomo) y preservar orden
    final Map<int, List<List<EpisodeLogEntry>>> seriesToVolumes = {};
    for (final entry in seriesGroups.entries) {
      final Map<int, List<EpisodeLogEntry>> bySeason = {};
      for (final ep in entry.value) {
        bySeason.putIfAbsent(ep.seasonNumber, () => []).add(ep);
      }
      final seasonNums = bySeason.keys.toList()..sort();
      seriesToVolumes[entry.key] = seasonNums.map((sn) => bySeason[sn]!).toList();
    }

    // Ordenar series por display_order, luego ID
    final sortedSeriesIds = seriesToVolumes.keys.toList()
      ..sort((a, b) {
        final oa = seriesOrderMap[a] ?? 0;
        final ob = seriesOrderMap[b] ?? 0;
        if (oa != ob) return oa.compareTo(ob);
        return a.compareTo(b);
      });

    // Round-robin por tomo
    final List<EpisodeLogEntry> result = [];
    int round = 0;
    while (true) {
      bool added = false;
      for (final seriesId in sortedSeriesIds) {
        final vols = seriesToVolumes[seriesId]!;
        if (round < vols.length) {
          result.addAll(vols[round]);
          added = true;
        }
      }
      if (!added) break;
      round++;
    }

    return result;
  }

  Future<void> _toggleWatchedStatus(EpisodeLogEntry entry) async {
    try {
      // Recordar la serie que acaba de consumirse
      _lastServedSeriesId = entry.seriesId;
      final result = await EpisodeLogService.toggleEpisodeWatchedStatus(
        entry.episodeId, 
        entry.status != EpisodeStatus.visto
      );
      
      final isLastEpisode = result['isLastEpisode'] as bool;
      final seriesId = result['seriesId'] as int?;
      
      _loadEpisodes(); // Recargar para actualizar la UI y los contadores
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Episodio "${entry.formattedEpisode}" marcado como ${entry.status != EpisodeStatus.visto ? 'visto' : 'no visto'}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Si es el último episodio, mostrar diálogo para cambiar estado de la serie
      if (isLastEpisode && seriesId != null && entry.status != EpisodeStatus.visto) {
        await _showSeriesCompletionDialog(seriesId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar episodio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Rotar la lista para que comience con la serie siguiente a lastServedSeriesId
  List<EpisodeLogEntry> _rotateStartByNextSeries(List<EpisodeLogEntry> list, int lastSeriesId) {
    if (list.isEmpty) return list;

    // Obtener orden de series según la aparición en lista (ya respeta display_order)
    final orderedSeries = <int>[];
    for (final e in list) {
      if (!orderedSeries.contains(e.seriesId)) orderedSeries.add(e.seriesId);
    }
    final idx = orderedSeries.indexOf(lastSeriesId);
    if (idx == -1) return list;
    final nextSeriesId = orderedSeries[(idx + 1) % orderedSeries.length];

    // Buscar primer índice en la lista que pertenezca a esa serie
    final startIndex = list.indexWhere((e) => e.seriesId == nextSeriesId);
    if (startIndex <= 0) return list; // ya comienza con la serie deseada o no encontrada

    // Rotar manteniendo el orden relativo
    return [...list.sublist(startIndex), ...list.sublist(0, startIndex)];
  }

  Future<void> _showSeriesCompletionDialog(int seriesId) async {
    final series = await SeriesService.getSeriesById(seriesId);
    if (series == null || !mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('¡Serie completada!'),
        content: Text(
          'Has terminado de ver todos los episodios de "${series.name}".\n\n'
          '¿Qué deseas hacer con esta serie?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('waiting'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause_circle, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('En Espera'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('finished'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Terminada', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        SeriesStatus newStatus;
        if (result == 'waiting') {
          newStatus = SeriesStatus.enEspera;
        } else {
          newStatus = SeriesStatus.terminada;
          // Marcar fecha de finalización
        }

        // Obtener el último episodio visto para actualizar el progreso final
        final lastWatched = await SeriesService.getLastWatchedEpisode(seriesId);
        
        final updatedSeries = series.copyWith(
          status: newStatus,
          finishWatchingDate: result == 'finished' ? DateTime.now() : series.finishWatchingDate,
          // Actualizar currentSeason y currentEpisode al último visto
          currentSeason: lastWatched?['season'] ?? series.currentSeason,
          currentEpisode: lastWatched?['episode'] ?? series.currentEpisode,
          updatedAt: DateTime.now(),
        );

        await SeriesService.updateSeries(updatedSeries);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Serie "${series.name}" movida a ${newStatus.displayName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar estado de la serie: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Registro - ${widget.categoryName}'),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
            tooltip: _isEditMode ? 'Finalizar edición' : 'Editar orden',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<Map<String, int>>(
              future: EpisodeLogService.getEpisodeStatistics(widget.categoryId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final stats = snapshot.data ?? {'total': 0, 'watched': 0, 'pending': 0};
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Total', stats['total']!),
                    _buildStatCard('Vistos', stats['watched']!),
                    _buildStatCard('Pendientes', stats['pending']!),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Todos'), icon: Icon(Icons.list)),
                ButtonSegment(value: 'pending', label: Text('Pendientes'), icon: Icon(Icons.watch_later)),
                ButtonSegment(value: 'watched', label: Text('Vistos'), icon: Icon(Icons.check_circle)),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFilter = newSelection.first;
                  _applyFilter();
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEpisodes.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == 'all'
                              ? 'No hay episodios registrados.'
                              : _selectedFilter == 'pending'
                                  ? 'No hay episodios pendientes.'
                                  : 'No hay episodios vistos.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : _isEditMode
                        ? ReorderableListView.builder(
                            itemCount: _filteredEpisodes.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final item = _filteredEpisodes.removeAt(oldIndex);
                                _filteredEpisodes.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              final episode = _filteredEpisodes[index];
                              final isBehind = _isEpisodeBehind(episode, index);
                              return Card(
                                key: ValueKey(episode.episodeId),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: isBehind ? Colors.orange.withOpacity(0.2) : null,
                                child: ListTile(
                                  leading: Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey,
                                  ),
                                  title: Text(
                                    episode.formattedEpisode,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Categoría: ${episode.categoryName}',
                                  ),
                                  trailing: Icon(
                                    episode.statusIcon,
                                    color: episode.statusColor,
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.builder(
                            itemCount: _filteredEpisodes.length,
                            itemBuilder: (context, index) {
                              final episode = _filteredEpisodes[index];
                              final isBehind = _isEpisodeBehind(episode, index);
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: isBehind ? Colors.orange.withOpacity(0.2) : null,
                                child: ListTile(
                                  leading: Icon(
                                    episode.statusIcon,
                                    color: episode.statusColor,
                                  ),
                                  title: Text(
                                    episode.formattedEpisode,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Categoría: ${episode.categoryName}',
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      episode.status == EpisodeStatus.visto ? Icons.undo : Icons.check,
                                      color: episode.status == EpisodeStatus.visto ? Colors.orange : Colors.green,
                                    ),
                                    onPressed: () => _toggleWatchedStatus(episode),
                                  ),
                                  onTap: () => _toggleWatchedStatus(episode),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Determinar si un episodio está atrasado (para resaltar visualmente)
  bool _isEpisodeBehind(EpisodeLogEntry episode, int index) {
    // Solo resaltar si hay atraso y el episodio está pendiente
    if (_chaptersBehind <= 0 || episode.isWatched) {
      return false;
    }

    if (_categoryType == 'lectura') {
      // Para Lectura: resaltar todos los capítulos de los primeros N tomos pendientes
      // Necesitamos obtener la lista de tomos pendientes ordenados
      final pendingEpisodes = _filteredEpisodes.where((e) => e.isPending).toList();
      
      // Agrupar por serie y tomo (seasonNumber)
      final Map<String, List<EpisodeLogEntry>> tomoMap = {};
      for (final ep in pendingEpisodes) {
        final key = '${ep.seriesId}_${ep.seasonNumber}';
        if (!tomoMap.containsKey(key)) {
          tomoMap[key] = [];
        }
        tomoMap[key]!.add(ep);
      }
      
      // Ordenar los tomos por orden de visualización y número de tomo
      final sortedTomos = tomoMap.entries.toList()
        ..sort((a, b) {
          final aFirst = a.value.first;
          final bFirst = b.value.first;
          if (aFirst.seriesDisplayOrder != bFirst.seriesDisplayOrder) {
            return aFirst.seriesDisplayOrder.compareTo(bFirst.seriesDisplayOrder);
          }
          return aFirst.seasonNumber.compareTo(bFirst.seasonNumber);
        });
      
      // Verificar si este episodio pertenece a uno de los primeros N tomos
      int tomoIndex = 0;
      for (final tomoEntry in sortedTomos) {
        if (tomoIndex >= _chaptersBehind) break;
        
        final tomoEpisodes = tomoEntry.value;
        if (tomoEpisodes.any((e) => e.episodeId == episode.episodeId)) {
          return true;
        }
        tomoIndex++;
      }
      
      return false;
    } else {
      // Para Video: resaltar los primeros N episodios pendientes
      final pendingEpisodes = _filteredEpisodes.where((e) => e.isPending).toList();
      final episodeIndex = pendingEpisodes.indexWhere((e) => e.episodeId == episode.episodeId);
      return episodeIndex >= 0 && episodeIndex < _chaptersBehind;
    }
  }
}