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
        version: 8,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
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
        company_id INTEGER,
        price_usd REAL DEFAULT 0,
        source TEXT,
        form TEXT,
        notes TEXT
      )
    ''');

    // Create optimized indexes for medicines table
    await db.execute('''
      CREATE INDEX idx_medicine_name ON medicines(name)
    ''');
    await db.execute('''
      CREATE INDEX idx_medicine_company ON medicines(company_id)
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
        qty INTEGER,
        price REAL DEFAULT 0,
        is_gift INTEGER NOT NULL DEFAULT 0,
        gift_qty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create optimized indexes for medicines table (duplicate removal)
    // Indexes are already created above, this is just for migration compatibility

    // Create index for orders table (for date filtering)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add indexes for existing databases
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_medicine_name ON medicines(name)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_medicine_company ON medicines(company_id)
        ''');
      } catch (e) {
        // Indexes might already exist, ignore error
      }
    }
    if (oldVersion < 3) {
      // Add index for orders date filtering
      try {
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(created_at)
        ''');
      } catch (e) {
        // Index might already exist, ignore error
      }
    }
    if (oldVersion < 4) {
      // Recreate indexes with optimized names (if they don't exist)
      try {
        // Drop old indexes if they exist
        await db.execute('DROP INDEX IF EXISTS idx_medicines_name');
        await db.execute('DROP INDEX IF EXISTS idx_medicines_company_id');

        // Create new optimized indexes
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_medicine_name ON medicines(name)
        ''');
        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_medicine_company ON medicines(company_id)
        ''');
      } catch (e) {
        // Indexes might already exist, ignore error
      }
    }
    if (oldVersion < 5) {
      // Add price_usd column to medicines table
      try {
        await db.execute('''
          ALTER TABLE medicines ADD COLUMN price_usd REAL DEFAULT 0
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
      // Add price column to order_items table
      try {
        await db.execute('''
          ALTER TABLE order_items ADD COLUMN price REAL DEFAULT 0
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 6) {
      // Add source, form, and notes columns to medicines table
      try {
        await db.execute('''
          ALTER TABLE medicines ADD COLUMN source TEXT
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute('''
          ALTER TABLE medicines ADD COLUMN form TEXT
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute('''
          ALTER TABLE medicines ADD COLUMN notes TEXT
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 7) {
      // Add is_gift column to order_items table
      try {
        await db.execute('''
          ALTER TABLE order_items ADD COLUMN is_gift INTEGER NOT NULL DEFAULT 0
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 8) {
      // Add gift_qty column to order_items table
      try {
        await db.execute('''
          ALTER TABLE order_items ADD COLUMN gift_qty INTEGER NOT NULL DEFAULT 0
        ''');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
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

  /// Fetches order items with medicine and company details for PDF export
  /// Returns list of items with all necessary fields for PDF generation
  Future<List<Map<String, dynamic>>> fetchOrderItemsWithDetails(
      int orderId) async {
    final db = await database;

    // Query order items with joined medicine and company data
    final itemMaps = await db.rawQuery('''
      SELECT 
        order_items.id,
        order_items.order_id,
        order_items.medicine_id,
        order_items.qty,
        CASE 
          WHEN order_items.is_gift = 1 THEN 0 
          ELSE COALESCE(medicines.price_usd, order_items.price, 0) 
        END as price_usd,
        order_items.price as price,
        order_items.is_gift as is_gift,
        order_items.gift_qty as gift_qty,
        medicines.name as medicine_name,
        medicines.source as medicine_source,
        medicines.form as medicine_form,
        medicines.notes as medicine_notes,
        companies.name as company_name
      FROM order_items
      LEFT JOIN medicines ON order_items.medicine_id = medicines.id
      LEFT JOIN companies ON medicines.company_id = companies.id
      WHERE order_items.order_id = ?
      ORDER BY medicines.name
    ''', [orderId]);

    return itemMaps;
  }
}
