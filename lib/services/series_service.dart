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
    return await db.insert(_seriesTable, series.toMap());
  }

  static Future<List<Series>> getSeriesByCategory(int categoryId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _seriesTable,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
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
    await _updateSeasonWatchedCount(episode.seasonId);
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
  static Future<void> _updateSeasonWatchedCount(int seasonId) async {
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
      final season = Season(
        seriesId: seriesId,
        seasonNumber: seasonData['seasonNumber'] as int,
        title: seasonData['title'] as String?,
        totalEpisodes: seasonData['totalEpisodes'] as int,
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
        
        // Si es estado "mirando", marcar como vistos los capítulos anteriores al punto actual
        if (status == SeriesStatus.mirando && startSeason != null && startEpisode != null) {
          final seasonNum = seasonData['seasonNumber'] as int;
          final episodeNum = i;
          
          if (seasonNum < startSeason || 
              (seasonNum == startSeason && episodeNum < startEpisode)) {
            episodeStatus = EpisodeStatus.visto;
          }
        }
        
        final episode = Episode(
          seasonId: seasonId,
          episodeNumber: i,
          title: seasonData['episodeTitle'] as String? ?? 'Capítulo $i',
          createdAt: now,
          updatedAt: now,
          status: episodeStatus,
          watchDate: episodeStatus == EpisodeStatus.visto ? now : null,
        );

        await createEpisode(episode);
      }
      
      // Actualizar contador de capítulos vistos para la temporada
      if (status == SeriesStatus.mirando) {
        int watchedCount = 0;
        if (seasonData['seasonNumber'] as int? == startSeason) {
          // En la temporada actual, contar capítulos vistos
          watchedCount = (startEpisode ?? 1) - 1;
        } else if (seasonData['seasonNumber'] as int? != null && 
                   (seasonData['seasonNumber'] as int) < (startSeason ?? 1)) {
          // Temporadas anteriores están completamente vistas
          watchedCount = seasonData['totalEpisodes'] as int;
        }
        
        if (watchedCount > 0) {
          await _updateSeasonWatchedCount(seasonId);
        }
      }
    }

    return series.copyWith(id: seriesId);
  }
}
