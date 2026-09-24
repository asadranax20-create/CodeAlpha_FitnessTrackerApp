import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

// ==========================================
// 1. ACTIVITY MODEL
// ==========================================
class ActivityModel {
  final int? id;
  final String activityType;
  final int duration;
  final int steps;
  final double calories;
  final String date;
  final String createdAt;

  const ActivityModel({
    this.id,
    required this.activityType,
    required this.duration,
    required this.steps,
    required this.calories,
    required this.date,
    required this.createdAt,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      id: map['id'] as int?,
      activityType: map['activityType'] as String? ?? 'Walking',
      duration: map['duration'] as int? ?? 0,
      steps: map['steps'] as int? ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] as String? ?? '',
      createdAt: map['createdAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'activityType': activityType,
      'duration': duration,
      'steps': steps,
      'calories': calories,
      'date': date,
      'createdAt': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}

// ==========================================
// 2. GOAL MODEL
// ==========================================
class GoalModel {
  final int? id;
  final int stepsGoal;
  final double caloriesGoal;
  final int workoutGoal;

  const GoalModel({
    this.id,
    required this.stepsGoal,
    required this.caloriesGoal,
    required this.workoutGoal,
  });

  factory GoalModel.defaultGoals() {
    return const GoalModel(
      id: 1,
      stepsGoal: 10000,
      caloriesGoal: 500.0,
      workoutGoal: 60,
    );
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as int?,
      stepsGoal: map['stepsGoal'] as int? ?? 10000,
      caloriesGoal: (map['caloriesGoal'] as num?)?.toDouble() ?? 500.0,
      workoutGoal: map['workoutGoal'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'stepsGoal': stepsGoal,
      'caloriesGoal': caloriesGoal,
      'workoutGoal': workoutGoal,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  GoalModel copyWith({
    int? id,
    int? stepsGoal,
    double? caloriesGoal,
    int? workoutGoal,
  }) {
    return GoalModel(
      id: id ?? this.id,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      caloriesGoal: caloriesGoal ?? this.caloriesGoal,
      workoutGoal: workoutGoal ?? this.workoutGoal,
    );
  }
}

// ==========================================
// 3. DATABASE HELPER
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static Future<Database>? _initFuture;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _initFuture ??= _initDatabase();
    _database = await _initFuture;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'fittrack.db');

      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onOpen: (db) async {
          await _createSchema(db);
        },
      );
    } catch (e) {
      debugPrint('[FitTrack DB Error] initDatabase: $e');
      rethrow;
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityType TEXT NOT NULL,
        duration INTEGER NOT NULL,
        steps INTEGER NOT NULL,
        calories REAL NOT NULL,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stepsGoal INTEGER NOT NULL,
        caloriesGoal REAL NOT NULL,
        workoutGoal INTEGER NOT NULL
      )
    ''');

    // Default goals row if not present
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM goals'),
    );
    if (count == null || count == 0) {
      await db.insert('goals', {
        'id': 1,
        'stepsGoal': 10000,
        'caloriesGoal': 500.0,
        'workoutGoal': 60,
      });
    }
  }

  Future<int> insertActivity(ActivityModel activity) async {
    try {
      final db = await database;
      return await db.insert(
        'activities',
        activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[FitTrack DB] Insert error: $e');
      return -1;
    }
  }

  Future<List<ActivityModel>> getAllActivities() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'activities',
        orderBy: 'date DESC, createdAt DESC',
      );
      return maps.map((m) => ActivityModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[FitTrack DB] Fetch error: $e');
      return [];
    }
  }

  Future<int> deleteActivity(int id) async {
    try {
      final db = await database;
      return await db.delete('activities', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      return 0;
    }
  }

  Future<int> deleteAllActivities() async {
    try {
      final db = await database;
      return await db.delete('activities');
    } catch (e) {
      return 0;
    }
  }

  Future<GoalModel> getGoals() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'goals',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return GoalModel.fromMap(maps.first);
      }
    } catch (_) {}
    return GoalModel.defaultGoals();
  }

  Future<int> updateGoals(GoalModel goal) async {
    try {
      final db = await database;
      return await db.update(
        'goals',
        goal.toMap(),
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (_) {
      return 0;
    }
  }
}
