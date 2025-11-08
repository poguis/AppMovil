import '../models/pending_item.dart';
import 'database_service.dart';

class PendingItemService {
  static const String _tableName = 'pending_items';

  /// Crear un nuevo item pendiente
  static Future<int> createPendingItem(PendingItem item) async {
    final db = await DatabaseService.database;
    
    // Si el estado es "visto" y no tiene fecha de visualización, asignarla
    PendingItem itemToCreate = item;
    if (item.status == PendingItemStatus.visto && item.watchedDate == null) {
      itemToCreate = item.copyWith(watchedDate: DateTime.now());
    }
    
    return await db.insert(_tableName, itemToCreate.toMap());
  }

  /// Obtener todos los items pendientes
  static Future<List<PendingItem>> getAllPendingItems() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }

  /// Obtener items por tipo
  static Future<List<PendingItem>> getPendingItemsByType(PendingItemType type) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }

  /// Obtener items por estado
  static Future<List<PendingItem>> getPendingItemsByStatus(PendingItemStatus status) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }

  /// Obtener items por tipo y estado
  static Future<List<PendingItem>> getPendingItemsByTypeAndStatus(
    PendingItemType type,
    PendingItemStatus? status,
  ) async {
    final db = await DatabaseService.database;
    
    String whereClause = 'type = ?';
    List<dynamic> whereArgs = [type.name];
    
    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status.name);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }

  /// Obtener un item por ID
  static Future<PendingItem?> getPendingItemById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PendingItem.fromMap(maps.first);
    }
    return null;
  }

  /// Actualizar un item pendiente
  static Future<int> updatePendingItem(PendingItem item) async {
    final db = await DatabaseService.database;
    
    // Obtener el item anterior para comparar estados
    final previousItem = await getPendingItemById(item.id!);
    
    PendingItem updatedItem = item;
    
    // Si el estado es "visto" y no tiene fecha, asignarla
    if (item.status == PendingItemStatus.visto) {
      if (item.watchedDate == null) {
        updatedItem = item.copyWith(
          watchedDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        updatedItem = item.copyWith(updatedAt: DateTime.now());
      }
    } else {
      // Si el estado cambia de "visto" a otro, limpiar la fecha si no está ya limpiada
      if (previousItem?.status == PendingItemStatus.visto && item.watchedDate != null) {
        updatedItem = item.copyWith(
          watchedDate: null,
          updatedAt: DateTime.now(),
        );
      } else {
        updatedItem = item.copyWith(updatedAt: DateTime.now());
      }
    }
    
    return await db.update(
      _tableName,
      updatedItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Eliminar un item pendiente
  static Future<int> deletePendingItem(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtener items ordenados
  static Future<List<PendingItem>> getPendingItemsOrdered({
    required PendingItemType type,
    PendingItemStatus? status,
    String orderBy = 'title',
    bool ascending = true,
  }) async {
    final db = await DatabaseService.database;
    
    String whereClause = 'type = ?';
    List<dynamic> whereArgs = [type.name];
    
    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status.name);
    }
    
    // Validar orderBy
    final validOrderBy = ['title', 'created_at', 'year', 'start_date', 'end_date', 'watched_date'];
    final orderByColumn = validOrderBy.contains(orderBy) ? orderBy : 'title';
    final orderDirection = ascending ? 'ASC' : 'DESC';
    
    // Para campos que pueden ser NULL, usar una expresión que maneje NULLs
    // SQLite ordena NULLs al final por defecto en ASC y al inicio en DESC
    // Para consistencia, siempre ponemos NULLs al final usando una subexpresión
    String orderByClause;
    if (orderByColumn == 'year') {
      // Para año, usar un valor grande para NULLs (siempre al final)
      orderByClause = ascending 
          ? 'CASE WHEN $orderByColumn IS NULL THEN 1 ELSE 0 END ASC, $orderByColumn $orderDirection'
          : 'CASE WHEN $orderByColumn IS NULL THEN 1 ELSE 0 END ASC, $orderByColumn $orderDirection';
    } else if (orderByColumn == 'start_date' || orderByColumn == 'end_date' || orderByColumn == 'watched_date') {
      // Para fechas, usar una fecha muy lejana para NULLs (siempre al final)
      orderByClause = ascending 
          ? 'CASE WHEN $orderByColumn IS NULL THEN 1 ELSE 0 END ASC, $orderByColumn $orderDirection'
          : 'CASE WHEN $orderByColumn IS NULL THEN 1 ELSE 0 END ASC, $orderByColumn $orderDirection';
    } else {
      orderByClause = '$orderByColumn $orderDirection';
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: orderByClause,
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }

  /// Obtener estadísticas por tipo
  static Future<Map<String, int>> getStatisticsByType(PendingItemType type) async {
    final db = await DatabaseService.database;
    
    // Total
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ?',
      [type.name],
    );
    final total = totalResult.first['count'] as int;
    
    // Pendientes
    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ? AND status = ?',
      [type.name, PendingItemStatus.pendiente.name],
    );
    final pending = pendingResult.first['count'] as int;
    
    // Mirando
    final mirandoResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ? AND status = ?',
      [type.name, PendingItemStatus.mirando.name],
    );
    final mirando = mirandoResult.first['count'] as int;
    
    // Vistos
    final vistoResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ? AND status = ?',
      [type.name, PendingItemStatus.visto.name],
    );
    final visto = vistoResult.first['count'] as int;
    
    return {
      'total': total,
      'pendiente': pending,
      'mirando': mirando,
      'visto': visto,
    };
  }

  /// Buscar items por título
  static Future<List<PendingItem>> searchPendingItems(String query, {PendingItemType? type}) async {
    final db = await DatabaseService.database;
    
    String whereClause = 'title LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];
    
    if (type != null) {
      whereClause = 'type = ? AND $whereClause';
      whereArgs.insert(0, type.name);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'title ASC',
    );
    return List.generate(maps.length, (i) => PendingItem.fromMap(maps[i]));
  }
}

