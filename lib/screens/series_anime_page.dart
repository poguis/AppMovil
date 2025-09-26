import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/series_anime_category.dart';
import '../models/video_tracking.dart';
import '../services/series_anime_category_service.dart';
import '../services/video_tracking_service.dart';
import '../widgets/series_anime_category_dialog.dart';
import '../widgets/video_tracking_dialog.dart';
import 'category_detail_page.dart';

class SeriesAnimePage extends StatefulWidget {
  const SeriesAnimePage({super.key});

  @override
  State<SeriesAnimePage> createState() => _SeriesAnimePageState();
}

class _SeriesAnimePageState extends State<SeriesAnimePage> {
  List<SeriesAnimeCategory> _categories = [];
  bool _isLoading = true;
  String _selectedType = 'all'; // 'all', 'video', 'lectura'

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
      setState(() {
        _categories = categories;
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


  List<SeriesAnimeCategory> get _filteredCategories {
    if (_selectedType == 'all') return _categories;
    return _categories.where((cat) => cat.type == _selectedType).toList();
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category.description != null)
                  Text(category.description!),
                const SizedBox(height: 4),
                Text(
                  'Inicio: ${DateFormat('dd/MM/yyyy').format(category.startDate)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Días: ${category.selectedDayNames.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Frecuencia: ${category.categorySummary}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: category.getDaysBehind() > 0 ? Colors.red.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category.getDaysBehind() > 0 
                        ? 'Atraso: ${category.getDaysBehind()} días (${category.getChaptersBehind()} capítulos)'
                        : category.getStatusMessage(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: category.getDaysBehind() > 0 ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryDetailPage(category: category),
                ),
              );
            },
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
                : _buildCategoriesView(),
          ),
        ],
      ),
      floatingActionButton: Column(
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
      ),
    );
  }
}
