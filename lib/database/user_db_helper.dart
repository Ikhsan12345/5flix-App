import 'package:sqflite/sqflite.dart';
import 'package:five_flix/models/user_model.dart';

class UserDbHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      'userdb.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE,
          password TEXT
        )
        ''');
      },
    );
    return _db!;
  }

  static Future<int> insertUser(UserModel user) async {
    final dbClient = await db;
    return await dbClient.insert('users', user.toMap());
  }

  static Future<UserModel?> getUser(String username, String password) async {
    final dbClient = await db;
    final res = await dbClient.query('users',
        where: 'username = ? AND password = ?', whereArgs: [username, password]);
    if (res.isNotEmpty) {
      return UserModel.fromMap(res.first);
    }
    return null;
  }
}
