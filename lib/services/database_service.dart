import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'app_database.db';
  static const int _databaseVersion = 1;

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

  // Actualizar base de datos
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Aquí se pueden agregar migraciones futuras
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
