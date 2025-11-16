import '../models/series.dart';
import '../models/season.dart';
import '../models/episode.dart';
import 'database_service.dart';

class SeriesService {
  static const String _seriesTable = 'series';
  static const String _seasonsTable = 'seasons';
  static const String _episodesTable = 'episodes';

  // Verificar que las tablas existen (se crean automáticamente en DatabaseService)
  static Future<void> createTables() async {
    // Las tablas se crean automáticamente en DatabaseService._onCreate()
    // Este método se mantiene por compatibilidad pero ya no es necesario
    final db = await DatabaseService.database;
    
    // Verificar que las tablas existen
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN (?, ?, ?)",
      [_seriesTable, _seasonsTable, _episodesTable]
    );
    
    if (tables.length != 3) {
      throw Exception('Las tablas de series no están disponibles. Reinicia la aplicación.');
    }
  }

  // CRUD para Series
  static Future<int> createSeries(Series series) async {
    final db = await DatabaseService.database;
    
    // Si no se especifica display_order, asignar el siguiente disponible
    int displayOrder = series.displayOrder;
    if (displayOrder == 0) {
      // Obtener el máximo display_order de las series de la misma categoría
      final result = await db.rawQuery('''
        SELECT MAX(display_order) as max_order 
        FROM $_seriesTable 
        WHERE category_id = ?
      ''', [series.categoryId]);
      
      final maxOrder = result.first['max_order'] as int?;
      displayOrder = (maxOrder ?? -1) + 1;
    }
    
    // Crear la serie con el display_order correcto
    final seriesWithOrder = series.copyWith(
      displayOrder: displayOrder,
    );
    
    return await db.insert(_seriesTable, seriesWithOrder.toMap());
  }

  static Future<List<Series>> getSeriesByCategory(int categoryId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seriesTable,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'display_order ASC, name ASC',
    );

    return List.generate(maps.length, (i) {
      return Series.fromMap(maps[i]);
    });
  }

  static Future<Series?> getSeriesById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seriesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Series.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> updateSeries(Series series) async {
    final db = await DatabaseService.database;
    
    // Obtener la serie anterior para comparar estados
    final previousSeries = await getSeriesById(series.id!);
    
    // Si la serie cambió a "Terminada", marcar todos los episodios como vistos
    if (previousSeries != null && 
        previousSeries.status != SeriesStatus.terminada && 
        series.status == SeriesStatus.terminada) {
      
      // Obtener todas las temporadas de la serie
      final seasons = await getSeasonsBySeries(series.id!);
      
      // Marcar todos los episodios como vistos
      for (final season in seasons) {
        final episodes = await getEpisodesBySeason(season.id!);
        
        for (final episode in episodes) {
          // Solo actualizar si no está ya visto
          if (episode.status != EpisodeStatus.visto) {
            final updatedEpisode = episode.copyWith(
              status: EpisodeStatus.visto,
              watchProgress: 1.0,
              watchDate: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await updateEpisode(updatedEpisode);
          }
        }
        
        // Actualizar el contador de capítulos vistos en la temporada
        await updateSeasonWatchedCount(season.id!);
      }
    }
    
    return await db.update(
      _seriesTable,
      series.toMap(),
      where: 'id = ?',
      whereArgs: [series.id],
    );
  }

  static Future<int> deleteSeries(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _seriesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Actualizar orden de las series
  static Future<void> updateSeriesOrder(List<Series> seriesList) async {
    final db = await DatabaseService.database;
    
    for (int i = 0; i < seriesList.length; i++) {
      final series = seriesList[i];
      final updatedSeries = series.copyWith(
        displayOrder: i,
        updatedAt: DateTime.now(),
      );
      
      await db.update(
        _seriesTable,
        updatedSeries.toMap(),
        where: 'id = ?',
        whereArgs: [series.id],
      );
    }
  }

  // CRUD para Seasons
  static Future<int> createSeason(Season season) async {
    final db = await DatabaseService.database;
    return await db.insert(_seasonsTable, season.toMap());
  }

  static Future<List<Season>> getSeasonsBySeries(int seriesId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seasonsTable,
      where: 'series_id = ?',
      whereArgs: [seriesId],
      orderBy: 'season_number ASC',
    );

    return List.generate(maps.length, (i) {
      return Season.fromMap(maps[i]);
    });
  }

  static Future<Season?> getSeasonById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seasonsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Season.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> updateSeason(Season season) async {
    final db = await DatabaseService.database;
    return await db.update(
      _seasonsTable,
      season.toMap(),
      where: 'id = ?',
      whereArgs: [season.id],
    );
  }

  static Future<int> deleteSeason(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _seasonsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD para Episodes
  static Future<int> createEpisode(Episode episode) async {
    final db = await DatabaseService.database;
    return await db.insert(_episodesTable, episode.toMap());
  }

  static Future<List<Episode>> getEpisodesBySeason(int seasonId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _episodesTable,
      where: 'season_id = ?',
      whereArgs: [seasonId],
      orderBy: 'episode_number ASC',
    );

    return List.generate(maps.length, (i) {
      return Episode.fromMap(maps[i]);
    });
  }

  static Future<Episode?> getEpisodeById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _episodesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Episode.fromMap(maps.first);
    }
    return null;
  }

  static Future<int> updateEpisode(Episode episode) async {
    final db = await DatabaseService.database;
    return await db.update(
      _episodesTable,
      episode.toMap(),
      where: 'id = ?',
      whereArgs: [episode.id],
    );
  }

  static Future<int> deleteEpisode(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      _episodesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Métodos de utilidad
  static Future<List<Series>> getAllSeries() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seriesTable,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return Series.fromMap(maps[i]);
    });
  }

  static Future<int> getSeriesCountByCategory(int categoryId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_seriesTable WHERE category_id = ?',
      [categoryId],
    );
    return result.first['count'] as int;
  }

  static Future<List<Series>> getSeriesByStatus(SeriesStatus status) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seriesTable,
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return Series.fromMap(maps[i]);
    });
  }

  static Future<List<Series>> getActiveSeries() async {
    return getSeriesByStatus(SeriesStatus.mirando);
  }

  static Future<List<Series>> getCompletedSeries() async {
    return getSeriesByStatus(SeriesStatus.terminada);
  }

  static Future<List<Series>> getWaitingSeries() async {
    return getSeriesByStatus(SeriesStatus.enEspera);
  }

  static Future<List<Series>> getNewSeries() async {
    return getSeriesByStatus(SeriesStatus.nueva);
  }

  // Obtener el último episodio visto de una serie
  static Future<Map<String, int>?> getLastWatchedEpisode(int seriesId) async {
    try {
      final seasons = await getSeasonsBySeries(seriesId);
      if (seasons.isEmpty) return null;

      // Ordenar temporadas por número
      seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

      int? lastSeasonNumber;
      int? lastEpisodeNumber;

      // Buscar el último episodio visto en todas las temporadas
      // El último episodio visto es el que tiene la temporada y episodio más alto
      for (final season in seasons) {
        final episodes = await getEpisodesBySeason(season.id!);
        final watchedEpisodes = episodes.where((e) => e.status == EpisodeStatus.visto).toList();
        
        if (watchedEpisodes.isNotEmpty) {
          // Ordenar por número de episodio (descendente para obtener el mayor)
          watchedEpisodes.sort((a, b) => b.episodeNumber.compareTo(a.episodeNumber));
          
          // Obtener el último episodio visto de esta temporada (el de mayor número)
          final lastEp = watchedEpisodes.first;
          
          // Si es la primera temporada con episodios vistos, o si esta temporada es mayor
          // o si es la misma temporada pero con episodio mayor, actualizar
          if (lastSeasonNumber == null || 
              season.seasonNumber > lastSeasonNumber ||
              (season.seasonNumber == lastSeasonNumber && lastEp.episodeNumber > (lastEpisodeNumber ?? 0))) {
            lastSeasonNumber = season.seasonNumber;
            lastEpisodeNumber = lastEp.episodeNumber;
          }
        }
      }

      if (lastSeasonNumber != null && lastEpisodeNumber != null) {
        return {
          'season': lastSeasonNumber,
          'episode': lastEpisodeNumber,
        };
      }

      return null;
    } catch (e) {
      print('Error obteniendo último episodio visto: $e');
      return null;
    }
  }

  // Métodos para estadísticas
  static Future<Map<String, int>> getSeriesStatistics(int categoryId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT 
        status,
        COUNT(*) as count
      FROM $_seriesTable 
      WHERE category_id = ?
      GROUP BY status
    ''', [categoryId]);

    final Map<String, int> stats = {};
    for (final row in result) {
      stats[row['status'] as String] = row['count'] as int;
    }

    return stats;
  }

  static Future<Map<String, int>> getOverallStatistics() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT 
        status,
        COUNT(*) as count
      FROM $_seriesTable 
      GROUP BY status
    ''');

    final Map<String, int> stats = {};
    for (final row in result) {
      stats[row['status'] as String] = row['count'] as int;
    }

    return stats;
  }

  // Método para marcar capítulo como visto
  static Future<void> markEpisodeAsWatched(int episodeId, {double? progress, int? rating, String? notes}) async {
    final episode = await getEpisodeById(episodeId);
    if (episode == null) return;

    final updatedEpisode = episode.copyWith(
      status: EpisodeStatus.visto,
      watchProgress: progress ?? 1.0,
      watchDate: DateTime.now(),
      rating: rating ?? episode.rating,
      notes: notes ?? episode.notes,
      updatedAt: DateTime.now(),
    );

    await updateEpisode(updatedEpisode);

    // Actualizar contador de capítulos vistos en la temporada
    await updateSeasonWatchedCount(episode.seasonId);
  }

  // Método para marcar capítulo como parcialmente visto
  static Future<void> markEpisodeAsPartiallyWatched(int episodeId, double progress, {String? notes}) async {
    final episode = await getEpisodeById(episodeId);
    if (episode == null) return;

    final updatedEpisode = episode.copyWith(
      status: EpisodeStatus.parcialmenteVisto,
      watchProgress: progress,
      notes: notes ?? episode.notes,
      updatedAt: DateTime.now(),
    );

    await updateEpisode(updatedEpisode);
  }

  // Método privado para actualizar contador de capítulos vistos
  static Future<void> updateSeasonWatchedCount(int seasonId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM $_episodesTable 
      WHERE season_id = ? AND status = 'visto'
    ''', [seasonId]);

    final watchedCount = result.first['count'] as int;
    
    await db.update(
      _seasonsTable,
      {'watched_episodes': watchedCount, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [seasonId],
    );
  }

  // Método para avanzar al siguiente capítulo
  static Future<void> advanceToNextEpisode(int seriesId) async {
    final series = await getSeriesById(seriesId);
    if (series == null) return;

    final seasons = await getSeasonsBySeries(seriesId);
    if (seasons.isEmpty) return;

    // Ordenar temporadas por número
    seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

    Season? currentSeason;
    for (final season in seasons) {
      if (season.seasonNumber == series.currentSeason) {
        currentSeason = season;
        break;
      }
    }

    if (currentSeason == null) return;

    final nextEpisode = currentSeason.nextEpisode;
    
    // Si hay más capítulos en la temporada actual
    if (currentSeason.hasNextEpisode) {
      final updatedSeries = series.copyWith(
        currentEpisode: nextEpisode,
        updatedAt: DateTime.now(),
      );
      await updateSeries(updatedSeries);
    } else {
      // Buscar la siguiente temporada
      Season? nextSeason;
      for (final season in seasons) {
        if (season.seasonNumber > series.currentSeason) {
          nextSeason = season;
          break;
        }
      }

      if (nextSeason != null) {
        final updatedSeries = series.copyWith(
          currentSeason: nextSeason.seasonNumber,
          currentEpisode: 1,
          updatedAt: DateTime.now(),
        );
        await updateSeries(updatedSeries);
      } else {
        // No hay más temporadas, marcar como terminada
        final updatedSeries = series.copyWith(
          status: SeriesStatus.terminada,
          finishWatchingDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await updateSeries(updatedSeries);
      }
    }
  }

  // Método para crear una serie completa con temporadas y capítulos
  static Future<Series> createCompleteSeries({
    required int categoryId,
    required String name,
    required SeriesStatus status,
    required List<Map<String, dynamic>> seasonsData, // [{seasonNumber: 1, totalEpisodes: 12, title: "Temporada 1"}, ...]
    String? description,
    int? startSeason,
    int? startEpisode,
  }) async {
    final now = DateTime.now();
    
    // Crear la serie
    final series = Series(
      categoryId: categoryId,
      name: name,
      description: description,
      status: status,
      currentSeason: startSeason ?? 1,
      currentEpisode: startEpisode ?? 1,
      startWatchingDate: status == SeriesStatus.mirando ? now : null,
      createdAt: now,
      updatedAt: now,
    );

    final seriesId = await createSeries(series);
    final seasonIds = <int>[];

    // Crear temporadas y capítulos
    for (final seasonData in seasonsData) {
      final seasonNumber = seasonData['seasonNumber'] is int 
          ? seasonData['seasonNumber'] as int 
          : throw ArgumentError('Invalid seasonNumber type');
      final title = seasonData['title'] as String?;
      final totalEpisodes = seasonData['totalEpisodes'] is int 
          ? seasonData['totalEpisodes'] as int 
          : throw ArgumentError('Invalid totalEpisodes type');
      
      final season = Season(
        seriesId: seriesId,
        seasonNumber: seasonNumber,
        title: title,
        totalEpisodes: totalEpisodes,
        watchedEpisodes: 0,
        createdAt: now,
        updatedAt: now,
      );

      final seasonId = await createSeason(season);
      seasonIds.add(seasonId);

      // Crear capítulos
      for (int i = 1; i <= season.totalEpisodes; i++) {
        // Determinar estado del episodio
        EpisodeStatus episodeStatus = EpisodeStatus.noVisto;
        
        // Si es estado "Terminada", marcar TODOS los capítulos como vistos automáticamente
        if (status == SeriesStatus.terminada) {
          episodeStatus = EpisodeStatus.visto;
        }
        // Si es estado "mirando", marcar como vistos los capítulos anteriores al punto actual
        else if (status == SeriesStatus.mirando && startSeason != null && startEpisode != null) {
          final seasonNum = seasonData['seasonNumber'];
          final episodeNum = i;
          
          if (seasonNum is int && (seasonNum < startSeason || 
              (seasonNum == startSeason && episodeNum < startEpisode))) {
            episodeStatus = EpisodeStatus.visto;
          }
        }
        
        // Definir watchDate: 
        // - Terminada: todos con fecha (se cuentan para registro)
        // - Mirando y episodios anteriores al punto de inicio: marcados vistos pero sin fecha (no cuentan)
        DateTime? episodeWatchDate;
        if (status == SeriesStatus.terminada) {
          episodeWatchDate = now;
        } else if (status == SeriesStatus.mirando && startSeason != null && startEpisode != null) {
          final seasonNum = seasonData['seasonNumber'];
          final episodeNum = i;
          if (seasonNum is int && (seasonNum < startSeason || (seasonNum == startSeason && episodeNum < startEpisode))) {
            episodeWatchDate = null; // visto histórico, no cuenta para registro
          }
        }

        final episode = Episode(
          seasonId: seasonId,
          episodeNumber: i,
          title: seasonData['episodeTitle'] as String? ?? 'Capítulo $i',
          createdAt: now,
          updatedAt: now,
          status: episodeStatus,
          watchProgress: episodeStatus == EpisodeStatus.visto ? 1.0 : null,
          watchDate: episodeStatus == EpisodeStatus.visto ? episodeWatchDate : null,
        );

        await createEpisode(episode);
      }
      
      // Actualizar contador de capítulos vistos para la temporada
      if (status == SeriesStatus.terminada) {
        // Si la serie está terminada, todos los capítulos están vistos
        await updateSeasonWatchedCount(seasonId);
      } else if (status == SeriesStatus.mirando && startSeason != null) {
        int watchedCount = 0;
        final seasonNumber = seasonData['seasonNumber'];
        
        if (seasonNumber is int && seasonNumber == startSeason) {
          // En la temporada actual, contar capítulos vistos
          watchedCount = (startEpisode ?? 1) - 1;
        } else if (seasonNumber is int && seasonNumber < startSeason) {
          // Temporadas anteriores están completamente vistas
          final totalEpisodes = seasonData['totalEpisodes'];
          if (totalEpisodes is int) {
            watchedCount = totalEpisodes;
          }
        }
        
        if (watchedCount > 0) {
          await updateSeasonWatchedCount(seasonId);
        }
      }
    }

    return series.copyWith(id: seriesId);
  }

  // Actualizar serie con sus temporadas y episodios
  static Future<void> updateSeriesWithSeasons(Series series, List<Map<String, dynamic>> seasonsData) async {
    // Obtener el estado actual de la serie desde la base de datos
    final currentSeries = await getSeriesById(series.id!);
    if (currentSeries == null) return;
    
    final originalStatus = currentSeries.status; // Guardar el estado original
    
    // Primero actualizar la serie
    await updateSeries(series);

    // Obtener temporadas existentes
    final existingSeasons = await getSeasonsBySeries(series.id!);
    final existingSeasonsMap = <int, Season>{};
    for (final season in existingSeasons) {
      if (season.id != null) {
        existingSeasonsMap[season.id!] = season;
      }
    }

    // Procesar cada temporada en los datos nuevos
    for (final seasonData in seasonsData) {
      final seasonId = seasonData['id'] as int?;
      final seasonNumber = seasonData['seasonNumber'] as int;
      final title = seasonData['title'] as String?;
      final totalEpisodes = seasonData['totalEpisodes'] as int;

      if (seasonId != null && existingSeasonsMap.containsKey(seasonId)) {
        // Temporada existente - actualizar
        final existingSeason = existingSeasonsMap[seasonId]!;
        
        // Actualizar información básica de la temporada
        final updatedSeason = existingSeason.copyWith(
          title: title,
          totalEpisodes: totalEpisodes,
          updatedAt: DateTime.now(),
        );
        await updateSeason(updatedSeason);

        // Obtener episodios existentes de esta temporada
        final existingEpisodes = await getEpisodesBySeason(seasonId);
        final currentEpisodeCount = existingEpisodes.length;

        if (totalEpisodes > currentEpisodeCount) {
          // Aumentó el número de capítulos - crear los nuevos
          final now = DateTime.now();
          for (int i = currentEpisodeCount + 1; i <= totalEpisodes; i++) {
            final newEpisode = Episode(
              seasonId: seasonId,
              episodeNumber: i,
              title: 'Capítulo $i',
              createdAt: now,
              updatedAt: now,
              status: EpisodeStatus.noVisto,
            );
            await createEpisode(newEpisode);
          }
        } else if (totalEpisodes < currentEpisodeCount) {
          // Disminuyó el número de capítulos - eliminar los que exceden
          // Ordenar por número de episodio descendente para eliminar los últimos
          existingEpisodes.sort((a, b) => b.episodeNumber.compareTo(a.episodeNumber));
          
          for (int i = 0; i < (currentEpisodeCount - totalEpisodes); i++) {
            if (existingEpisodes[i].id != null) {
              await deleteEpisode(existingEpisodes[i].id!);
            }
          }
        }

        // Actualizar contador de capítulos vistos
        await updateSeasonWatchedCount(seasonId);
      } else {
        // Nueva temporada - crear
        // Si la serie estaba terminada o en espera originalmente, cambiar automáticamente a "Mirando"
        // y establecer un nuevo startWatchingDate para que solo se cuenten los tomos/capítulos
        // vistos DESPUÉS de agregar este nuevo tomo
        if (originalStatus == SeriesStatus.terminada || originalStatus == SeriesStatus.enEspera) {
          final now = DateTime.now();
          // Obtener la serie actualizada desde la base de datos
          final currentSeriesAfterUpdate = await getSeriesById(series.id!);
          if (currentSeriesAfterUpdate != null) {
            final updatedSeries = currentSeriesAfterUpdate.copyWith(
              status: SeriesStatus.mirando,
              startWatchingDate: now, // Nuevo punto de inicio, no mantener el anterior
              finishWatchingDate: null, // Limpiar fecha de finalización
              currentSeason: seasonNumber,
              currentEpisode: 1,
              updatedAt: now,
            );
            await updateSeries(updatedSeries);
          }
        }
        
        final now = DateTime.now();
        final newSeason = Season(
          seriesId: series.id!,
          seasonNumber: seasonNumber,
          title: title,
          totalEpisodes: totalEpisodes,
          watchedEpisodes: 0,
          createdAt: now,
          updatedAt: now,
        );
        
        final newSeasonId = await createSeason(newSeason);

        // Crear todos los episodios de la nueva temporada
        for (int i = 1; i <= totalEpisodes; i++) {
          final episode = Episode(
            seasonId: newSeasonId,
            episodeNumber: i,
            title: 'Capítulo $i',
            createdAt: now,
            updatedAt: now,
            status: EpisodeStatus.noVisto,
          );
          await createEpisode(episode);
        }
      }
    }

    // Eliminar temporadas que ya no están en la lista
    final newSeasonIds = seasonsData
        .where((s) => s['id'] != null)
        .map((s) => s['id'] as int)
        .toSet();
    
    for (final existingSeason in existingSeasons) {
      if (existingSeason.id != null && !newSeasonIds.contains(existingSeason.id)) {
        // Esta temporada ya no está en la lista - eliminarla (cascade eliminará los episodios)
        await deleteSeason(existingSeason.id!);
      }
    }
  }
}
