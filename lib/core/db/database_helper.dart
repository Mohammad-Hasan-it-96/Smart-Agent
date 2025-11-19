import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_agent.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create companies table
    await db.execute('''
      CREATE TABLE companies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT
      )
    ''');

    // Create medicines table
    await db.execute('''
      CREATE TABLE medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        company_id INTEGER
      )
    ''');

    // Create pharmacies table
    await db.execute('''
      CREATE TABLE pharmacies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        address TEXT,
        phone TEXT
      )
    ''');

    // Create orders table
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pharmacy_id INTEGER,
        created_at TEXT
      )
    ''');

    // Create order_items table
    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        medicine_id INTEGER,
        qty INTEGER
      )
    ''');
  }

  Future<Database> openDatabase() async {
    return await database;
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
