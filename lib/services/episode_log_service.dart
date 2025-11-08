import '../models/episode_log_entry.dart';
import '../models/series.dart';
import '../models/episode.dart';
import 'database_service.dart';
import 'series_service.dart';
import 'series_anime_category_service.dart';

class EpisodeLogService {
  // Obtener todos los episodios de una categoría específica
  // Solo retorna episodios PENDIENTES desde el punto actual de cada serie
  static Future<List<EpisodeLogEntry>> getEpisodesByCategory(int categoryId) async {
    try {
      final db = await DatabaseService.database;
      // Obtener tipo de categoría para decidir el orden
      final category = await SeriesAnimeCategoryService.getCategoryById(categoryId);
      final isReading = category?.type == 'lectura';
      
      // Primero obtener todas las series de la categoría para conocer sus puntos actuales
      final allSeries = await SeriesService.getSeriesByCategory(categoryId);
      final seriesCurrentPoints = <int, Map<String, int>>{}; // seriesId -> {season, episode}
      
      for (final series in allSeries) {
        if (series.id != null && series.status != SeriesStatus.terminada) {
          seriesCurrentPoints[series.id!] = {
            'season': series.currentSeason,
            'episode': series.currentEpisode,
          };
        }
      }
      
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT
          e.id as episode_id,
          e.season_id,
          e.episode_number,
          e.title as episode_title,
          e.status as episode_status,
          e.watch_date,
          s.id as series_id,
          s.name as series_name,
          s.current_season,
          s.current_episode,
          s.display_order,
          s.status as series_status,
          sn.season_number,
          sac.name as category_name
        FROM episodes e
        INNER JOIN seasons sn ON e.season_id = sn.id
        INNER JOIN series s ON sn.series_id = s.id
        INNER JOIN series_anime_categories sac ON s.category_id = sac.id
        WHERE s.category_id = ? AND s.status != 'terminada'
        ORDER BY s.display_order ASC, sn.season_number ASC, e.episode_number ASC
      ''', [categoryId]);

      // Filtrar solo episodios pendientes desde el punto actual de cada serie
      final pendingEpisodes = <EpisodeLogEntry>[];
      
      for (final map in maps) {
        final seriesId = map['series_id'] as int;
        final seriesStatus = map['series_status'] as String;
        final seasonNumber = map['season_number'] as int;
        final episodeNumber = map['episode_number'] as int;
        final episodeStatus = EpisodeStatus.values.firstWhere(
          (eStatus) => eStatus.name == map['episode_status'],
          orElse: () => EpisodeStatus.noVisto,
        );
        
        // Excluir series terminadas
        if (seriesStatus == 'terminada') {
          continue;
        }
        
        // Obtener el punto actual de esta serie
        final currentPoint = seriesCurrentPoints[seriesId];
        if (currentPoint == null) continue;
        
        final currentSeason = currentPoint['season']!;
        final currentEpisode = currentPoint['episode']!;
        
        // Solo incluir episodios desde el punto actual en adelante (vistos y pendientes)
        // Los episodios anteriores al punto actual NO se incluyen en el registro
        bool shouldInclude = false;
        
        if (seasonNumber > currentSeason) {
          // Temporada futura - incluir todos (vistos y pendientes)
          shouldInclude = true;
        } else if (seasonNumber == currentSeason && episodeNumber >= currentEpisode) {
          // Misma temporada, desde el capítulo actual en adelante - incluir todos
          shouldInclude = true;
        }
        // Si es temporada o capítulo anterior, no incluir (ya pasó, no aparece en el registro)
        
        if (shouldInclude) {
          pendingEpisodes.add(EpisodeLogEntry(
            episodeId: map['episode_id'] as int,
            seasonId: map['season_id'] as int,
            seriesId: seriesId,
            seriesName: map['series_name'] as String,
            categoryName: map['category_name'] as String,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeTitle: map['episode_title'] as String,
            status: episodeStatus,
            watchDate: map['watch_date'] != null
                ? DateTime.parse(map['watch_date'] as String)
                : null,
            seriesDisplayOrder: map['display_order'] as int? ?? 0,
          ));
        }
      }

      // Alternar según tipo: video por episodios; lectura por tomos
      return isReading
          ? _alternateByVolumes(pendingEpisodes)
          : _alternateEpisodes(pendingEpisodes);
    } catch (e) {
      print('Error obteniendo episodios de la categoría: $e');
      return [];
    }
  }

  // Verificar si un episodio es el último de la serie (después de marcarlo como visto)
  static Future<bool> isLastEpisodeOfSeries(int episodeId) async {
    try {
      final episode = await SeriesService.getEpisodeById(episodeId);
      if (episode == null || episode.status != EpisodeStatus.visto) return false;

      final season = await SeriesService.getSeasonById(episode.seasonId);
      if (season == null) return false;

      final series = await SeriesService.getSeriesById(season.seriesId);
      if (series == null) return false;

      // Obtener todas las temporadas de la serie ordenadas
      final seasons = await SeriesService.getSeasonsBySeries(series.id!);
      if (seasons.isEmpty) return false;

      seasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

      // Obtener la última temporada
      final lastSeason = seasons.last;

      // Verificar si el episodio es de la última temporada
      if (season.id != lastSeason.id) return false;

      // Obtener todos los episodios de la última temporada
      final episodes = await SeriesService.getEpisodesBySeason(lastSeason.id!);
      if (episodes.isEmpty) return false;

      // Ordenar por número de episodio
      episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

      // Verificar si este es el último episodio
      final lastEpisode = episodes.last;
      if (episode.id != lastEpisode.id) return false;

      // Verificar si todos los episodios de la serie están vistos
      for (final s in seasons) {
        final seasonEpisodes = await SeriesService.getEpisodesBySeason(s.id!);
        for (final e in seasonEpisodes) {
          // Si hay algún episodio no visto, no es el último
          if (e.status != EpisodeStatus.visto) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('Error verificando si es último episodio: $e');
      return false;
    }
  }

  // Marcar episodio como visto/no visto
  // Retorna: {'isLastEpisode': bool, 'seriesId': int?} si es el último episodio
  static Future<Map<String, dynamic>> toggleEpisodeWatchedStatus(int episodeId, bool isWatched) async {
    try {
      final episode = await SeriesService.getEpisodeById(episodeId);
      if (episode == null) return {'isLastEpisode': false, 'seriesId': null};

      final newStatus = isWatched ? EpisodeStatus.visto : EpisodeStatus.noVisto;
      final newWatchDate = isWatched ? DateTime.now() : null;

      final updatedEpisode = episode.copyWith(
        status: newStatus,
        watchDate: newWatchDate,
        updatedAt: DateTime.now(),
      );
      await SeriesService.updateEpisode(updatedEpisode);

      // Actualizar el contador de episodios vistos en la temporada
      await SeriesService.updateSeasonWatchedCount(episode.seasonId);

      // Actualizar el progreso de la serie (sin avanzar automáticamente el punto actual aquí)
      final season = await SeriesService.getSeasonById(episode.seasonId);
      int? seriesId;
      bool isLastEpisode = false;

      if (season != null) {
        final series = await SeriesService.getSeriesById(season.seriesId);
        if (series != null) {
          seriesId = series.id;
          
          // NOTA: No avanzamos automáticamente el currentSeason/currentEpisode aquí.
          // Esto permite que el primer episodio marcado como visto permanezca
          // incluido en los conteos/estadísticas del registro y atraso.

          // Verificar si es el último episodio de la serie
          if (isWatched) {
            isLastEpisode = await isLastEpisodeOfSeries(episodeId);
          }
        }
      }

      return {
        'isLastEpisode': isLastEpisode,
        'seriesId': seriesId,
      };
    } catch (e) {
      print('Error actualizando estado del episodio: $e');
      throw e;
    }
  }

  // Obtener estadísticas de episodios para una categoría
  static Future<Map<String, int>> getEpisodeStatistics(int categoryId) async {
    try {
      final allEpisodes = await getEpisodesByCategory(categoryId);
      
      // Obtener todas las series de la categoría para identificar cuáles están terminadas
      final allSeries = await SeriesService.getSeriesByCategory(categoryId);
      final finishedSeriesIds = allSeries
          .where((s) => s.status == SeriesStatus.terminada)
          .map((s) => s.id!)
          .toSet();
      
      // Filtrar episodios: excluir los de series terminadas del conteo de pendientes
      final activeEpisodes = allEpisodes.where((e) => !finishedSeriesIds.contains(e.seriesId)).toList();
      
      final total = activeEpisodes.length;
      final watched = activeEpisodes.where((e) => e.status == EpisodeStatus.visto).length;
      final pending = total - watched;

      return {
        'total': total,
        'watched': watched,
        'pending': pending,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de episodios: $e');
      return {
        'total': 0,
        'watched': 0,
        'pending': 0,
      };
    }
  }

  // Obtener episodios agrupados por serie para una categoría
  static Future<Map<String, List<EpisodeLogEntry>>> getEpisodesGroupedBySeries(int categoryId) async {
    try {
      final allEpisodes = await getEpisodesByCategory(categoryId);
      final Map<String, List<EpisodeLogEntry>> grouped = {};

      for (final episode in allEpisodes) {
        if (!grouped.containsKey(episode.seriesName)) {
          grouped[episode.seriesName] = [];
        }
        grouped[episode.seriesName]!.add(episode);
      }

      return grouped;
    } catch (e) {
      print('Error agrupando episodios por serie: $e');
      return {};
    }
  }

  // Calcular atraso real basado en episodios vistos para una categoría
  static Future<Map<String, int>> calculateRealDelay(int categoryId) async {
    try {
      final category = await SeriesAnimeCategoryService.getCategoryById(categoryId);
      if (category == null) return {'episodesWatched': 0, 'episodesExpected': 0, 'episodesBehind': 0};

      final activeSeries = await SeriesService.getSeriesByCategory(categoryId);
      final activeWatchingSeries = activeSeries.where((s) => s.status == SeriesStatus.mirando).toList();

      int totalEpisodesWatched = 0;
      int totalEpisodesExpected = 0;

      for (final series in activeWatchingSeries) {
        final seasons = await SeriesService.getSeasonsBySeries(series.id!);

        for (final season in seasons) {
          final episodes = await SeriesService.getEpisodesBySeason(season.id!);

          // Contar episodios vistos
          final watchedCount = episodes.where((e) => e.status == EpisodeStatus.visto).length;
          totalEpisodesWatched += watchedCount;

          // Calcular episodios esperados basado en la frecuencia y días transcurridos
          if (series.startWatchingDate != null) {
            final now = DateTime.now();
            final startDate = series.startWatchingDate!;
            
            // Calcular días hábiles (excluyendo domingos)
            int workingDays = 0;
            DateTime currentDate = startDate;
            
            while (currentDate.isBefore(now)) {
              // Si no es domingo (0 = domingo)
              if (currentDate.weekday != 7) {
                workingDays++;
              }
              currentDate = currentDate.add(const Duration(days: 1));
            }
            
            // Calcular episodios esperados según la frecuencia y días hábiles
            final expectedEpisodes = (workingDays * category.frequency).round();
            totalEpisodesExpected += expectedEpisodes > season.totalEpisodes 
                ? season.totalEpisodes 
                : expectedEpisodes;
          }
        }
      }

      // Calcular atraso basado en la diferencia
      final delay = totalEpisodesExpected - totalEpisodesWatched;

      return {
        'episodesWatched': totalEpisodesWatched,
        'episodesExpected': totalEpisodesExpected,
        'episodesBehind': delay > 0 ? delay : 0,
      };
    } catch (e) {
      print('Error calculando atraso real: $e');
      return {
        'episodesWatched': 0,
        'episodesExpected': 0,
        'episodesBehind': 0,
      };
    }
  }

  // Obtener progreso de una serie específica
  static Future<Map<String, dynamic>> getSeriesProgress(int seriesId) async {
    try {
      final series = await SeriesService.getSeriesById(seriesId);
      if (series == null) return {};

      final seasons = await SeriesService.getSeasonsBySeries(seriesId);
      int totalEpisodes = 0;
      int watchedEpisodes = 0;

      for (final season in seasons) {
        final episodes = await SeriesService.getEpisodesBySeason(season.id!);
        totalEpisodes += episodes.length;
        watchedEpisodes += episodes.where((e) => e.status == EpisodeStatus.visto).length;
      }

      return {
        'seriesName': series.name,
        'totalEpisodes': totalEpisodes,
        'watchedEpisodes': watchedEpisodes,
        'progressPercentage': totalEpisodes > 0 ? (watchedEpisodes / totalEpisodes * 100).round() : 0,
        'currentSeason': series.currentSeason,
        'currentEpisode': series.currentEpisode,
      };
    } catch (e) {
      print('Error obteniendo progreso de la serie: $e');
      return {};
    }
  }

  // Alternar episodios automáticamente entre series respetando display_order
  static List<EpisodeLogEntry> _alternateEpisodes(List<EpisodeLogEntry> episodes) {
    if (episodes.isEmpty) return episodes;

    // Agrupar episodios por serie ID (más seguro que por nombre)
    final Map<int, List<EpisodeLogEntry>> seriesGroups = {};
    final Map<int, int> seriesOrderMap = {}; // Para preservar el orden
    final Map<int, String> seriesNameMap = {}; // Para preservar el nombre
    
    for (final episode in episodes) {
      final seriesId = episode.seriesId;
      if (!seriesGroups.containsKey(seriesId)) {
        seriesGroups[seriesId] = [];
        seriesOrderMap[seriesId] = episode.seriesDisplayOrder;
        seriesNameMap[seriesId] = episode.seriesName;
      }
      seriesGroups[seriesId]!.add(episode);
    }

    // Ordenar las series por display_order (y luego por ID si hay empate)
    final sortedSeriesIds = seriesGroups.keys.toList()
      ..sort((a, b) {
        final orderA = seriesOrderMap[a] ?? 0;
        final orderB = seriesOrderMap[b] ?? 0;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        return a.compareTo(b); // Si hay empate, usar ID
      });
    
    // Obtener listas de episodios por serie en el orden correcto
    // Asegurarse de que cada lista esté ordenada por temporada y episodio
    final List<List<EpisodeLogEntry>> seriesLists = sortedSeriesIds.map((seriesId) {
      final list = List<EpisodeLogEntry>.from(seriesGroups[seriesId]!);
      list.sort((a, b) {
        final seasonCmp = a.seasonNumber.compareTo(b.seasonNumber);
        if (seasonCmp != 0) return seasonCmp;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });
      return list;
    }).toList();
    
    // Alternar episodios: un capítulo de cada serie en orden, luego el siguiente de cada serie, etc.
    final List<EpisodeLogEntry> alternatedEpisodes = [];
    
    if (seriesLists.isEmpty) return episodes;
    
    // Encontrar la longitud máxima
    int maxLength = 0;
    for (final list in seriesLists) {
      if (list.length > maxLength) {
        maxLength = list.length;
      }
    }
    
    // Intercalar episodios
    for (int i = 0; i < maxLength; i++) {
      for (final seriesList in seriesLists) {
        if (i < seriesList.length) {
          alternatedEpisodes.add(seriesList[i]);
        }
      }
    }

    return alternatedEpisodes;
  }

  // Intercalar por tomos (lectura): mostrar todos los capítulos de un tomo, luego
  // pasar al siguiente tomo de la siguiente serie respetando display_order.
  static List<EpisodeLogEntry> _alternateByVolumes(List<EpisodeLogEntry> episodes) {
    if (episodes.isEmpty) return episodes;

    // Agrupar por serie
    final Map<int, List<EpisodeLogEntry>> seriesGroups = {};
    final Map<int, int> seriesOrderMap = {};
    for (final e in episodes) {
      if (!seriesGroups.containsKey(e.seriesId)) {
        seriesGroups[e.seriesId] = [];
        seriesOrderMap[e.seriesId] = e.seriesDisplayOrder;
      }
      seriesGroups[e.seriesId]!.add(e);
    }

    // Ordenar cada serie por (seasonNumber asc, episodeNumber asc)
    for (final list in seriesGroups.values) {
      list.sort((a, b) {
        final s = a.seasonNumber.compareTo(b.seasonNumber);
        if (s != 0) return s;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });
    }

    // Para cada serie, agrupar a su vez por seasonNumber conservando el orden
    final Map<int, List<List<EpisodeLogEntry>>> seriesToVolumes = {};
    for (final entry in seriesGroups.entries) {
      final Map<int, List<EpisodeLogEntry>> bySeason = {};
      for (final ep in entry.value) {
        bySeason.putIfAbsent(ep.seasonNumber, () => []).add(ep);
      }
      final volumeLists = bySeason.keys.toList()
        ..sort();
      seriesToVolumes[entry.key] = volumeLists.map((sn) => bySeason[sn]!).toList();
    }

    // Orden de series por display_order, luego ID
    final sortedSeriesIds = seriesToVolumes.keys.toList()
      ..sort((a, b) {
        final oa = seriesOrderMap[a] ?? 0;
        final ob = seriesOrderMap[b] ?? 0;
        if (oa != ob) return oa.compareTo(ob);
        return a.compareTo(b);
      });

    // Round-robin por volumen (tomo): de cada serie, tomar la lista completa de capítulos del siguiente tomo
    final List<EpisodeLogEntry> result = [];
    int round = 0;
    while (true) {
      bool addedInThisRound = false;
      for (final seriesId in sortedSeriesIds) {
        final volumes = seriesToVolumes[seriesId]!;
        if (round < volumes.length) {
          result.addAll(volumes[round]);
          addedInThisRound = true;
        }
      }
      if (!addedInThisRound) break;
      round++;
    }

    return result;
  }
}