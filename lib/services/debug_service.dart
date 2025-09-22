import 'database_service.dart';

class DebugService {
  /// Ver todos los usuarios en la base de datos
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> users = await db.query('users');
    return users;
  }

  /// Ver todas las tablas en la base de datos
  static Future<List<String>> getAllTables() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
    );
    return tables.map((table) => table['name'] as String).toList();
  }

  /// Ver el contenido de cualquier tabla
  static Future<List<Map<String, dynamic>>> getTableContent(String tableName) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> content = await db.query(tableName);
    return content;
  }

  /// Ver estadísticas de la base de datos
  static Future<Map<String, int>> getDatabaseStats() async {
    final db = await DatabaseService.database;
    
    final stats = <String, int>{};
    
    // Contar usuarios
    final usersResult = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    stats['users'] = usersResult.first['count'] as int;
    
    // Contar categorías
    final categoriesResult = await db.rawQuery('SELECT COUNT(*) as count FROM categories');
    stats['categories'] = categoriesResult.first['count'] as int;
    
    // Contar transacciones
    final transactionsResult = await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    stats['transactions'] = transactionsResult.first['count'] as int;
    
    // Contar deudas y préstamos
    final debtsResult = await db.rawQuery('SELECT COUNT(*) as count FROM debts_loans');
    stats['debts_loans'] = debtsResult.first['count'] as int;
    
    // Contar categorías de series/anime
    final seriesCategoriesResult = await db.rawQuery('SELECT COUNT(*) as count FROM series_anime_categories');
    stats['series_anime_categories'] = seriesCategoriesResult.first['count'] as int;
    
    // Contar registros de video
    final videoTrackingResult = await db.rawQuery('SELECT COUNT(*) as count FROM video_tracking');
    stats['video_tracking'] = videoTrackingResult.first['count'] as int;
    
    return stats;
  }

  /// Imprimir información de debug en consola
  static Future<void> printDebugInfo() async {
    print('=== INFORMACIÓN DE DEBUG DE LA BASE DE DATOS ===');
    
    // Mostrar tablas
    final tables = await getAllTables();
    print('\n📋 Tablas en la base de datos:');
    for (final table in tables) {
      print('  - $table');
    }
    
    // Mostrar estadísticas
    final stats = await getDatabaseStats();
    print('\n📊 Estadísticas:');
    stats.forEach((key, value) {
      print('  - $key: $value registros');
    });
    
    // Mostrar usuarios
    final users = await getAllUsers();
    print('\n👥 Usuarios registrados:');
    if (users.isEmpty) {
      print('  No hay usuarios registrados');
    } else {
      for (final user in users) {
        print('  - ID: ${user['id']}');
        print('    Username: ${user['username']}');
        print('    Email: ${user['email'] ?? 'No especificado'}');
        print('    Creado: ${user['created_at']}');
        print('    ---');
      }
    }
    
    print('\n=== FIN DE INFORMACIÓN DE DEBUG ===');
  }
}
