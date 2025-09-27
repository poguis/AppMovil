import 'package:flutter/material.dart';
import '../models/episode_log_entry.dart';
import '../services/episode_log_service.dart';
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
  List<EpisodeLogEntry> _filteredEpisodes = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending'; // 'all', 'pending', 'watched'
  bool _isEditMode = false;

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
      final episodes = await EpisodeLogService.getEpisodesByCategory(widget.categoryId);
      setState(() {
        _allEpisodes = episodes;
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
      _filteredEpisodes = _allEpisodes;
    } else if (_selectedFilter == 'pending') {
      _filteredEpisodes = _allEpisodes.where((e) => e.status == EpisodeStatus.noVisto || e.status == EpisodeStatus.parcialmenteVisto).toList();
    } else if (_selectedFilter == 'watched') {
      _filteredEpisodes = _allEpisodes.where((e) => e.status == EpisodeStatus.visto).toList();
    }
    // Sort episodes for consistent display
    _filteredEpisodes.sort((a, b) {
      int seriesComparison = a.seriesName.compareTo(b.seriesName);
      if (seriesComparison != 0) return seriesComparison;
      int seasonComparison = a.seasonNumber.compareTo(b.seasonNumber);
      if (seasonComparison != 0) return seasonComparison;
      return a.episodeNumber.compareTo(b.episodeNumber);
    });
  }

  Future<void> _toggleWatchedStatus(EpisodeLogEntry entry) async {
    try {
      await EpisodeLogService.toggleEpisodeWatchedStatus(entry.episodeId, entry.status != EpisodeStatus.visto);
      _loadEpisodes(); // Recargar para actualizar la UI y los contadores
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Episodio "${entry.formattedEpisode}" marcado como ${entry.status != EpisodeStatus.visto ? 'visto' : 'no visto'}'),
            backgroundColor: Colors.green,
          ),
        );
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
                              return Card(
                                key: ValueKey(episode.episodeId),
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
}