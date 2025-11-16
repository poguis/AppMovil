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
        // - Series activas (mirando): contar solo tomos vistos DESPUÉS del startWatchingDate (si existe)
        // - Series terminadas que se vieron desde el principio: contar todos los tomos vistos
        // - Series terminadas a las que se agregó nueva temporada: contar solo tomos vistos DESPUÉS del nuevo startWatchingDate
        int watchedTomos = 0;
        for (final series in allSeries) {
          // Si la serie está terminada y no tiene startWatchingDate, fue creada ya terminada: no cuenta
          if (series.status == SeriesStatus.terminada && series.startWatchingDate == null) {
            continue;
          }
          
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          
          // Verificar si hay capítulos con watchDate anterior al startWatchingDate
          // Si los hay, significa que se agregó nueva temporada a una serie que ya tenía capítulos vistos
          bool hasNewTemporada = false;
          if (series.startWatchingDate != null) {
            // Verificar todos los episodios de la serie para detectar nueva temporada
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
              // Si tiene nueva temporada agregada (hasNewTemporada):
              // - Los tomos vistos ANTES del nuevo startWatchingDate NO deben contar
              //   porque ya estaban contados cuando la serie estaba activa
              // - Solo contar tomos vistos DESPUÉS del nuevo startWatchingDate
              // Si no tiene nueva temporada, aplicar el filtro de startWatchingDate normalmente
              if (hasNewTemporada && series.startWatchingDate != null) {
                // Solo contar tomos vistos DESPUÉS del nuevo startWatchingDate
                final lastEpisodeDate = episodes
                    .where((ep) => ep.watchDate != null)
                    .map((ep) => ep.watchDate!)
                    .reduce((a, b) => a.isAfter(b) ? a : b);
                
                if (lastEpisodeDate.isAfter(series.startWatchingDate!)) {
                  watchedTomos++;
                }
                // Si el tomo fue visto antes del nuevo startWatchingDate, no cuenta
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
                // Para series terminadas sin nueva temporada, o series sin startWatchingDate, contar normalmente
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
        
        // Contar capítulos realmente vistos:
        // - Series activas (mirando): contar episodios con watchDate DESPUÉS del startWatchingDate (si existe) y en/después del punto actual
        // - Series terminadas que se vieron desde el principio: contar todos los capítulos vistos
        // - Series terminadas a las que se agregó nueva temporada: contar solo capítulos vistos DESPUÉS del nuevo startWatchingDate
        int watchedChapters = 0;
        for (final series in allSeries) {
          // Si la serie está terminada y no tiene startWatchingDate, fue creada ya terminada: no cuenta
          if (series.status == SeriesStatus.terminada && series.startWatchingDate == null) {
            continue;
          }
          
          final seasons = await SeriesService.getSeasonsBySeries(series.id!);
          
          // Verificar si hay capítulos con watchDate anterior al startWatchingDate
          // Si los hay, significa que se agregó nueva temporada a una serie que ya tenía capítulos vistos
          bool hasNewTemporada = false;
          if (series.startWatchingDate != null) {
            // Verificar todos los episodios de la serie para detectar nueva temporada
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
            
            // Si tiene nueva temporada, aplicar la misma lógica sin importar el estado:
            // Solo contar capítulos vistos DESPUÉS del nuevo startWatchingDate
            if (hasNewTemporada && series.startWatchingDate != null) {
              // Se agregó nueva temporada:
              // - Los capítulos vistos ANTES del nuevo startWatchingDate NO deben contar
              //   porque ya estaban contados cuando la serie estaba activa
              // - Solo contar capítulos vistos DESPUÉS del nuevo startWatchingDate (nueva temporada)
              for (final e in episodes) {
                if (e.status == EpisodeStatus.visto && e.watchDate != null) {
                  // CRÍTICO: Solo contar si fue visto DESPUÉS del nuevo startWatchingDate
                  // Los capítulos con watchDate anterior NO deben contar nunca
                  if (e.watchDate!.isAfter(series.startWatchingDate!)) {
                    // Si está en estado "mirando", también verificar que esté en o después del punto actual
                    if (series.status == SeriesStatus.mirando) {
                      final atOrAfterPoint = season.seasonNumber > series.currentSeason ||
                          (season.seasonNumber == series.currentSeason && e.episodeNumber >= series.currentEpisode);
                      if (atOrAfterPoint) {
                        watchedChapters++;
                      }
                    } else {
                      // Si está terminada, contar todos los vistos después del nuevo startWatchingDate
                      watchedChapters++;
                    }
                  }
                  // Si el watchDate es anterior o igual al startWatchingDate, NO contar (ya estaban contados)
                }
              }
            } else if (series.status == SeriesStatus.terminada) {
              // Serie terminada sin nueva temporada: contar todos los capítulos vistos
              for (final e in episodes) {
                if (e.status == EpisodeStatus.visto && e.watchDate != null) {
                  watchedChapters++;
                }
              }
            } else {
              // Activa (mirando) sin nueva temporada: después del punto actual
              // Aplicar el filtro de punto actual y startWatchingDate
              // IMPORTANTE: Si hay capítulos con watchDate anterior al startWatchingDate,
              // NO deben contarse (ya estaban contados cuando la serie estaba activa antes)
              for (final e in episodes) {
                if (e.status == EpisodeStatus.visto && e.watchDate != null) {
                  // Verificar primero que el watchDate sea DESPUÉS del startWatchingDate
                  // Si hay startWatchingDate y el watchDate es anterior, NO contar
                  if (series.startWatchingDate != null && 
                      e.watchDate!.isBefore(series.startWatchingDate!)) {
                    // Este capítulo fue visto antes del startWatchingDate actual
                    // No debe contarse (ya estaba contado cuando la serie estaba activa antes)
                    continue;
                  }
                  
                  // Contabilizar capítulos vistos en o después del punto actual
                  final atOrAfterPoint = season.seasonNumber > series.currentSeason ||
                      (season.seasonNumber == series.currentSeason && e.episodeNumber >= series.currentEpisode);
                  if (atOrAfterPoint) {
                    if (series.startWatchingDate != null) {
                      // Si hay startWatchingDate, verificar que el watchDate sea después de él
                      if (e.watchDate!.isAfter(series.startWatchingDate!) || 
                          e.watchDate!.isAtSameMomentAs(series.startWatchingDate!)) {
                        watchedChapters++;
                      }
                    } else {
                      // Si no hay startWatchingDate, contar normalmente
                      watchedChapters++;
                    }
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


