import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'app_database.db';
  static const int _databaseVersion = 12;

  // Obtener la instancia de la base de datos
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inicializar la base de datos
  static Future<Database> _initDatabase() async {
    // En web, usar una base de datos en memoria
    if (kIsWeb) {
      return await openDatabase(
        ':memory:',
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
    
    // En móvil, usar archivo físico
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Crear las tablas
  static Future<void> _onCreate(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        email TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de dinero actual
    await db.execute('''
      CREATE TABLE money_balance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER UNIQUE NOT NULL,
        amount REAL NOT NULL DEFAULT 0.0,
        last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabla de categorías
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT DEFAULT '#2196F3',
        icon TEXT DEFAULT 'category',
        is_default INTEGER DEFAULT 0,
        user_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabla de transacciones
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id INTEGER,
        description TEXT,
        date DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Tabla de deudas y préstamos
    await db.execute('''
      CREATE TABLE debts_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        person_name TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        date_created DATETIME DEFAULT CURRENT_TIMESTAMP,
        date_due DATETIME,
        is_paid INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // Tabla de categorías de Series/Anime
    await db.execute('''
      CREATE TABLE series_anime_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('video', 'lectura')),
        description TEXT,
        start_date DATETIME NOT NULL,
        selected_days TEXT NOT NULL,
        frequency INTEGER NOT NULL DEFAULT 1,
        number_of_series INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabla de registros de video
    await db.execute('''
      CREATE TABLE video_tracking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        start_date DATETIME NOT NULL,
        selected_days TEXT NOT NULL,
        frequency TEXT NOT NULL,
        description TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES series_anime_categories (id)
      )
    ''');

    // Tabla de series
    await db.execute('''
      CREATE TABLE series (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'nueva',
        current_season INTEGER NOT NULL DEFAULT 1,
        current_episode INTEGER NOT NULL DEFAULT 1,
        start_watching_date TEXT,
        finish_watching_date TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES series_anime_categories (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de temporadas
    await db.execute('''
      CREATE TABLE seasons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        series_id INTEGER NOT NULL,
        season_number INTEGER NOT NULL,
        title TEXT,
        total_episodes INTEGER NOT NULL DEFAULT 0,
        watched_episodes INTEGER NOT NULL DEFAULT 0,
        release_date TEXT,
        finish_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (series_id) REFERENCES series (id) ON DELETE CASCADE,
        UNIQUE(series_id, season_number)
      )
    ''');

    // Tabla de capítulos
    await db.execute('''
      CREATE TABLE episodes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        season_id INTEGER NOT NULL,
        episode_number INTEGER NOT NULL,
        title TEXT,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'noVisto',
        duration INTEGER,
        watch_progress REAL,
        watch_date TEXT,
        rating INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (season_id) REFERENCES seasons (id) ON DELETE CASCADE,
        UNIQUE(season_id, episode_number)
      )
    ''');

    // Tabla de items pendientes (películas, series, anime)
    await db.execute('''
      CREATE TABLE pending_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK (type IN ('pelicula', 'serie', 'anime')),
        title TEXT NOT NULL,
        year INTEGER,
        start_year INTEGER,
        end_year INTEGER,
        is_ongoing INTEGER NOT NULL DEFAULT 0,
        series_format TEXT CHECK (series_format IN ('format24min', 'format40min')),
        status TEXT NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente', 'mirando', 'visto')),
        watched_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Insertar categorías por defecto
    await _insertDefaultCategories(db);
  }

  // Insertar categorías por defecto
  static Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      // Categorías base para agregar dinero (income)
      {'name': 'Me deben', 'type': 'income', 'color': '#4CAF50', 'icon': 'account_balance_wallet', 'is_default': 1},
      {'name': 'Préstamos', 'type': 'income', 'color': '#FF9800', 'icon': 'money', 'is_default': 1},
      
      // Categorías base para quitar dinero (expense)  
      {'name': 'Préstamo', 'type': 'expense', 'color': '#FF9800', 'icon': 'money', 'is_default': 1},
      {'name': 'Me deben', 'type': 'expense', 'color': '#4CAF50', 'icon': 'account_balance_wallet', 'is_default': 1},
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category);
    }
  }

  // Verificar si una tabla existe
  static Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName]
    );
    return result.isNotEmpty;
  }

  // Actualizar base de datos
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar tabla de categorías de Series/Anime
      final tableExists = await _tableExists(db, 'series_anime_categories');
      if (!tableExists) {
        await db.execute('''
          CREATE TABLE series_anime_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('video', 'lectura')),
            description TEXT,
            start_date DATETIME NOT NULL,
            selected_days TEXT NOT NULL,
            frequency INTEGER NOT NULL DEFAULT 1,
            number_of_series INTEGER NOT NULL DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        print('Tabla series_anime_categories creada exitosamente');
      } else {
        print('Tabla series_anime_categories ya existe, saltando creación');
      }
    }
    
    if (oldVersion < 3) {
      // Agregar tabla de registros de video
      final tableExists = await _tableExists(db, 'video_tracking');
      if (!tableExists) {
        await db.execute('''
          CREATE TABLE video_tracking (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            start_date DATETIME NOT NULL,
            selected_days TEXT NOT NULL,
            frequency TEXT NOT NULL,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (category_id) REFERENCES series_anime_categories (id)
          )
        ''');
        print('Tabla video_tracking creada exitosamente');
      } else {
        print('Tabla video_tracking ya existe, saltando creación');
      }
    }
    
    if (oldVersion < 4) {
      // Actualizar tabla de categorías de Series/Anime con nuevos campos
      try {
        await db.execute('ALTER TABLE series_anime_categories ADD COLUMN start_date DATETIME');
        await db.execute('ALTER TABLE series_anime_categories ADD COLUMN selected_days TEXT');
        await db.execute('ALTER TABLE series_anime_categories ADD COLUMN frequency INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE series_anime_categories ADD COLUMN number_of_series INTEGER DEFAULT 1');
        print('Tabla series_anime_categories actualizada con nuevos campos');
      } catch (e) {
        print('Error actualizando tabla series_anime_categories: $e');
      }
    }
    
    if (oldVersion < 5) {
      // Agregar tablas de series, temporadas y capítulos
      final seriesExists = await _tableExists(db, 'series');
      if (!seriesExists) {
        await db.execute('''
          CREATE TABLE series (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            status TEXT NOT NULL DEFAULT 'nueva',
            current_season INTEGER NOT NULL DEFAULT 1,
            current_episode INTEGER NOT NULL DEFAULT 1,
            start_watching_date TEXT,
            finish_watching_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (category_id) REFERENCES series_anime_categories (id) ON DELETE CASCADE
          )
        ''');
        print('Tabla series creada exitosamente');
      }

      final seasonsExists = await _tableExists(db, 'seasons');
      if (!seasonsExists) {
        await db.execute('''
          CREATE TABLE seasons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            series_id INTEGER NOT NULL,
            season_number INTEGER NOT NULL,
            title TEXT,
            total_episodes INTEGER NOT NULL DEFAULT 0,
            watched_episodes INTEGER NOT NULL DEFAULT 0,
            release_date TEXT,
            finish_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (series_id) REFERENCES series (id) ON DELETE CASCADE,
            UNIQUE(series_id, season_number)
          )
        ''');
        print('Tabla seasons creada exitosamente');
      }

      final episodesExists = await _tableExists(db, 'episodes');
      if (!episodesExists) {
        await db.execute('''
          CREATE TABLE episodes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            season_id INTEGER NOT NULL,
            episode_number INTEGER NOT NULL,
            title TEXT,
            description TEXT,
            status TEXT NOT NULL DEFAULT 'noVisto',
            duration INTEGER,
            watch_progress REAL,
            watch_date TEXT,
            rating INTEGER,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (season_id) REFERENCES seasons (id) ON DELETE CASCADE,
            UNIQUE(season_id, episode_number)
          )
        ''');
        print('Tabla episodes creada exitosamente');
      }
    }

    if (oldVersion < 6) {
      // Agregar campo order a la tabla series
      try {
        await db.execute('ALTER TABLE series ADD COLUMN display_order INTEGER DEFAULT 0');
        print('Campo display_order agregado a la tabla series');
      } catch (e) {
        print('Error agregando campo display_order: $e');
      }
    }

    if (oldVersion < 7) {
      // Corregir tabla money_balance: eliminar duplicados y agregar constraint UNIQUE
      try {
        // Primero, eliminar posibles registros duplicados, manteniendo solo el más reciente
        final duplicates = await db.rawQuery('''
          SELECT user_id, MAX(last_updated) as max_date
          FROM money_balance
          GROUP BY user_id
          HAVING COUNT(*) > 1
        ''');

        for (var dup in duplicates) {
          final userId = dup['user_id'] as int;
          final maxDate = dup['max_date'] as String;
          
          // Eliminar todos los registros excepto el más reciente
          await db.rawDelete('''
            DELETE FROM money_balance 
            WHERE user_id = ? AND last_updated != ?
          ''', [userId, maxDate]);
        }

        // Recrear la tabla con la constraint UNIQUE correcta
        await db.execute('DROP TABLE IF EXISTS money_balance_backup');
        await db.execute('CREATE TABLE money_balance_backup AS SELECT * FROM money_balance');
        await db.execute('DROP TABLE money_balance');
        await db.execute('''
          CREATE TABLE money_balance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER UNIQUE NOT NULL,
            amount REAL NOT NULL DEFAULT 0.0,
            last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');
        await db.execute('INSERT INTO money_balance SELECT * FROM money_balance_backup');
        await db.execute('DROP TABLE money_balance_backup');
        
        print('Tabla money_balance actualizada con constraint UNIQUE');
      } catch (e) {
        print('Error actualizando tabla money_balance: $e');
      }
    }

    if (oldVersion < 8) {
      // Agregar categoría "Me deben" para expense (Quitar dinero)
      try {
        // Verificar si la categoría ya existe
        final existingCategory = await db.query(
          'categories',
          where: 'name = ? AND type = ?',
          whereArgs: ['Me deben', 'expense'],
        );

        if (existingCategory.isEmpty) {
          await db.insert('categories', {
            'name': 'Me deben',
            'type': 'expense',
            'color': '#4CAF50',
            'icon': 'account_balance_wallet',
            'is_default': 1,
          });
          print('Categoría "Me deben" para expense agregada exitosamente');
        } else {
          print('Categoría "Me deben" para expense ya existe, saltando creación');
        }
      } catch (e) {
        print('Error agregando categoría "Me deben" para expense: $e');
      }
    }

    if (oldVersion < 9) {
      // Asegurar columna display_order en tabla series
      try {
        await db.execute('ALTER TABLE series ADD COLUMN display_order INTEGER DEFAULT 0');
        print('Columna display_order agregada a la tabla series (v9)');
      } catch (e) {
        // Si ya existe, SQLite lanzará error; lo ignoramos de forma segura
        print('display_order ya existe o no se pudo agregar: $e');
      }
    }

    if (oldVersion < 10) {
      // Agregar tabla de items pendientes
      final tableExists = await _tableExists(db, 'pending_items');
      if (!tableExists) {
        await db.execute('''
          CREATE TABLE pending_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL CHECK (type IN ('pelicula', 'serie', 'anime')),
            title TEXT NOT NULL,
            year INTEGER,
            start_year INTEGER,
            end_year INTEGER,
            is_ongoing INTEGER NOT NULL DEFAULT 0,
            series_format TEXT CHECK (series_format IN ('format24min', 'format40min')),
            status TEXT NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente', 'mirando', 'visto')),
            watched_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        print('Tabla pending_items creada exitosamente');
      } else {
        print('Tabla pending_items ya existe, saltando creación');
      }
    }

    if (oldVersion < 11) {
      // Agregar columna series_format a la tabla pending_items
      try {
        await db.execute('ALTER TABLE pending_items ADD COLUMN series_format TEXT CHECK (series_format IN (\'format24min\', \'format40min\'))');
        print('Columna series_format agregada a la tabla pending_items');
      } catch (e) {
        // Si ya existe, SQLite lanzará error; lo ignoramos de forma segura
        print('series_format ya existe o no se pudo agregar: $e');
      }
    }

    if (oldVersion < 12) {
      // Migrar de start_date/end_date a start_year/end_year
      try {
        // Verificar si las columnas start_date y end_date existen
        final tableInfo = await db.rawQuery("PRAGMA table_info(pending_items)");
        final hasStartDate = tableInfo.any((col) => col['name'] == 'start_date');
        final hasStartYear = tableInfo.any((col) => col['name'] == 'start_year');
        
        if (hasStartDate && !hasStartYear) {
          // Agregar nuevas columnas
          await db.execute('ALTER TABLE pending_items ADD COLUMN start_year INTEGER');
          await db.execute('ALTER TABLE pending_items ADD COLUMN end_year INTEGER');
          
          // Migrar datos: extraer el año de las fechas existentes
          final items = await db.query('pending_items', 
            columns: ['id', 'start_date', 'end_date']);
          
          for (final item in items) {
            final id = item['id'] as int;
            int? startYear;
            int? endYear;
            
            if (item['start_date'] != null) {
              try {
                final date = DateTime.parse(item['start_date'] as String);
                startYear = date.year;
              } catch (e) {
                print('Error parseando start_date: $e');
              }
            }
            
            if (item['end_date'] != null) {
              try {
                final date = DateTime.parse(item['end_date'] as String);
                endYear = date.year;
              } catch (e) {
                print('Error parseando end_date: $e');
              }
            }
            
            await db.update('pending_items', 
              {'start_year': startYear, 'end_year': endYear},
              where: 'id = ?',
              whereArgs: [id]);
          }
          
          // Eliminar las columnas antiguas (SQLite no soporta DROP COLUMN directamente,
          // así que recreamos la tabla sin esas columnas)
          await db.execute('''
            CREATE TABLE pending_items_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL CHECK (type IN ('pelicula', 'serie', 'anime')),
              title TEXT NOT NULL,
              year INTEGER,
              start_year INTEGER,
              end_year INTEGER,
              is_ongoing INTEGER NOT NULL DEFAULT 0,
              series_format TEXT CHECK (series_format IN ('format24min', 'format40min')),
              status TEXT NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente', 'mirando', 'visto')),
              watched_date TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          
          await db.execute('''
            INSERT INTO pending_items_new 
            (id, type, title, year, start_year, end_year, is_ongoing, series_format, status, watched_date, created_at, updated_at)
            SELECT id, type, title, year, start_year, end_year, is_ongoing, series_format, status, watched_date, created_at, updated_at
            FROM pending_items
          ''');
          
          await db.execute('DROP TABLE pending_items');
          await db.execute('ALTER TABLE pending_items_new RENAME TO pending_items');
          
          print('Migración de start_date/end_date a start_year/end_year completada');
        } else if (!hasStartYear) {
          // Solo agregar las nuevas columnas si no existen
          await db.execute('ALTER TABLE pending_items ADD COLUMN start_year INTEGER');
          await db.execute('ALTER TABLE pending_items ADD COLUMN end_year INTEGER');
          print('Columnas start_year y end_year agregadas a la tabla pending_items');
        } else {
          print('Las columnas start_year y end_year ya existen');
        }
      } catch (e) {
        print('Error en migración de fechas a años: $e');
      }
    }
  }

  // Crear backup de la base de datos
  static Future<String> createBackup() async {
    if (kIsWeb) {
      // En web, no podemos hacer backup físico
      throw UnsupportedError('Backup no soportado en web');
    }
    
    final db = await database;
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupPath = join(documentsDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}.db');
    
    final dbPath = await getDatabasesPath();
    final originalPath = join(dbPath, _databaseName);
    
    await File(originalPath).copy(backupPath);
    return backupPath;
  }

  // Cerrar la base de datos
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
