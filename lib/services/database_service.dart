import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'app_database.db';
  static const int _databaseVersion = 5;

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
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
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
