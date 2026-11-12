import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  static Database? _db;

  DBHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'closetmate.db');

    return await openDatabase(
      path,
      version: 7, // ✅ bumped to 7 to handle bagPath addition
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE outfits ADD COLUMN name TEXT');
        }

        if (oldVersion < 3) {
          await db.execute('ALTER TABLE items ADD COLUMN brand TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN size TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN price TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN tags TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN colors TEXT');
          await db.execute('ALTER TABLE items ADD COLUMN private INTEGER');
          await db.execute('ALTER TABLE items ADD COLUMN datePurchased TEXT');
        }

        if (oldVersion < 4) {
          await db.execute('ALTER TABLE items ADD COLUMN mainCategory TEXT');
        }

        if (oldVersion < 6) {
          // Recreate outfits table: headPath → accessoriesPath
          await db.execute('''
            CREATE TABLE new_outfits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              accessoriesPath TEXT,
              topPath TEXT,
              bottomPath TEXT,
              shoesPath TEXT,
              bagPath TEXT
            )
          ''');

          // Try migrating from old schema — headPath may or may not exist
          try {
            await db.execute('''
              INSERT INTO new_outfits (id, name, accessoriesPath, topPath, bottomPath, shoesPath)
              SELECT id, name, headPath, topPath, bottomPath, shoesPath FROM outfits
            ''');
          } catch (_) {
            // headPath didn't exist, try without it
            await db.execute('''
              INSERT INTO new_outfits (id, name, topPath, bottomPath, shoesPath)
              SELECT id, name, topPath, bottomPath, shoesPath FROM outfits
            ''');
          }

          await db.execute('DROP TABLE outfits');
          await db.execute('ALTER TABLE new_outfits RENAME TO outfits');
        }

        // ✅ Only add bagPath if upgrading from version 6 that didn't have it
        if (oldVersion == 6) {
          try {
            await db.execute('ALTER TABLE outfits ADD COLUMN bagPath TEXT');
          } catch (e) {
            print('⚠️ bagPath may already exist: $e');
          }
        }
      },
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT,
        username TEXT UNIQUE,
        email TEXT UNIQUE,
        password TEXT,
        gender TEXT,
        birthday TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT,
        category TEXT,
        mainCategory TEXT,
        brand TEXT,
        size TEXT,
        price TEXT,
        tags TEXT,
        colors TEXT,
        private INTEGER,
        datePurchased TEXT
      )
    ''');

    // ✅ Fresh installs get bagPath from the start
    await db.execute('''
      CREATE TABLE outfits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        accessoriesPath TEXT,
        topPath TEXT,
        bottomPath TEXT,
        shoesPath TEXT,
        bagPath TEXT
      )
    ''');

    // Seed sample data for new users
    await _seedSampleData(db);
  }

  /// Seeds the database with sample items and outfits for demonstration
  Future<void> _seedSampleData(Database db) async {
    // Sample items - using placeholder image paths
    final sampleItems = [
      {
        'imagePath': '',
        'category': 'T-shirt',
        'mainCategory': 'Tops',
        'brand': 'White Cotton Tee',
        'size': 'M',
        'price': '29.99',
        'tags': 'casual,everyday',
        'colors': 'white',
        'private': 0,
        'datePurchased': '2024-01-15',
      },
      {
        'imagePath': '',
        'category': 'Hoodie',
        'mainCategory': 'Tops',
        'brand': 'Black Oversized Hoodie',
        'size': 'L',
        'price': '59.99',
        'tags': 'comfort,winter',
        'colors': 'black',
        'private': 0,
        'datePurchased': '2023-11-20',
      },
      {
        'imagePath': '',
        'category': 'Jeans',
        'mainCategory': 'Bottoms',
        'brand': 'Blue Straight Jeans',
        'size': '32',
        'price': '79.99',
        'tags': 'denim,classic',
        'colors': 'blue',
        'private': 0,
        'datePurchased': '2024-02-10',
      },
      {
        'imagePath': '',
        'category': 'Trouser',
        'mainCategory': 'Bottoms',
        'brand': 'Beige Chino Pants',
        'size': '32',
        'price': '49.99',
        'tags': 'formal,work',
        'colors': 'beige',
        'private': 0,
        'datePurchased': '2024-03-05',
      },
      {
        'imagePath': '',
        'category': 'Sport Shoes',
        'mainCategory': 'Footwear',
        'brand': 'White Sneakers',
        'size': '42',
        'price': '129.99',
        'tags': 'running,casual',
        'colors': 'white',
        'private': 0,
        'datePurchased': '2024-01-20',
      },
      {
        'imagePath': '',
        'category': 'Boots',
        'mainCategory': 'Footwear',
        'brand': 'Brown Leather Boots',
        'size': '42',
        'price': '189.99',
        'tags': 'winter,formal',
        'colors': 'brown',
        'private': 0,
        'datePurchased': '2023-12-01',
      },
      {
        'imagePath': '',
        'category': 'Scarves',
        'mainCategory': 'Accessories',
        'brand': 'Patterned Silk Scarf',
        'size': 'One Size',
        'price': '39.99',
        'tags': 'accessory,formal',
        'colors': 'multi',
        'private': 0,
        'datePurchased': '2024-02-14',
      },
      {
        'imagePath': '',
        'category': 'Ties',
        'mainCategory': 'Accessories',
        'brand': 'Navy Blue Tie',
        'size': 'One Size',
        'price': '24.99',
        'tags': 'formal,business',
        'colors': 'navy',
        'private': 0,
        'datePurchased': '2024-01-10',
      },
      {
        'imagePath': '',
        'category': 'Jackets',
        'mainCategory': 'Outerwear',
        'brand': 'Denim Jacket',
        'size': 'M',
        'price': '89.99',
        'tags': 'casual,spring',
        'colors': 'blue',
        'private': 0,
        'datePurchased': '2024-03-15',
      },
    ];

    for (final item in sampleItems) {
      await db.insert('items', item);
    }

    // Sample outfits
    final sampleOutfits = [
      {
        'name': 'Casual Weekend',
        'accessoriesPath': '',
        'topPath': '',
        'bottomPath': '',
        'shoesPath': '',
        'bagPath': '',
      },
      {
        'name': 'Office Ready',
        'accessoriesPath': '',
        'topPath': '',
        'bottomPath': '',
        'shoesPath': '',
        'bagPath': '',
      },
      {
        'name': 'Evening Out',
        'accessoriesPath': '',
        'topPath': '',
        'bottomPath': '',
        'shoesPath': '',
        'bagPath': '',
      },
    ];

    for (final outfit in sampleOutfits) {
      await db.insert('outfits', outfit);
    }

    print('✅ Sample data seeded successfully');
  }

  /// Public method to seed sample data if database is empty
  Future<void> seedSampleDataIfEmpty() async {
    final db = await database;
    final itemCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM items'),
        ) ??
        0;

    if (itemCount == 0) {
      await _seedSampleData(db);
    }
  }

  // 👕 ITEMS METHODS
  Future<int> addItem(Map<String, dynamic> item) async {
    try {
      final db = await database;
      return await db.insert('items', item);
    } catch (e) {
      print("❌ Failed to insert item: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    return await db.query('items');
  }

  Future<void> clearAllItems() async {
    final db = await database;
    await db.delete('items');
    print("🧺 All wardrobe items cleared");
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateItem(Map<String, dynamic> item) async {
    try {
      final db = await database;
      final id = item['id'];
      final itemToUpdate = Map<String, dynamic>.from(item)..remove('id');

      final result = await db.update(
        'items',
        itemToUpdate,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result == 0) {
        print("❌ No item found with id: $id");
      } else {
        print("✅ Item updated successfully: $id");
      }
    } catch (e) {
      print("❌ Failed to update item: $e");
      rethrow;
    }
  }

  // 🧥 OUTFIT METHODS
  Future<int> addOutfit(Map<String, dynamic> outfit) async {
    final db = await database;
    return await db.insert('outfits', outfit);
  }

  Future<int> updateOutfit(int id, Map<String, dynamic> outfit) async {
    final db = await database;
    return await db.update('outfits', outfit, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllOutfits() async {
    final db = await database;
    return await db.query('outfits');
  }

  Future<void> clearAllOutfits() async {
    final db = await database;
    await db.delete('outfits');
    print("🧺 All outfits cleared");
  }

  Future<int> deleteOutfit(int id) async {
    final db = await database;
    return await db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }

  // 📊 COUNTS
  Future<int> getItemCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM items'),
        ) ??
        0;
  }

  Future<int> getOutfitCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM outfits'),
        ) ??
        0;
  }
}