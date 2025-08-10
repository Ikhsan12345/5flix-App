import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/services/xor_chiper_service.dart';

class DownloadService {
  static Database? _database;
  static const String _dbName = 'downloads.db';
  static const String _tableName = 'downloads';

  // Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = '${documentsDirectory.path}/$_dbName';
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            genre TEXT NOT NULL,
            description TEXT NOT NULL,
            duration INTEGER NOT NULL,
            year INTEGER NOT NULL,
            is_featured INTEGER NOT NULL,
            thumbnail_url TEXT NOT NULL,
            video_path TEXT NOT NULL,
            thumbnail_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            download_date TEXT NOT NULL,
            is_encrypted INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  // Download video with encryption
  static Future<bool> downloadVideo(VideoModel video, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('Preparing download...');
      
      // Check if already downloaded
      if (await isVideoDownloaded(video.id)) {
        throw Exception('Video is already downloaded');
      }

      // Get download URL from API
      final downloadResponse = await ApiService.getDownloadUrl(video.id);
      if (!downloadResponse['success']) {
        throw Exception(downloadResponse['message']);
      }

      final videoUrl = downloadResponse['data']['video_url'];
      
      // Create download directories
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final videoDir = Directory('${downloadDir.path}/videos');
      final thumbnailDir = Directory('${downloadDir.path}/thumbnails');
      
      if (!await videoDir.exists()) await videoDir.create(recursive: true);
      if (!await thumbnailDir.exists()) await thumbnailDir.create(recursive: true);

      // Download video file
      onStatusChange?.call('Downloading video...');
      final videoPath = '${videoDir.path}/${video.id}_${video.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.enc';
      final videoFile = File(videoPath);
      
      final videoResponse = await http.get(Uri.parse(videoUrl));
      if (videoResponse.statusCode != 200) {
        throw Exception('Failed to download video');
      }

      // Encrypt video data
      onStatusChange?.call('Encrypting video...');
      final encryptedVideoData = XorCipherService.encrypt(videoResponse.bodyBytes);
      await videoFile.writeAsBytes(encryptedVideoData);

      // Download thumbnail
      onStatusChange?.call('Downloading thumbnail...');
      final thumbnailPath = '${thumbnailDir.path}/${video.id}_thumbnail.jpg';
      final thumbnailFile = File(thumbnailPath);
      
      final thumbnailResponse = await http.get(Uri.parse(video.thumbnailUrl));
      if (thumbnailResponse.statusCode == 200) {
        await thumbnailFile.writeAsBytes(thumbnailResponse.bodyBytes);
      }

      // Save to database
      onStatusChange?.call('Saving to database...');
      final db = await database;
      await db.insert(_tableName, {
        'id': video.id,
        'title': video.title,
        'genre': video.genre,
        'description': video.description,
        'duration': video.duration,
        'year': video.year,
        'is_featured': video.isFeatured ? 1 : 0,
        'thumbnail_url': video.thumbnailUrl,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'file_size': encryptedVideoData.length,
        'download_date': DateTime.now().toIso8601String(),
        'is_encrypted': 1,
      });

      onStatusChange?.call('Download completed');
      onProgress?.call(1.0);
      
      return true;
    } catch (e) {
      debugPrint('Download error: $e');
      onStatusChange?.call('Download failed: ${e.toString()}');
      return false;
    }
  }

  // Download video with detailed progress
  static Future<bool> downloadVideoWithProgress(VideoModel video, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('Preparing download...');
      
      if (await isVideoDownloaded(video.id)) {
        throw Exception('Video is already downloaded');
      }

      final downloadResponse = await ApiService.getDownloadUrl(video.id);
      if (!downloadResponse['success']) {
        throw Exception(downloadResponse['message']);
      }

      final videoUrl = downloadResponse['data']['video_url'];
      
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final videoDir = Directory('${downloadDir.path}/videos');
      final thumbnailDir = Directory('${downloadDir.path}/thumbnails');
      
      if (!await videoDir.exists()) await videoDir.create(recursive: true);
      if (!await thumbnailDir.exists()) await thumbnailDir.create(recursive: true);

      // Download video with progress tracking
      onStatusChange?.call('Downloading video...');
      final videoPath = '${videoDir.path}/${video.id}_${video.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.enc';
      
      final request = http.Request('GET', Uri.parse(videoUrl));
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('Failed to download video');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final videoFile = File(videoPath);
      final sink = videoFile.openWrite();
      
      int downloadedBytes = 0;
      List<int> videoBytes = [];

      await streamedResponse.stream.listen(
        (chunk) {
          videoBytes.addAll(chunk);
          downloadedBytes += chunk.length;
          
          if (contentLength > 0) {
            final progress = downloadedBytes / contentLength;
            onProgress?.call(progress * 0.8); // 80% for download, 20% for encryption
          }
        },
      ).asFuture();

      await sink.close();

      // Encrypt video data
      onStatusChange?.call('Encrypting video...');
      final encryptedVideoData = XorCipherService.encrypt(Uint8List.fromList(videoBytes));
      await videoFile.writeAsBytes(encryptedVideoData);
      onProgress?.call(0.9);

      // Download thumbnail
      onStatusChange?.call('Downloading thumbnail...');
      final thumbnailPath = '${thumbnailDir.path}/${video.id}_thumbnail.jpg';
      final thumbnailFile = File(thumbnailPath);
      
      final thumbnailResponse = await http.get(Uri.parse(video.thumbnailUrl));
      if (thumbnailResponse.statusCode == 200) {
        await thumbnailFile.writeAsBytes(thumbnailResponse.bodyBytes);
      }

      // Save to database
      onStatusChange?.call('Finalizing...');
      final db = await database;
      await db.insert(_tableName, {
        'id': video.id,
        'title': video.title,
        'genre': video.genre,
        'description': video.description,
        'duration': video.duration,
        'year': video.year,
        'is_featured': video.isFeatured ? 1 : 0,
        'thumbnail_url': video.thumbnailUrl,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'file_size': encryptedVideoData.length,
        'download_date': DateTime.now().toIso8601String(),
        'is_encrypted': 1,
      });

      onProgress?.call(1.0);
      onStatusChange?.call('Download completed');
      
      return true;
    } catch (e) {
      debugPrint('Download error: $e');
      onStatusChange?.call('Download failed: ${e.toString()}');
      return false;
    }
  }

  // Get downloaded videos
  static Future<List<VideoModel>> getDownloadedVideos() async {
    try {
      final db = await database;
      final maps = await db.query(_tableName, orderBy: 'download_date DESC');
      
      return maps.map((map) => VideoModel(
        id: map['id'] as int,
        title: map['title'] as String,
        genre: map['genre'] as String,
        description: map['description'] as String,
        duration: map['duration'] as int,
        year: map['year'] as int,
        isFeatured: (map['is_featured'] as int) == 1,
        thumbnailUrl: map['thumbnail_path'] as String, // Use local thumbnail path
        videoUrl: map['video_path'] as String, // Use local video path
      )).toList();
    } catch (e) {
      debugPrint('Error getting downloaded videos: $e');
      return [];
    }
  }

  // Check if video is downloaded
  static Future<bool> isVideoDownloaded(int videoId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Delete download
  static Future<bool> deleteDownload(int videoId) async {
    try {
      final db = await database;
      
      // Get file paths before deletion
      final result = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
      );
      
      if (result.isNotEmpty) {
        final videoPath = result.first['video_path'] as String;
        final thumbnailPath = result.first['thumbnail_path'] as String;
        
        // Delete physical files
        final videoFile = File(videoPath);
        final thumbnailFile = File(thumbnailPath);
        
        if (await videoFile.exists()) {
          await videoFile.delete();
        }
        
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }
      
      // Delete from database
      final deletedRows = await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
      );
      
      return deletedRows > 0;
    } catch (e) {
      debugPrint('Error deleting download: $e');
      return false;
    }
  }

  // Clear all downloads
  static Future<bool> clearAllDownloads() async {
    try {
      final db = await database;
      
      // Get all download paths
      final results = await db.query(_tableName);
      
      // Delete all physical files
      for (final result in results) {
        final videoPath = result['video_path'] as String;
        final thumbnailPath = result['thumbnail_path'] as String;
        
        final videoFile = File(videoPath);
        final thumbnailFile = File(thumbnailPath);
        
        if (await videoFile.exists()) {
          await videoFile.delete();
        }
        
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }
      
      // Clear database
      await db.delete(_tableName);
      
      return true;
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
      return false;
    }
  }

  // Get total download size
  static Future<int> getTotalDownloadSize() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT SUM(file_size) as total FROM $_tableName');
      
      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Get decrypted video file for playback
  static Future<File?> getDecryptedVideoFile(int videoId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
      );
      
      if (result.isEmpty) return null;
      
      final videoPath = result.first['video_path'] as String;
      final encryptedFile = File(videoPath);
      
      if (!await encryptedFile.exists()) return null;
      
      // Read encrypted data
      final encryptedData = await encryptedFile.readAsBytes();
      
      // Decrypt data
      final decryptedData = XorCipherService.decrypt(encryptedData);
      
      // Create temporary decrypted file for playback
      final tempDir = await getTemporaryDirectory();
      final tempVideoPath = '${tempDir.path}/temp_${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final tempFile = File(tempVideoPath);
      
      await tempFile.writeAsBytes(decryptedData);
      
      return tempFile;
    } catch (e) {
      debugPrint('Error decrypting video: $e');
      return null;
    }
  }

  // Clean temporary files
  static Future<void> cleanTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where(
        (entity) => entity is File && entity.path.contains('temp_') && entity.path.endsWith('.mp4')
      );
      
      for (final file in tempFiles) {
        if (file is File) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('Error deleting temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning temporary files: $e');
    }
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes == 0) ? 0 : (bytes.bitLength - 1) ~/ 10;
    final size = bytes / (1 << (i * 10));
    
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  // Get video info
  static Future<Map<String, dynamic>?> getVideoInfo(int videoId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [videoId],
      );
      
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      return null;
    }
  }
}