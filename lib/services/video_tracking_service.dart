import '../models/video_tracking.dart';
import 'database_service.dart';

class VideoTrackingService {
  static const String _tableName = 'video_tracking';

  /// Crear un nuevo registro de video
  static Future<int> createVideoTracking(VideoTracking tracking) async {
    final db = await DatabaseService.database;
    return await db.insert(_tableName, tracking.toMap());
  }

  /// Obtener todos los registros de video
  static Future<List<VideoTracking>> getAllVideoTracking() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }

  /// Obtener registros de video por categoría
  static Future<List<VideoTracking>> getVideoTrackingByCategory(int categoryId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }

  /// Obtener un registro de video por ID
  static Future<VideoTracking?> getVideoTrackingById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return VideoTracking.fromMap(maps.first);
    }
    return null;
  }

  /// Actualizar un registro de video
  static Future<int> updateVideoTracking(VideoTracking tracking) async {
    final db = await DatabaseService.database;
    final updatedTracking = tracking.copyWith(updatedAt: DateTime.now());
    return await db.update(
      _tableName,
      updatedTracking.toMap(),
      where: 'id = ?',
      whereArgs: [tracking.id],
    );
  }

  /// Eliminar un registro de video
  static Future<int> deleteVideoTracking(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Verificar si existe un registro con el mismo nombre en la categoría
  static Future<bool> videoTrackingExists(String name, int categoryId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'name = ? AND category_id = ?',
      whereArgs: [name, categoryId],
    );
    return maps.isNotEmpty;
  }

  /// Obtener registros de video activos (que tienen días seleccionados)
  static Future<List<VideoTracking>> getActiveVideoTracking() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'selected_days != ?',
      whereArgs: [''],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }

  /// Obtener registros de video para un día específico de la semana
  static Future<List<VideoTracking>> getVideoTrackingForDay(int dayNumber) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'selected_days LIKE ?',
      whereArgs: ['%$dayNumber%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }

  /// Obtener estadísticas de registros de video
  static Future<Map<String, int>> getVideoTrackingStats() async {
    final db = await DatabaseService.database;
    
    // Contar total de registros
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final total = totalResult.first['count'] as int;
    
    // Contar registros activos (con días seleccionados)
    final activeResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE selected_days != ?',
      ['']
    );
    final active = activeResult.first['count'] as int;
    
    // Contar registros por categoría
    final categoryResult = await db.rawQuery(
      'SELECT category_id, COUNT(*) as count FROM $_tableName GROUP BY category_id'
    );
    
    return {
      'total': total,
      'active': active,
      'inactive': total - active,
    };
  }

  /// Obtener registros de video con información de categoría
  static Future<List<Map<String, dynamic>>> getVideoTrackingWithCategory() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        vt.*,
        sac.name as category_name,
        sac.type as category_type
      FROM $_tableName vt
      LEFT JOIN series_anime_categories sac ON vt.category_id = sac.id
      ORDER BY vt.created_at DESC
    ''');
    return maps;
  }

  /// Obtener registros de video para una categoría específica con información de categoría
  static Future<List<Map<String, dynamic>>> getVideoTrackingWithCategoryByCategoryId(int categoryId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        vt.*,
        sac.name as category_name,
        sac.type as category_type
      FROM $_tableName vt
      LEFT JOIN series_anime_categories sac ON vt.category_id = sac.id
      WHERE vt.category_id = ?
      ORDER BY vt.created_at DESC
    ''', [categoryId]);
    return maps;
  }

  /// Buscar registros de video por nombre
  static Future<List<VideoTracking>> searchVideoTracking(String query) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }

  /// Obtener registros de video que empiezan en una fecha específica
  static Future<List<VideoTracking>> getVideoTrackingByStartDate(DateTime date) async {
    final db = await DatabaseService.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'start_date >= ? AND start_date <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => VideoTracking.fromMap(maps[i]));
  }
}
