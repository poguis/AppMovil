import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import 'database_service.dart';

class CategoryService {
  // Obtener todas las categorías por tipo
  static Future<List<Category>> getCategoriesByType(String type, {int? userId}) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'categories',
      where: 'type = ? AND (user_id = ? OR user_id IS NULL OR is_default = 1)',
      whereArgs: [type, userId],
      orderBy: 'is_default DESC, name ASC',
    );

    return result.map((map) => Category.fromMap(map)).toList();
  }

  // Obtener todas las categorías
  static Future<List<Category>> getAllCategories({int? userId}) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'categories',
      where: 'user_id = ? OR user_id IS NULL OR is_default = 1',
      whereArgs: [userId],
      orderBy: 'type ASC, is_default DESC, name ASC',
    );

    return result.map((map) => Category.fromMap(map)).toList();
  }

  // Crear nueva categoría
  static Future<int> createCategory(Category category) async {
    final db = await DatabaseService.database;
    return await db.insert('categories', category.toMap());
  }

  // Verificar si la categoría existe
  static Future<bool> categoryExists(String name, String type, {int? userId}) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'categories',
      where: 'name = ? AND type = ? AND (user_id = ? OR user_id IS NULL)',
      whereArgs: [name, type, userId],
    );
    return result.isNotEmpty;
  }

  // Obtener categoría por ID
  static Future<Category?> getCategoryById(int id) async {
    final db = await DatabaseService.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return Category.fromMap(result.first);
    }
    return null;
  }

  // Eliminar categoría personalizada
  static Future<void> deleteCategory(int id) async {
    final db = await DatabaseService.database;
    await db.delete(
      'categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }
}
