import '../models/series_anime_category.dart';
import '../models/series.dart';
import '../models/episode.dart';
import 'database_service.dart';
import 'series_service.dart';

class SeriesAnimeCategoryService {
  static const String _tableName = 'series_anime_categories';

  /// Crear una nueva categoría
  static Future<int> createCategory(SeriesAnimeCategory category) async {
    final db = await DatabaseService.database;
    return await db.insert(_tableName, category.toMap());
  }

  /// Obtener todas las categorías
  static Future<List<SeriesAnimeCategory>> getAllCategories() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => SeriesAnimeCategory.fromMap(maps[i]));
  }

  /// Obtener categorías por tipo (video o lectura)
  static Future<List<SeriesAnimeCategory>> getCategoriesByType(String type) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => SeriesAnimeCategory.fromMap(maps[i]));
  }

  /// Obtener una categoría por ID
  static Future<SeriesAnimeCategory?> getCategoryById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return SeriesAnimeCategory.fromMap(maps.first);
    }
    return null;
  }

  /// Actualizar una categoría
  static Future<int> updateCategory(SeriesAnimeCategory category) async {
    final db = await DatabaseService.database;
    return await db.update(
      _tableName,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Eliminar una categoría
  static Future<int> deleteCategory(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Verificar si existe una categoría con el mismo nombre y tipo
  static Future<bool> categoryExists(String name, String type) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
    );
    return maps.isNotEmpty;
  }

  /// Obtener estadísticas de categorías
  static Future<Map<String, int>> getCategoryStats() async {
    final db = await DatabaseService.database;
    
    // Contar total de categorías
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final total = totalResult.first['count'] as int;
    
    // Contar categorías de video
    final videoResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ?',
      ['video']
    );
    final video = videoResult.first['count'] as int;
    
    // Contar categorías de lectura
    final lecturaResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE type = ?',
      ['lectura']
    );
    final lectura = lecturaResult.first['count'] as int;
    
    return {
      'total': total,
      'video': video,
      'lectura': lectura,
    };
  }

  /// Calcular el atraso real considerando los episodios vistos
  /// Retorna: {'daysBehind': int, 'chaptersBehind': int}
  /// Para video: chaptersBehind = capítulos de atraso
  /// Para lectura: chaptersBehind = tomos de atraso
  static Future<Map<String, int>> calculateRealDelay(int categoryId) async {
    try {
      final category = await getCategoryById(categoryId);
      if (category == null) return {'daysBehind': 0, 'chaptersBehind': 0};

      // Calcular días válidos desde el inicio (solo días seleccionados)
      final validDays = category.getDaysBehind();
      
      // Obtener TODAS las series de esta categoría (incluyendo terminadas y en espera)
      final allSeries = await SeriesService.getSeriesByCategory(categoryId);
      
      if (category.type == 'lectura') {
        // LÓGICA PARA LECTURA: contar por tomos completos
        // frequency es negativo (ej: -3 significa 1 tomo en 3 días)
        final daysPerTomo = category.frequency.abs();
        
        // Calcular tomos esperados según la configuración
        // (días válidos / días por tomo)
        final expectedTomos = validDays ~/ daysPerTomo;
        
        // Contar tomos realmente completados (todos los capítulos con watchDate != null)
        // Incluir series terminadas sólo si tienen startWatchingDate (fueron vistas, no creadas ya terminadas)
        int watchedTomos = 0;
        for (final series in allSeries) {
          if (series.status == SeriesStatus.terminada && series.startWatchingDate == null) {
            // Serie creada directamente como terminada: no cuenta
            continue;
          }
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          for (final season in seasons) {
            final episodes = await SeriesService.getEpisodesBySeason(season.id!);
            final allWatched = episodes.isNotEmpty &&
                              episodes.every((ep) => ep.status == EpisodeStatus.visto && ep.watchDate != null);
            if (allWatched) {
              watchedTomos++;
            }
          }
        }
        
        // Calcular atraso: tomos esperados - tomos vistos
        final tomosBehind = expectedTomos - watchedTomos;
        
        // Calcular días de atraso basado en tomos de atraso
        final actualDaysBehind = tomosBehind > 0 
            ? (tomosBehind * daysPerTomo) 
            : 0;

        return {
          'daysBehind': actualDaysBehind > 0 ? actualDaysBehind : 0,
          'chaptersBehind': tomosBehind > 0 ? tomosBehind : 0, // En lectura, esto representa tomos
        };
      } else {
        // LÓGICA PARA VIDEO: contar por capítulos individuales
        // Calcular capítulos esperados según la configuración
        // (días válidos * frecuencia de capítulos por día)
        final expectedChapters = validDays * category.frequency;
        
        // Contar capítulos realmente vistos:
        // - Series activas: contar sólo episodios con watchDate y DESPUÉS del punto actual
        // - Series terminadas: contar sólo si startWatchingDate != null (fueron vistas)
        int watchedChapters = 0;
        for (final series in allSeries) {
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          for (final season in seasons) {
            final episodes = await SeriesService.getEpisodesBySeason(season.id!);
            if (series.status == SeriesStatus.terminada) {
              if (series.startWatchingDate == null) continue; // creada terminada: no cuenta
              watchedChapters += episodes.where((e) => e.status == EpisodeStatus.visto && e.watchDate != null).length;
            } else {
              // Activa: después del punto actual
              for (final e in episodes) {
                // Contabilizar capítulos vistos en o después del punto actual
                final atOrAfterPoint = season.seasonNumber > series.currentSeason ||
                    (season.seasonNumber == series.currentSeason && e.episodeNumber >= series.currentEpisode);
                if (atOrAfterPoint && e.status == EpisodeStatus.visto && e.watchDate != null) {
                  watchedChapters++;
                }
              }
            }
          }
        }

        // Calcular atraso real: capítulos esperados - capítulos vistos
        final chaptersBehind = expectedChapters - watchedChapters;
        
        // Calcular días de atraso basado en capítulos de atraso
        final actualDaysBehind = chaptersBehind > 0 
            ? (chaptersBehind / category.frequency).ceil() 
            : 0;

        return {
          'daysBehind': actualDaysBehind > 0 ? actualDaysBehind : 0,
          'chaptersBehind': chaptersBehind > 0 ? chaptersBehind : 0,
        };
      }
    } catch (e) {
      print('Error calculando atraso real: $e');
      return {'daysBehind': 0, 'chaptersBehind': 0};
    }
  }
}

