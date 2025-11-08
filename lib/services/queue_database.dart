import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/queue_item.dart';

/// Database service voor queue opslag
class QueueDatabase {
  static final QueueDatabase _instance = QueueDatabase._internal();
  factory QueueDatabase() => _instance;
  QueueDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'claudine_queue.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE queue_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        command TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        processed_at TEXT,
        result TEXT,
        error TEXT,
        metadata TEXT
      )
    ''');

    // Index voor snellere queries
    await db.execute('''
      CREATE INDEX idx_status ON queue_items(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_at ON queue_items(created_at)
    ''');
  }

  /// Voeg queue item toe
  Future<int> insert(QueueItem item) async {
    final db = await database;
    return await db.insert('queue_items', item.toMap());
  }

  /// Update queue item
  Future<int> update(QueueItem item) async {
    final db = await database;
    return await db.update(
      'queue_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Verwijder queue item
  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      'queue_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Haal alle queue items op (FIFO - First In First Out)
  Future<List<QueueItem>> getAllItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'queue_items',
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => QueueItem.fromMap(map)).toList();
  }

  /// Haal items op met specifieke status
  Future<List<QueueItem>> getItemsByStatus(QueueItemStatus status) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'queue_items',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => QueueItem.fromMap(map)).toList();
  }

  /// Haal pending items op (om te verwerken)
  Future<List<QueueItem>> getPendingItems() async {
    return getItemsByStatus(QueueItemStatus.pending);
  }

  /// Tel items per status
  Future<int> countByStatus(QueueItemStatus status) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM queue_items WHERE status = ?',
      [status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Tel totaal aantal pending en processing items
  Future<int> countActiveItems() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM queue_items WHERE status IN (?, ?)',
      [QueueItemStatus.pending.name, QueueItemStatus.processing.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Verwijder oude voltooide/gefaalde items (ouder dan X dagen)
  Future<int> cleanupOldItems({int daysToKeep = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      'queue_items',
      where: 'status IN (?, ?) AND created_at < ?',
      whereArgs: [
        QueueItemStatus.completed.name,
        QueueItemStatus.failed.name,
        cutoffDate.toIso8601String(),
      ],
    );
  }

  /// Haal een specifiek item op
  Future<QueueItem?> getItem(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'queue_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return QueueItem.fromMap(maps.first);
  }

  /// Reset database (alleen voor development/debugging)
  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('queue_items');
  }

  /// Sluit database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
