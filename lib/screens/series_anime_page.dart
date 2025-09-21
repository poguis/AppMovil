import 'package:flutter/material.dart';
import '../models/series_anime_category.dart';
import '../models/video_tracking.dart';
import '../services/series_anime_category_service.dart';
import '../services/video_tracking_service.dart';
import '../widgets/series_anime_category_dialog.dart';
import '../widgets/video_tracking_dialog.dart';

class SeriesAnimePage extends StatefulWidget {
  const SeriesAnimePage({super.key});

  @override
  State<SeriesAnimePage> createState() => _SeriesAnimePageState();
}

class _SeriesAnimePageState extends State<SeriesAnimePage> {
  List<SeriesAnimeCategory> _categories = [];
  List<VideoTracking> _videoTracking = [];
  bool _isLoading = true;
  String _selectedType = 'all'; // 'all', 'video', 'lectura'
  String _currentView = 'categories'; // 'categories', 'video_tracking'

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
      final categories = await SeriesAnimeCategoryService.getAllCategories();
      final videoTracking = await VideoTrackingService.getAllVideoTracking();
      setState(() {
        _categories = categories;
        _videoTracking = videoTracking;
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

  Future<void> _loadCategories() async {
    try {
      final categories = await SeriesAnimeCategoryService.getAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar categorías: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadVideoTracking() async {
    try {
      final videoTracking = await VideoTrackingService.getAllVideoTracking();
      setState(() {
        _videoTracking = videoTracking;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar registros de video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddCategoryDialog({String? type}) async {
    final result = await showDialog<SeriesAnimeCategory>(
      context: context,
      builder: (context) => SeriesAnimeCategoryDialog(initialType: type),
    );

    if (result != null) {
      try {
        await SeriesAnimeCategoryService.createCategory(result);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría agregada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar categoría: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditCategoryDialog(SeriesAnimeCategory category) async {
    final result = await showDialog<SeriesAnimeCategory>(
      context: context,
      builder: (context) => SeriesAnimeCategoryDialog(category: category),
    );

    if (result != null) {
      try {
        await SeriesAnimeCategoryService.updateCategory(result);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar categoría: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(SeriesAnimeCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de que quieres eliminar la categoría "${category.name}"?'),
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
        await SeriesAnimeCategoryService.deleteCategory(category.id!);
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría eliminada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar categoría: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showAddVideoTrackingDialog() async {
    final videoCategories = _categories.where((cat) => cat.type == 'video').toList();
    if (videoCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea una categoría de video'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<VideoTracking>(
      context: context,
      builder: (context) => VideoTrackingDialog(
        categories: videoCategories,
      ),
    );

    if (result != null) {
      try {
        await VideoTrackingService.createVideoTracking(result);
        _loadVideoTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro de video agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar registro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditVideoTrackingDialog(VideoTracking tracking) async {
    final videoCategories = _categories.where((cat) => cat.type == 'video').toList();
    final result = await showDialog<VideoTracking>(
      context: context,
      builder: (context) => VideoTrackingDialog(
        tracking: tracking,
        categories: videoCategories,
      ),
    );

    if (result != null) {
      try {
        await VideoTrackingService.updateVideoTracking(result);
        _loadVideoTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro de video actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar registro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteVideoTracking(VideoTracking tracking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Registro'),
        content: Text('¿Estás seguro de que quieres eliminar el registro "${tracking.name}"?'),
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
        await VideoTrackingService.deleteVideoTracking(tracking.id!);
        _loadVideoTracking();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registro eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar registro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<SeriesAnimeCategory> get _filteredCategories {
    if (_selectedType == 'all') return _categories;
    return _categories.where((cat) => cat.type == _selectedType).toList();
  }

  List<VideoTracking> get _filteredVideoTracking {
    if (_selectedType == 'all') return _videoTracking;
    // Filtrar por categorías del tipo seleccionado
    final categoryIds = _categories
        .where((cat) => cat.type == _selectedType)
        .map((cat) => cat.id)
        .toList();
    return _videoTracking.where((tracking) => categoryIds.contains(tracking.categoryId)).toList();
  }

  Widget _buildCategoriesView() {
    if (_filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedType == 'video' 
                  ? Icons.play_circle_outline
                  : _selectedType == 'lectura'
                      ? Icons.menu_book
                      : Icons.category,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedType == 'all'
                  ? 'No hay categorías registradas'
                  : _selectedType == 'video'
                      ? 'No hay categorías de video'
                      : 'No hay categorías de lectura',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega una nueva categoría para comenzar',
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
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        final category = _filteredCategories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: category.type == 'video'
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              child: Icon(
                category.type == 'video'
                    ? Icons.play_circle_outline
                    : Icons.menu_book,
                color: category.type == 'video'
                    ? Colors.blue
                    : Colors.green,
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: category.description != null
                ? Text(category.description!)
                : Text(
                    category.type == 'video' ? 'Video' : 'Lectura',
                    style: TextStyle(
                      color: category.type == 'video'
                          ? Colors.blue
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditCategoryDialog(category);
                } else if (value == 'delete') {
                  _deleteCategory(category);
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
          ),
        );
      },
    );
  }

  Widget _buildVideoTrackingView() {
    if (_filteredVideoTracking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedType == 'all'
                  ? 'No hay registros de video'
                  : _selectedType == 'video'
                      ? 'No hay registros de video'
                      : 'No hay registros de lectura',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega un nuevo registro para comenzar',
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
      itemCount: _filteredVideoTracking.length,
      itemBuilder: (context, index) {
        final tracking = _filteredVideoTracking[index];
        final category = _categories.firstWhere(
          (cat) => cat.id == tracking.categoryId,
          orElse: () => SeriesAnimeCategory(
            name: 'Categoría eliminada',
            type: 'video',
            createdAt: DateTime.now(),
          ),
        );
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.blue,
              ),
            ),
            title: Text(
              tracking.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categoría: ${category.name}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Inicio: ${tracking.startDate.day}/${tracking.startDate.month}/${tracking.startDate.year}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Días: ${tracking.selectedDayNames.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Frecuencia: ${tracking.frequencySummary}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditVideoTrackingDialog(tracking);
                } else if (value == 'delete') {
                  _deleteVideoTracking(tracking);
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Serie/Anime'),
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
          // Selector de vista
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'categories',
                        label: Text('Categorías'),
                        icon: Icon(Icons.category),
                      ),
                      ButtonSegment(
                        value: 'video_tracking',
                        label: Text('Registros'),
                        icon: Icon(Icons.video_library),
                      ),
                    ],
                    selected: {_currentView},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _currentView = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Filtros de tipo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('Todas'),
                        icon: Icon(Icons.list),
                      ),
                      ButtonSegment(
                        value: 'video',
                        label: Text('Video'),
                        icon: Icon(Icons.play_circle_outline),
                      ),
                      ButtonSegment(
                        value: 'lectura',
                        label: Text('Lectura'),
                        icon: Icon(Icons.menu_book),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _selectedType = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentView == 'categories'
                    ? _buildCategoriesView()
                    : _buildVideoTrackingView(),
          ),
        ],
      ),
      floatingActionButton: _currentView == 'categories'
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón para agregar categoría de lectura
                FloatingActionButton(
                  heroTag: 'add_lectura',
                  onPressed: () => _showAddCategoryDialog(type: 'lectura'),
                  mini: true,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.menu_book, color: Colors.white),
                  tooltip: 'Agregar categoría de lectura',
                ),
                const SizedBox(height: 8),
                // Botón para agregar categoría de video
                FloatingActionButton(
                  heroTag: 'add_video',
                  onPressed: () => _showAddCategoryDialog(type: 'video'),
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.play_circle_outline, color: Colors.white),
                  tooltip: 'Agregar categoría de video',
                ),
                const SizedBox(height: 8),
                // Botón principal para agregar cualquier categoría
                FloatingActionButton(
                  heroTag: 'add_category',
                  onPressed: () => _showAddCategoryDialog(),
                  child: const Icon(Icons.add),
                  tooltip: 'Agregar categoría',
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: _showAddVideoTrackingDialog,
              child: const Icon(Icons.video_library),
              tooltip: 'Agregar registro de video',
            ),
    );
  }
}
