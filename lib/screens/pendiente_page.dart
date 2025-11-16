import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pending_item.dart';
import '../services/pending_item_service.dart';
import '../widgets/pending_item_dialog.dart';

class PendientePage extends StatefulWidget {
  const PendientePage({super.key});

  @override
  State<PendientePage> createState() => _PendientePageState();
}

class _PendientePageState extends State<PendientePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PendingItemType _selectedType = PendingItemType.pelicula;
  PendingItemStatus? _selectedStatus;
  String _orderBy = 'title';
  bool _ascending = true;
  bool _showHistory = false;

  List<PendingItem> _items = [];
  Map<String, int> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedType = PendingItemType.values[_tabController.index];
          _loadData();
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Funciones helper para obtener icono y color según el tipo
  IconData _getTypeIcon(PendingItemType type) {
    switch (type) {
      case PendingItemType.pelicula:
        return Icons.movie;
      case PendingItemType.serie:
        return Icons.tv;
      case PendingItemType.anime:
        return Icons.animation;
    }
  }

  Color _getTypeColor(PendingItemType type) {
    switch (type) {
      case PendingItemType.pelicula:
        return Colors.purple;
      case PendingItemType.serie:
        return Colors.blue;
      case PendingItemType.anime:
        return Colors.pink;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar items ordenados
      final items = await PendingItemService.getPendingItemsOrdered(
        type: _selectedType,
        status: _showHistory ? PendingItemStatus.visto : _selectedStatus,
        orderBy: _orderBy,
        ascending: _ascending,
      );

      // Cargar estadísticas
      final stats = await PendingItemService.getStatisticsByType(_selectedType);

      setState(() {
        _items = items;
        _statistics = stats;
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

  Future<void> _showAddItemDialog() async {
    final result = await showDialog<PendingItem>(
      context: context,
      builder: (context) => PendingItemDialog(initialType: _selectedType),
    );

    if (result != null) {
      try {
        await PendingItemService.createPendingItem(result);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al agregar item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditItemDialog(PendingItem item) async {
    final result = await showDialog<PendingItem>(
      context: context,
      builder: (context) => PendingItemDialog(item: item),
    );

    if (result != null) {
      try {
        await PendingItemService.updatePendingItem(result);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item actualizado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al actualizar item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(PendingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Item'),
        content: Text('¿Estás seguro de que quieres eliminar "${item.title}"?'),
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
        await PendingItemService.deletePendingItem(item.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item eliminado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordenar por'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opciones de ordenamiento
            RadioListTile<String>(
              title: const Text('Nombre'),
              value: 'title',
              groupValue: _orderBy,
              onChanged: (value) {
                setState(() {
                  _orderBy = value!;
                });
                Navigator.of(context).pop();
                _loadData();
              },
            ),
            RadioListTile<String>(
              title: const Text('Fecha de creación'),
              value: 'created_at',
              groupValue: _orderBy,
              onChanged: (value) {
                setState(() {
                  _orderBy = value!;
                });
                Navigator.of(context).pop();
                _loadData();
              },
            ),
            RadioListTile<String>(
              title: const Text('Año'),
              value: 'year',
              groupValue: _orderBy,
              onChanged: (value) {
                setState(() {
                  _orderBy = value!;
                });
                Navigator.of(context).pop();
                _loadData();
              },
            ),
            if (_selectedType != PendingItemType.pelicula)
              RadioListTile<String>(
                title: const Text('Año de inicio'),
                value: 'start_year',
                groupValue: _orderBy,
                onChanged: (value) {
                  setState(() {
                    _orderBy = value!;
                  });
                  Navigator.of(context).pop();
                  _loadData();
                },
              ),
            if (_selectedType != PendingItemType.pelicula)
              RadioListTile<String>(
                title: const Text('Año de terminación'),
                value: 'end_year',
                groupValue: _orderBy,
                onChanged: (value) {
                  setState(() {
                    _orderBy = value!;
                  });
                  Navigator.of(context).pop();
                  _loadData();
                },
              ),
            RadioListTile<String>(
              title: const Text('Fecha de visualización'),
              value: 'watched_date',
              groupValue: _orderBy,
              onChanged: (value) {
                setState(() {
                  _orderBy = value!;
                });
                Navigator.of(context).pop();
                _loadData();
              },
            ),
            const Divider(),
            // Dirección de ordenamiento
            SwitchListTile(
              title: const Text('Ascendente'),
              value: _ascending,
              onChanged: (value) {
                setState(() {
                  _ascending = value;
                });
                Navigator.of(context).pop();
                _loadData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Total', _statistics['total'] ?? 0, Colors.grey),
            _buildStatItem('Pendiente', _statistics['pendiente'] ?? 0, Colors.grey),
            _buildStatItem('Mirando', _statistics['mirando'] ?? 0, Colors.blue),
            _buildStatItem('Visto', _statistics['visto'] ?? 0, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              'Todos',
              null,
              Icons.list,
              _selectedStatus == null && !_showHistory,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'Pendiente',
              PendingItemStatus.pendiente,
              Icons.pending,
              _selectedStatus == PendingItemStatus.pendiente,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'Mirando',
              PendingItemStatus.mirando,
              Icons.play_circle,
              _selectedStatus == PendingItemStatus.mirando,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              'Historial',
              null,
              Icons.history,
              _showHistory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, PendingItemStatus? status, IconData icon, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          if (label == 'Historial') {
            _showHistory = selected;
            _selectedStatus = null;
          } else {
            _showHistory = false;
            _selectedStatus = status;
          }
        });
        _loadData();
      },
    );
  }

  Widget _buildItemsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTypeIcon(_selectedType),
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _showHistory
                  ? 'No hay items vistos'
                  : 'No hay items registrados',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega un nuevo item para comenzar',
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
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.typeColor.withValues(alpha: 0.1),
              child: Icon(
                item.typeIcon,
                color: item.typeColor,
              ),
            ),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.dateInfo),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      item.statusIcon,
                      size: 16,
                      color: item.statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (item.watchedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Visto: ${DateFormat('dd/MM/yyyy').format(item.watchedDate!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditItemDialog(item);
                } else if (value == 'delete') {
                  _deleteItem(item);
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
        title: const Text('Pendiente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: 'Ordenar',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Regresar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.movie),
              text: 'Películas',
            ),
            Tab(
              icon: Icon(Icons.tv),
              text: 'Series',
            ),
            Tab(
              icon: Icon(Icons.animation),
              text: 'Anime',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Estadísticas
          _buildStatisticsCard(),
          const SizedBox(height: 8),
          // Filtros
          _buildFilterChips(),
          const SizedBox(height: 16),
          // Lista de items
          Expanded(
            child: _buildItemsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
        tooltip: 'Agregar ${_selectedType.displayName}',
      ),
    );
  }
}

