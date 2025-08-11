import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:five_flix/models/download_model.dart';
import 'package:five_flix/models/video_model.dart';

class UserDbHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'five_flix.db');

    return await openDatabase(
      path,
      version: 2, // Updated version
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Users table (untuk offline caching)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password TEXT,
        role TEXT DEFAULT 'user',
        cached_at INTEGER,
        is_online_user INTEGER DEFAULT 0
      )
    ''');

    // Downloads table
    await db.execute('''
      CREATE TABLE downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        local_path TEXT NOT NULL,
        thumbnail_url TEXT,
        thumbnail_local_path TEXT,
        file_size INTEGER DEFAULT 0,
        downloaded_at INTEGER NOT NULL,
        genre TEXT,
        year INTEGER,
        duration INTEGER,
        description TEXT,
        is_featured INTEGER DEFAULT 0,
        download_status TEXT DEFAULT 'completed'
      )
    ''');

    // Offline videos cache (untuk metadata video yang pernah dilihat)
    await db.execute('''
      CREATE TABLE video_cache (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        genre TEXT,
        thumbnail_url TEXT,
        video_url TEXT,
        description TEXT,
        duration INTEGER,
        year INTEGER,
        is_featured INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');

    // User session untuk offline
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY,
        username TEXT,
        role TEXT,
        token TEXT,
        cached_at INTEGER,
        expires_at INTEGER
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns if upgrading from version 1
      await db.execute('ALTER TABLE users ADD COLUMN role TEXT DEFAULT "user"');
      await db.execute('ALTER TABLE users ADD COLUMN cached_at INTEGER');
      await db.execute('ALTER TABLE users ADD COLUMN is_online_user INTEGER DEFAULT 0');
      
      // Create new tables
      await _onCreate(db, newVersion);
    }
  }

  // === USER MANAGEMENT ===
  
  /// Cache user data untuk offline access
  static Future<void> cacheUserData(Map<String, dynamic> userData, String? token) async {
    final dbClient = await db;
    
    // Cache user session
    await dbClient.insert('user_session', {
      'id': 1, // Single session
      'username': userData['username'],
      'role': userData['role'] ?? 'user',
      'token': token,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'expires_at': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get cached user session untuk offline
  static Future<Map<String, dynamic>?> getCachedUserSession() async {
    final dbClient = await db;
    final result = await dbClient.query('user_session', where: 'id = 1');
    
    if (result.isNotEmpty) {
      final session = result.first;
      final expiresAt = session['expires_at'] as int;
      
      // Check if session expired
      if (DateTime.now().millisecondsSinceEpoch < expiresAt) {
        return {
          'username': session['username'],
          'role': session['role'],
          'token': session['token'],
        };
      } else {
        // Clean expired session
        await clearUserSession();
      }
    }
    return null;
  }

  /// Clear user session
  static Future<void> clearUserSession() async {
    final dbClient = await db;
    await dbClient.delete('user_session');
  }

  // === DOWNLOAD MANAGEMENT ===

  /// Save downloaded video
  static Future<int> saveDownload(DownloadModel download) async {
    final dbClient = await db;
    return await dbClient.insert('downloads', {
      'video_id': download.videoId,
      'title': download.title,
      'local_path': download.localPath,
      'thumbnail_url': download.thumbnailUrl,
      'file_size': download.fileSize,
      'downloaded_at': download.downloadedAt.millisecondsSinceEpoch,
    });
  }

  /// Save downloaded video with full metadata
  static Future<int> saveDownloadFromVideo(VideoModel video, String localPath, String? thumbnailLocalPath, int fileSize) async {
    final dbClient = await db;
    return await dbClient.insert('downloads', {
      'video_id': video.id,
      'title': video.title,
      'local_path': localPath,
      'thumbnail_url': video.thumbnailUrl,
      'thumbnail_local_path': thumbnailLocalPath,
      'file_size': fileSize,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      'genre': video.genre,
      'year': video.year,
      'duration': video.duration,
      'description': video.description,
      'is_featured': video.isFeatured ? 1 : 0,
      'download_status': 'completed',
    });
  }

  /// Get all downloaded videos
  static Future<List<VideoModel>> getDownloadedVideos() async {
    final dbClient = await db;
    final result = await dbClient.query(
      'downloads',
      where: 'download_status = ?',
      whereArgs: ['completed'],
      orderBy: 'downloaded_at DESC',
    );

    return result.map((row) => VideoModel(
      id: row['video_id'] as int,
      title: row['title'] as String,
      genre: row['genre'] as String? ?? 'Unknown',
      thumbnailUrl: row['thumbnail_local_path'] as String? ?? row['thumbnail_url'] as String,
      videoUrl: row['local_path'] as String, // Local file path
      description: row['description'] as String?,
      duration: row['duration'] as int? ?? 0,
      year: row['year'] as int? ?? 0,
      isFeatured: (row['is_featured'] as int? ?? 0) == 1,
    )).toList();
  }

  /// Check if video is downloaded
  static Future<bool> isVideoDownloaded(int videoId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'downloads',
      where: 'video_id = ? AND download_status = ?',
      whereArgs: [videoId, 'completed'],
    );
    return result.isNotEmpty;
  }

  /// Get download info for video
  static Future<Map<String, dynamic>?> getDownloadInfo(int videoId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'downloads',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Delete downloaded video
  static Future<void> deleteDownload(int videoId) async {
    final dbClient = await db;
    await dbClient.delete(
      'downloads',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  /// Get download progress (for ongoing downloads)
  static Future<double> getDownloadProgress(int videoId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      'downloads',
      where: 'video_id = ? AND download_status = ?',
      whereArgs: [videoId, 'downloading'],
    );
    
    if (result.isNotEmpty) {
      // Return progress from 0.0 to 1.0
      return (result.first['progress'] as double? ?? 0.0);
    }
    return 0.0;
  }

  /// Update download progress
  static Future<void> updateDownloadProgress(int videoId, double progress) async {
    final dbClient = await db;
    await dbClient.update(
      'downloads',
      {'progress': progress},
      where: 'video_id = ? AND download_status = ?',
      whereArgs: [videoId, 'downloading'],
    );
  }

  // === VIDEO CACHE MANAGEMENT ===

  /// Cache video metadata untuk offline browsing
  static Future<void> cacheVideoMetadata(List<VideoModel> videos) async {
    final dbClient = await db;
    final batch = dbClient.batch();

    for (final video in videos) {
      batch.insert('video_cache', {
        'id': video.id,
        'title': video.title,
        'genre': video.genre,
        'thumbnail_url': video.thumbnailUrl,
        'video_url': video.videoUrl,
        'description': video.description,
        'duration': video.duration,
        'year': video.year,
        'is_featured': video.isFeatured ? 1 : 0,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit();
  }

  /// Get cached video metadata
  static Future<List<VideoModel>> getCachedVideos() async {
    final dbClient = await db;
    final result = await dbClient.query(
      'video_cache',
      orderBy: 'cached_at DESC',
    );

    return result.map((row) => VideoModel(
      id: row['id'] as int,
      title: row['title'] as String,
      genre: row['genre'] as String,
      thumbnailUrl: row['thumbnail_url'] as String,
      videoUrl: row['video_url'] as String,
      description: row['description'] as String?,
      duration: row['duration'] as int,
      year: row['year'] as int,
      isFeatured: (row['is_featured'] as int) == 1,
    )).toList();
  }

  /// Clear old cached videos (older than 30 days)
  static Future<void> clearOldCache() async {
    final dbClient = await db;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    
    await dbClient.delete(
      'video_cache',
      where: 'cached_at < ?',
      whereArgs: [thirtyDaysAgo],
    );
  }

  // === UTILITY METHODS ===

  /// Check if user is offline
  static Future<bool> isOfflineMode() async {
    // Simple network check - bisa diperbaiki dengan connectivity package
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isEmpty || result[0].rawAddress.isEmpty;
    } catch (e) {
      return true; // Assume offline if check fails
    }
  }

  /// Get database info
  static Future<Map<String, int>> getDatabaseStats() async {
    final dbClient = await db;
    
    final downloadsCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM downloads');
    final cacheCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM video_cache');
    final sessionCount = await dbClient.rawQuery('SELECT COUNT(*) as count FROM user_session');
    
    return {
      'downloads': downloadsCount.first['count'] as int,
      'cached_videos': cacheCount.first['count'] as int,
      'active_sessions': sessionCount.first['count'] as int,
    };
  }

  /// Clear all data
  static Future<void> clearAllData() async {
    final dbClient = await db;
    await dbClient.delete('downloads');
    await dbClient.delete('video_cache');
    await dbClient.delete('user_session');
  }
}