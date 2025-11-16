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
        
        // Contar tomos realmente completados
        // Solo contar tomos de series que fueron creadas como nuevas o mirando
        int watchedTomos = 0;
        for (final series in allSeries) {
          // Si la serie está terminada y no tiene startWatchingDate, fue creada como terminada: no cuenta
          if (series.status == SeriesStatus.terminada && series.startWatchingDate == null) {
            continue;
          }
          
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          
          // Verificar si hay capítulos con watchDate anterior al startWatchingDate
          // Si los hay, significa que se agregó nueva temporada
          bool hasNewTemporada = false;
          if (series.startWatchingDate != null) {
            final allSeriesEpisodes = <Episode>[];
            for (final s in seasons) {
              final eps = await SeriesService.getEpisodesBySeason(s.id!);
              allSeriesEpisodes.addAll(eps);
            }
            // Si hay algún episodio con watchDate anterior al startWatchingDate, 
            // significa que se agregó nueva temporada
            hasNewTemporada = allSeriesEpisodes.any((ep) => 
              ep.watchDate != null && ep.watchDate!.isBefore(series.startWatchingDate!));
          }
          
          for (final season in seasons) {
            final episodes = await SeriesService.getEpisodesBySeason(season.id!);
            // Verificar que todos los capítulos del tomo estén vistos
            final allWatched = episodes.isNotEmpty &&
                              episodes.every((ep) => ep.status == EpisodeStatus.visto && ep.watchDate != null);
            
            if (allWatched) {
              // REGLA CRÍTICA: Si tiene nueva temporada, SOLO contar tomos vistos DESPUÉS del nuevo startWatchingDate
              if (hasNewTemporada && series.startWatchingDate != null) {
                // Solo contar tomos vistos DESPUÉS del nuevo startWatchingDate
                final lastEpisodeDate = episodes
                    .where((ep) => ep.watchDate != null)
                    .map((ep) => ep.watchDate!)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
                
                if (lastEpisodeDate.isAfter(series.startWatchingDate!)) {
                  watchedTomos++;
                }
                // Si el tomo fue visto antes del nuevo startWatchingDate, NO cuenta
              } else if (series.status == SeriesStatus.mirando && series.startWatchingDate != null) {
                // Serie activa con startWatchingDate y SIN nueva temporada: verificar que el tomo se haya visto después
                final lastEpisodeDate = episodes
                    .where((ep) => ep.watchDate != null)
                    .map((ep) => ep.watchDate!)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
                
                if (lastEpisodeDate.isBefore(series.startWatchingDate!)) {
                  continue; // Este tomo fue visto antes del inicio, no cuenta
                }
                watchedTomos++;
              } else {
                // Serie terminada sin nueva temporada, o serie sin startWatchingDate: contar normalmente
                watchedTomos++;
              }
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
        
        // Contar capítulos realmente vistos
        // Solo contar capítulos de series que fueron creadas como nuevas o mirando
        // NO contar capítulos de series que fueron creadas como terminadas
        int watchedChapters = 0;
        for (final series in allSeries) {
          // Si la serie está terminada y no tiene startWatchingDate, fue creada como terminada: no cuenta
          if (series.status == SeriesStatus.terminada && series.startWatchingDate == null) {
            continue;
          }
          
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          
          // Verificar si hay capítulos con watchDate anterior al startWatchingDate
          // Si los hay, significa que se agregó nueva temporada
          bool hasNewTemporada = false;
          if (series.startWatchingDate != null) {
            final allSeriesEpisodes = <Episode>[];
            for (final s in seasons) {
              final eps = await SeriesService.getEpisodesBySeason(s.id!);
              allSeriesEpisodes.addAll(eps);
            }
            // Si hay algún episodio con watchDate anterior al startWatchingDate, 
            // significa que se agregó nueva temporada
            hasNewTemporada = allSeriesEpisodes.any((ep) => 
              ep.watchDate != null && ep.watchDate!.isBefore(series.startWatchingDate!));
          }
          
          for (final season in seasons) {
            final episodes = await SeriesService.getEpisodesBySeason(season.id!);
            
            for (final e in episodes) {
              if (e.status == EpisodeStatus.visto && e.watchDate != null) {
                // REGLA CRÍTICA: Si hay startWatchingDate, los capítulos vistos ANTES de él NO deben contar
                // Esto aplica tanto si tiene nueva temporada como si no
                if (series.startWatchingDate != null) {
                  // Si el watchDate es anterior al startWatchingDate, NO contar
                  // (ya estaban contados cuando la serie estaba activa antes, o nunca se contaron si fue creada como terminada)
                  if (e.watchDate!.isBefore(series.startWatchingDate!)) {
                    continue; // NO contar, ya estaba contado o nunca se contó
                  }
                  
                  // El watchDate es DESPUÉS del startWatchingDate, puede contar
                  // Si está en estado "mirando", verificar que esté en o después del punto actual
                  if (series.status == SeriesStatus.mirando) {
                    final atOrAfterPoint = season.seasonNumber > series.currentSeason ||
                        (season.seasonNumber == series.currentSeason && e.episodeNumber >= series.currentEpisode);
                    if (atOrAfterPoint) {
                      watchedChapters++;
                    }
                  } else {
                    // Si está terminada, contar todos los vistos después del startWatchingDate
                    watchedChapters++;
                  }
                } else {
                  // No hay startWatchingDate: contar normalmente si está en o después del punto actual
                  if (series.status == SeriesStatus.mirando) {
                    final atOrAfterPoint = season.seasonNumber > series.currentSeason ||
                        (season.seasonNumber == series.currentSeason && e.episodeNumber >= series.currentEpisode);
                    if (atOrAfterPoint) {
                      watchedChapters++;
                    }
                  } else {
                    // Si está terminada sin startWatchingDate, contar todos
                    watchedChapters++;
                  }
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


