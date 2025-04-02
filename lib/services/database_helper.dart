class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('snap2done.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mood_entries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        mood TEXT NOT NULL,
        moodNotes TEXT,
        gratitudeItems TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE mood_gratitude_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remindersEnabled INTEGER NOT NULL DEFAULT 0,
        reminderTime TEXT NOT NULL,
        maxGratitudeItems INTEGER NOT NULL DEFAULT 3,
        favoriteMoods TEXT NOT NULL,
        notificationEnabled INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here
  }
} 