import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('appDatabase.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path = join(await getDatabasesPath(), filePath);
    return await openDatabase(
      path,
      version: 3, // incrementar si agregamos tablas o columnas nuevas
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Agregamos username si se requiere
          await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
        }
        if (oldVersion < 3) {
          // Crear tablas nuevas para el módulo de dinero
          await db.execute('''
            CREATE TABLE user_money (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              amount REAL NOT NULL,
              updated_at TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              name TEXT NOT NULL,
              type TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE persons (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              name TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE debts_loans (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              person_id INTEGER,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              description TEXT,
              created_at TEXT,
              FOREIGN KEY(person_id) REFERENCES persons(id)
            )
          ''');

          await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT,
              category_id INTEGER,
              person_id INTEGER,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              description TEXT,
              created_at TEXT,
              FOREIGN KEY(category_id) REFERENCES categories(id),
              FOREIGN KEY(person_id) REFERENCES persons(id)
            )
          ''');
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla de usuarios
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    // Tablas del módulo de dinero
    await db.execute('''
      CREATE TABLE user_money (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        amount REAL NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        person_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        created_at TEXT,
        FOREIGN KEY(person_id) REFERENCES persons(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        category_id INTEGER,
        person_id INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        created_at TEXT,
        FOREIGN KEY(category_id) REFERENCES categories(id),
        FOREIGN KEY(person_id) REFERENCES persons(id)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
