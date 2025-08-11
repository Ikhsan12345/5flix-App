import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/models/download_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/services/xor_chiper_service.dart';

class DownloadService {
  static Database? _database;
  static const String _dbName = 'downloads.db';
  static const String _tableName = 'downloads';
  static const String _encryptionMethod = 'XOR';
  static const int _chunkSize =
      1024 * 1024; // 1MB chunks for large file handling

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
      version: 3, // Increased version for enhanced encryption support
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_id INTEGER NOT NULL UNIQUE,
            title TEXT NOT NULL,
            local_path TEXT NOT NULL,
            thumbnail_url TEXT NOT NULL,
            thumbnail_local_path TEXT,
            file_size INTEGER NOT NULL,
            downloaded_at INTEGER NOT NULL,
            genre TEXT,
            year INTEGER,
            duration INTEGER,
            description TEXT,
            is_featured INTEGER NOT NULL DEFAULT 0,
            download_status TEXT NOT NULL DEFAULT 'completed',
            progress REAL NOT NULL DEFAULT 1.0,
            original_video_url TEXT,
            original_thumbnail_url TEXT,
            is_encrypted INTEGER NOT NULL DEFAULT 1,
            encryption_method TEXT DEFAULT 'XOR',
            mime_type TEXT,
            quality TEXT,
            last_accessed_at INTEGER,
            encryption_version INTEGER DEFAULT 3,
            file_hash TEXT,
            checksum TEXT
          )
        ''');

        // Create indexes for faster queries
        await db.execute('CREATE INDEX idx_video_id ON $_tableName (video_id)');
        await db.execute(
          'CREATE INDEX idx_download_status ON $_tableName (download_status)',
        );
        await db.execute(
          'CREATE INDEX idx_encryption_version ON $_tableName (encryption_version)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns for version 2
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN original_video_url TEXT',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN original_thumbnail_url TEXT',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 1',
          );
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN encryption_method TEXT DEFAULT \'XOR\'',
          );
          await db.execute('ALTER TABLE $_tableName ADD COLUMN mime_type TEXT');
          await db.execute('ALTER TABLE $_tableName ADD COLUMN quality TEXT');
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN last_accessed_at INTEGER',
          );
        }
        if (oldVersion < 3) {
          // Add enhanced encryption support
          await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN encryption_version INTEGER DEFAULT 3',
          );
          await db.execute('ALTER TABLE $_tableName ADD COLUMN file_hash TEXT');
          await db.execute('ALTER TABLE $_tableName ADD COLUMN checksum TEXT');
        }
      },
    );
  }

  // Download video with enhanced encryption and progress tracking
  static Future<bool> downloadVideoWithProgress(
    VideoModel video, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
    VoidCallback? onCancel,
  }) async {
    return await downloadVideo(
      video,
      onProgress: onProgress,
      onStatusChange: onStatusChange,
      onCancel: onCancel,
    );
  }

  // Main download method with enhanced XOR encryption
  static Future<bool> downloadVideo(
    VideoModel video, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
    VoidCallback? onCancel,
  }) async {
    try {
      onStatusChange?.call('Initializing download...');
      debugPrint(
        'DownloadService: Starting download for video ${video.id}: ${video.title}',
      );

      // Check if already downloaded
      if (await isVideoDownloaded(video.id)) {
        throw Exception('Video is already downloaded');
      }

      // Check authentication for download
      if (!await ApiService.isAuthenticated()) {
        throw Exception('Authentication required for downloads');
      }

      onStatusChange?.call('Getting download URL...');

      // Get download URL from API
      final downloadResponse = await ApiService.getDownloadUrl(video.id);
      if (!downloadResponse['success']) {
        throw Exception(
          downloadResponse['message'] ?? 'Failed to get download URL',
        );
      }

      final videoUrl = downloadResponse['data']['video_url'];
      final thumbnailUrl =
          downloadResponse['data']['thumbnail_url'] ??
          ApiService.getVideoThumbnailUrl(video.id);

      debugPrint(
        'DownloadService: Got download URLs - Video: $videoUrl, Thumbnail: $thumbnailUrl',
      );

      // Create download directories
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');
      final videoDir = Directory('${downloadDir.path}/videos');
      final thumbnailDir = Directory('${downloadDir.path}/thumbnails');

      // Ensure directories exist
      for (final dir in [downloadDir, videoDir, thumbnailDir]) {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // Generate safe filename
      final safeTitle = _sanitizeFilename(video.title);
      final videoFileName = '${video.id}_${safeTitle}.enc';
      final thumbnailFileName = '${video.id}_${safeTitle}_thumb.jpg';

      final videoPath = '${videoDir.path}/$videoFileName';
      final thumbnailPath = '${thumbnailDir.path}/$thumbnailFileName';

      // Insert initial download record
      final db = await database;
      final downloadModel = DownloadModel.fromVideoModel(
        video,
        localPath: videoPath,
        thumbnailLocalPath: thumbnailPath,
        fileSize: 0,
        downloadStatus: 'downloading',
        progress: 0.0,
      );

      await db.insert(
        _tableName,
        downloadModel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      try {
        // Download and encrypt video with progress
        onStatusChange?.call('Downloading and encrypting video...');
        final fileSize = await _downloadAndEncryptVideoFile(
          videoUrl,
          videoPath,
          onProgress: (progress) {
            onProgress?.call(progress * 0.8); // 80% for video download
            _updateDownloadProgress(video.id, progress * 0.8);
          },
          onCancel: onCancel,
        );

        // Download thumbnail
        onStatusChange?.call('Downloading thumbnail...');
        await _downloadThumbnailFile(thumbnailUrl, thumbnailPath);
        onProgress?.call(0.9);

        // Verify encrypted file integrity
        onStatusChange?.call('Verifying file integrity...');
        final isValid = await XorCipherService.validateDataIntegrity(
          await File(videoPath).readAsBytes(),
        );

        if (!isValid) {
          throw Exception('Downloaded file failed integrity check');
        }

        // Generate file hash for additional security
        final fileBytes = await File(videoPath).readAsBytes();
        final fileHash = await _generateFileHash(fileBytes);

        // Update database with completion
        onStatusChange?.call('Finalizing download...');
        await _updateDownloadRecord(
          video.id,
          fileSize: fileSize,
          status: 'completed',
          progress: 1.0,
          fileHash: fileHash,
          encryptionVersion: 3,
        );

        onProgress?.call(1.0);
        onStatusChange?.call('Download completed successfully');

        debugPrint('DownloadService: Download completed for video ${video.id}');
        return true;
      } catch (e) {
        // Update status to failed
        await _updateDownloadRecord(video.id, status: 'failed', progress: 0.0);
        rethrow;
      }
    } catch (e) {
      debugPrint('DownloadService: Download error for video ${video.id}: $e');
      onStatusChange?.call('Download failed: ${e.toString()}');

      // Clean up any partial files
      await _cleanupFailedDownload(video.id);

      return false;
    }
  }

  // Enhanced download and encryption method
  static Future<int> _downloadAndEncryptVideoFile(
    String url,
    String savePath, {
    Function(double)? onProgress,
    VoidCallback? onCancel,
  }) async {
    debugPrint('DownloadService: Downloading and encrypting video from: $url');

    final request = http.Request('GET', Uri.parse(url));

    // Add authentication headers
    final headers = {
      'Accept': 'application/octet-stream',
      'User-Agent': 'FiveFlix-Mobile-App/1.0',
    };

    final authToken = ApiService.getCurrentToken();
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    request.headers.addAll(headers);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      if (streamedResponse.statusCode == 401) {
        throw Exception('Authentication required for download');
      } else if (streamedResponse.statusCode == 429) {
        throw Exception(
          'Download rate limit exceeded. Please try again later.',
        );
      } else {
        throw Exception(
          'Failed to download video: HTTP ${streamedResponse.statusCode}',
        );
      }
    }

    final contentLength = streamedResponse.contentLength ?? 0;
    final tempFile = File('${savePath}.tmp');

    int downloadedBytes = 0;
    List<int> videoBytes = [];
    bool cancelled = false;

    // Menggunakan Future.delayed untuk memeriksa pembatalan
    final cancelChecker = Future<void>.delayed(Duration(seconds: 1), () {
      if (cancelled) {
        throw Exception('Download cancelled by user');
      }
    });

    try {
      // Download video data
      await for (var chunk in streamedResponse.stream) {
        if (cancelled) {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          throw Exception('Download cancelled by user');
        }

        videoBytes.addAll(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress?.call(progress);
        }

        // Memeriksa pembatalan secara periodik
        await cancelChecker; // Mengecek pembatalan di setiap chunk yang diterima
      }

      debugPrint('DownloadService: Download completed, starting encryption...');

      // Encrypt the downloaded data using enhanced XorCipherService
      final videoData = Uint8List.fromList(videoBytes);
      final encryptedData = await XorCipherService.encrypt(videoData);

      // Write encrypted data to final file
      final finalFile = File(savePath);
      await finalFile.writeAsBytes(encryptedData);

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      debugPrint('DownloadService: Video download and encryption completed');
      return encryptedData.length;
    } catch (e) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  // Download video file using chunked encryption for large files
  static Future<int> _downloadAndEncryptVideoFileChunked(
    String url,
    String savePath, {
    Function(double)? onProgress,
    VoidCallback? onCancel,
  }) async {
    debugPrint('DownloadService: Starting chunked download and encryption');

    final request = http.Request('GET', Uri.parse(url));

    // Add authentication headers
    final headers = {
      'Accept': 'application/octet-stream',
      'User-Agent': 'FiveFlix-Mobile-App/1.0',
    };

    final authToken = ApiService.getCurrentToken();
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    request.headers.addAll(headers);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to download video: HTTP ${streamedResponse.statusCode}',
      );
    }

    final contentLength = streamedResponse.contentLength ?? 0;

    // Use XorCipherService file encryption for large files
    final tempDownloadPath = '${savePath}.download';
    final tempFile = File(tempDownloadPath);

    try {
      // Write downloaded data to temporary file
      final sink = tempFile.openWrite();
      int downloadedBytes = 0;

      await for (var chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress?.call(
            progress * 0.7,
          ); // 70% for download, 30% for encryption
        }
      }

      await sink.close();

      // Encrypt the downloaded file using chunked encryption
      debugPrint('DownloadService: Starting file encryption...');
      await XorCipherService.encryptFileInChunks(
        tempDownloadPath,
        savePath,
        chunkSize: _chunkSize,
        onProgress: (encryptProgress) {
          onProgress?.call(0.7 + (encryptProgress * 0.3));
        },
      );

      // Get final encrypted file size
      final encryptedFile = File(savePath);
      final finalSize = await encryptedFile.length();

      // Clean up temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      debugPrint('DownloadService: Chunked download and encryption completed');
      return finalSize;
    } catch (e) {
      // Clean up temporary files
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final finalFile = File(savePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      rethrow;
    }
  }

  // Enhanced thumbnail download
  static Future<void> _downloadThumbnailFile(
    String url,
    String savePath,
  ) async {
    try {
      debugPrint('DownloadService: Downloading thumbnail from: $url');

      final headers = <String, String>{
        'Accept': 'image/*',
        'User-Agent': 'FiveFlix-Mobile-App/1.0',
      };

      final authToken = ApiService.getCurrentToken();
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final thumbnailFile = File(savePath);
        await thumbnailFile.writeAsBytes(response.bodyBytes);
        debugPrint('DownloadService: Thumbnail download completed');
      } else {
        debugPrint(
          'DownloadService: Failed to download thumbnail: ${response.statusCode}',
        );
        // Create a placeholder file if thumbnail download fails
        await _createPlaceholderThumbnail(savePath);
      }
    } catch (e) {
      debugPrint('DownloadService: Thumbnail download error: $e');
      await _createPlaceholderThumbnail(savePath);
    }
  }

  // Create placeholder thumbnail
  static Future<void> _createPlaceholderThumbnail(String savePath) async {
    try {
      final placeholderFile = File(savePath);
      // Create a minimal placeholder file
      await placeholderFile.writeAsBytes([]);
    } catch (e) {
      debugPrint('DownloadService: Error creating placeholder thumbnail: $e');
    }
  }

  // Enhanced decrypted video file getter with better error handling
  static Future<File?> getDecryptedVideoFile(int videoId) async {
    try {
      debugPrint(
        'DownloadService: Getting decrypted video file for video $videoId',
      );

      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo == null) {
        debugPrint(
          'DownloadService: No download info found for video $videoId',
        );
        return null;
      }

      final encryptedFile = File(downloadInfo.localPath);
      if (!await encryptedFile.exists()) {
        debugPrint(
          'DownloadService: Encrypted file not found: ${downloadInfo.localPath}',
        );
        return null;
      }

      // Check if file uses chunked encryption (for large files)
      final fileSize = await encryptedFile.length();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempVideoPath = '${tempDir.path}/temp_${videoId}_$timestamp.mp4';

      if (fileSize > _chunkSize * 10) {
        // Use chunked decryption for files > 10MB
        debugPrint('DownloadService: Using chunked decryption for large file');

        await XorCipherService.decryptFileInChunks(
          downloadInfo.localPath,
          tempVideoPath,
          chunkSize: _chunkSize,
          onProgress: (progress) {
            debugPrint(
              'DownloadService: Decryption progress: ${(progress * 100).toStringAsFixed(1)}%',
            );
          },
        );
      } else {
        // Use memory-based decryption for smaller files
        debugPrint('DownloadService: Using memory-based decryption');

        final encryptedData = await encryptedFile.readAsBytes();
        final decryptedData = await XorCipherService.decrypt(encryptedData);

        final tempFile = File(tempVideoPath);
        await tempFile.writeAsBytes(decryptedData);
      }

      // Verify decrypted file exists and has content
      final tempFile = File(tempVideoPath);
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        throw Exception('Decrypted file is empty or creation failed');
      }

      // Update last accessed time
      await _updateDownloadRecord(
        videoId,
        lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint(
        'DownloadService: Created temporary decrypted file: $tempVideoPath',
      );
      return tempFile;
    } catch (e) {
      debugPrint('DownloadService: Error decrypting video: $e');
      return null;
    }
  }

  // Enhanced update download record method
  static Future<void> _updateDownloadRecord(
    int videoId, {
    int? fileSize,
    String? status,
    double? progress,
    String? fileHash,
    int? encryptionVersion,
    int? lastAccessedAt,
  }) async {
    try {
      final db = await database;
      final updates = <String, dynamic>{};

      if (fileSize != null) updates['file_size'] = fileSize;
      if (status != null) updates['download_status'] = status;
      if (progress != null) updates['progress'] = progress;
      if (fileHash != null) updates['file_hash'] = fileHash;
      if (encryptionVersion != null)
        updates['encryption_version'] = encryptionVersion;
      if (lastAccessedAt != null) updates['last_accessed_at'] = lastAccessedAt;

      if (updates.isNotEmpty) {
        await db.update(
          _tableName,
          updates,
          where: 'video_id = ?',
          whereArgs: [videoId],
        );
      }
    } catch (e) {
      debugPrint('DownloadService: Error updating download record: $e');
    }
  }

  // Generate file hash for integrity verification
  static Future<String> _generateFileHash(Uint8List data) async {
    try {
      // Use XorCipherService's custom hash function
      final hash = CustomCrypto.simpleHash(data);
      return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (e) {
      debugPrint('DownloadService: Error generating file hash: $e');
      return '';
    }
  }

  // Update download progress in database
  static Future<void> _updateDownloadProgress(
    int videoId,
    double progress,
  ) async {
    try {
      final db = await database;
      await db.update(
        _tableName,
        {
          'progress': progress,
          'download_status': progress >= 1.0 ? 'completed' : 'downloading',
        },
        where: 'video_id = ?',
        whereArgs: [videoId],
      );
    } catch (e) {
      debugPrint('DownloadService: Error updating progress: $e');
    }
  }

  // Get downloaded videos as VideoModel list
  static Future<List<VideoModel>> getDownloadedVideos() async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'download_status = ?',
        whereArgs: ['completed'],
        orderBy: 'downloaded_at DESC',
      );

      final videos = <VideoModel>[];
      for (final map in maps) {
        try {
          final downloadModel = DownloadModel.fromMap(map);
          final videoModel = downloadModel.toVideoModel();
          videos.add(videoModel);
        } catch (e) {
          debugPrint('DownloadService: Error parsing download record: $e');
        }
      }

      return videos;
    } catch (e) {
      debugPrint('DownloadService: Error getting downloaded videos: $e');
      return [];
    }
  }

  // Get download models with enhanced metadata
  static Future<List<DownloadModel>> getDownloadModels() async {
    try {
      final db = await database;
      final maps = await db.query(_tableName, orderBy: 'downloaded_at DESC');

      return maps.map((map) => DownloadModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DownloadService: Error getting download models: $e');
      return [];
    }
  }

  // Check if video is downloaded
  static Future<bool> isVideoDownloaded(int videoId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'video_id = ? AND download_status = ?',
        whereArgs: [videoId, 'completed'],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('DownloadService: Error checking download status: $e');
      return false;
    }
  }

  // Get download info with enhanced metadata
  static Future<DownloadModel?> getDownloadInfo(int videoId) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'video_id = ?',
        whereArgs: [videoId],
      );

      if (result.isNotEmpty) {
        return DownloadModel.fromMap(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('DownloadService: Error getting download info: $e');
      return null;
    }
  }

  // Enhanced file integrity verification
  static Future<bool> verifyDownloadIntegrity(int videoId) async {
    try {
      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo == null) return false;

      final file = File(downloadInfo.localPath);
      if (!await file.exists()) return false;

      // Verify encryption integrity using XorCipherService
      final fileData = await file.readAsBytes();
      final isValid = await XorCipherService.validateDataIntegrity(fileData);

      if (!isValid) {
        debugPrint('DownloadService: File failed encryption integrity check');
        return false;
      }

      // Test decryption without creating temp file
      try {
        if (await file.length() > _chunkSize * 10) {
          // For large files, just verify the encrypted data structure
          final isEncrypted = XorCipherService.isEncryptedData(fileData);
          return isEncrypted;
        } else {
          // For smaller files, test full decryption
          await XorCipherService.decrypt(fileData);
          return true;
        }
      } catch (e) {
        debugPrint('DownloadService: Decryption test failed: $e');
        return false;
      }
    } catch (e) {
      debugPrint('DownloadService: Error verifying download integrity: $e');
      return false;
    }
  }

  // Delete download with enhanced cleanup
  static Future<bool> deleteDownload(int videoId) async {
    try {
      debugPrint('DownloadService: Deleting download for video $videoId');

      final db = await database;

      // Get file paths before deletion
      final result = await db.query(
        _tableName,
        where: 'video_id = ?',
        whereArgs: [videoId],
      );

      if (result.isNotEmpty) {
        final downloadModel = DownloadModel.fromMap(result.first);

        // Delete physical files
        await _deletePhysicalFiles([
          downloadModel.localPath,
          if (downloadModel.thumbnailLocalPath != null)
            downloadModel.thumbnailLocalPath!,
        ]);
      }

      // Delete from database
      final deletedRows = await db.delete(
        _tableName,
        where: 'video_id = ?',
        whereArgs: [videoId],
      );

      // Clean any associated temp files
      await _cleanupTempFilesForVideo(videoId);

      debugPrint('DownloadService: Deleted download for video $videoId');
      return deletedRows > 0;
    } catch (e) {
      debugPrint('DownloadService: Error deleting download: $e');
      return false;
    }
  }

  // Clean temporary files for specific video
  static Future<void> _cleanupTempFilesForVideo(int videoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where(
        (entity) =>
            entity is File &&
            entity.path.contains('temp_${videoId}_') &&
            entity.path.endsWith('.mp4'),
      );

      for (final file in tempFiles) {
        if (file is File) {
          try {
            await file.delete();
            debugPrint('DownloadService: Deleted temp file: ${file.path}');
          } catch (e) {
            debugPrint('DownloadService: Error deleting temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint(
        'DownloadService: Error cleaning temp files for video $videoId: $e',
      );
    }
  }

  // Enhanced clean temporary files
  static Future<void> cleanTemporaryFiles() async {
    try {
      debugPrint('DownloadService: Cleaning temporary files');

      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync().where(
        (entity) =>
            entity is File &&
            (entity.path.contains('temp_') &&
                (entity.path.endsWith('.mp4') ||
                    entity.path.endsWith('.tmp') ||
                    entity.path.contains('decrypt_'))),
      );

      int deletedCount = 0;
      for (final file in tempFiles) {
        if (file is File) {
          try {
            // Only delete files older than 1 hour
            final fileStat = await file.stat();
            final age = DateTime.now().difference(fileStat.modified);

            if (age.inHours >= 1) {
              await file.delete();
              deletedCount++;
            }
          } catch (e) {
            debugPrint(
              'DownloadService: Error deleting temp file ${file.path}: $e',
            );
          }
        }
      }

      debugPrint('DownloadService: Cleaned $deletedCount temporary files');
    } catch (e) {
      debugPrint('DownloadService: Error cleaning temporary files: $e');
    }
  }

  // Test XorCipherService integration
  static Future<bool> testEncryptionIntegrity() async {
    try {
      debugPrint('DownloadService: Testing XorCipherService integration...');

      // Use XorCipherService built-in test
      final testResult = await XorCipherService.testEncryptionIntegrity();

      if (testResult) {
        debugPrint(
          'DownloadService: XorCipherService integration test passed ✅',
        );
      } else {
        debugPrint(
          'DownloadService: XorCipherService integration test failed ❌',
        );
      }

      return testResult;
    } catch (e) {
      debugPrint('DownloadService: Error testing encryption integrity: $e');
      return false;
    }
  }

  // Get encryption info for downloaded video
  static Future<Map<String, dynamic>?> getVideoEncryptionInfo(
    int videoId,
  ) async {
    try {
      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo == null) return null;

      final file = File(downloadInfo.localPath);
      if (!await file.exists()) return null;

      final fileData = await file.readAsBytes();
      final metadata = XorCipherService.getEncryptionMetadata(fileData);

      return {
        ...?metadata,
        'video_id': videoId,
        'local_path': downloadInfo.localPath,
        'download_status': downloadInfo.downloadStatus,
        'file_exists': true,
        'database_file_size': downloadInfo.fileSize,
        'actual_file_size': fileData.length,
      };
    } catch (e) {
      debugPrint('DownloadService: Error getting encryption info: $e');
      return null;
    }
  }

  // Clear all downloads with enhanced cleanup
  static Future<bool> clearAllDownloads() async {
    try {
      debugPrint('DownloadService: Clearing all downloads');

      final db = await database;

      // Get all download paths
      final results = await db.query(_tableName);
      final filePaths = <String>[];

      for (final result in results) {
        final downloadModel = DownloadModel.fromMap(result);
        filePaths.add(downloadModel.localPath);
        if (downloadModel.thumbnailLocalPath != null) {
          filePaths.add(downloadModel.thumbnailLocalPath!);
        }
      }

      // Delete all physical files
      await _deletePhysicalFiles(filePaths);

      // Clear database
      await db.delete(_tableName);

      // Clean all temporary files
      await cleanTemporaryFiles();

      debugPrint('DownloadService: Cleared all downloads');
      return true;
    } catch (e) {
      debugPrint('DownloadService: Error clearing downloads: $e');
      return false;
    }
  }

  // Get total download size
  static Future<int> getTotalDownloadSize() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT SUM(file_size) as total FROM $_tableName WHERE download_status = ?',
        ['completed'],
      );

      if (result.isNotEmpty && result.first['total'] != null) {
        return result.first['total'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('DownloadService: Error getting total size: $e');
      return 0;
    }
  }

  // Cancel download with proper cleanup
  static Future<bool> cancelDownload(int videoId) async {
    try {
      debugPrint('DownloadService: Cancelling download for video $videoId');

      await _updateDownloadRecord(videoId, status: 'cancelled', progress: 0.0);

      // Clean up partial files
      await _cleanupFailedDownload(videoId);

      return true;
    } catch (e) {
      debugPrint('DownloadService: Error cancelling download: $e');
      return false;
    }
  }

  // Resume download with enhanced error handling
  static Future<bool> resumeDownload(
    int videoId, {
    Function(double)? onProgress,
    Function(String)? onStatusChange,
  }) async {
    try {
      debugPrint('DownloadService: Resuming download for video $videoId');

      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo == null) {
        throw Exception('Download info not found');
      }

      // Clean up any existing partial files
      await _cleanupFailedDownload(videoId);

      // Get original video info
      final video = await ApiService.getVideo(videoId);
      if (video == null) {
        throw Exception('Video not found');
      }

      // Resume download
      return await downloadVideo(
        video,
        onProgress: onProgress,
        onStatusChange: onStatusChange,
      );
    } catch (e) {
      debugPrint('DownloadService: Error resuming download: $e');
      return false;
    }
  }

  // Get enhanced download statistics
  static Future<Map<String, dynamic>> getDownloadStatistics() async {
    try {
      final db = await database;

      final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as count, SUM(file_size) as total_size FROM $_tableName WHERE download_status = ?',
        ['completed'],
      );

      final failedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE download_status = ?',
        ['failed'],
      );

      final downloadingResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE download_status = ?',
        ['downloading'],
      );

      final encryptedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE is_encrypted = 1 AND download_status = ?',
        ['completed'],
      );

      final xorEncryptedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE encryption_method = ? AND download_status = ?',
        ['XOR', 'completed'],
      );

      return {
        'completed_count': completedResult.first['count'] ?? 0,
        'total_size': completedResult.first['total_size'] ?? 0,
        'failed_count': failedResult.first['count'] ?? 0,
        'downloading_count': downloadingResult.first['count'] ?? 0,
        'encrypted_count': encryptedResult.first['count'] ?? 0,
        'xor_encrypted_count': xorEncryptedResult.first['count'] ?? 0,
        'encryption_method': _encryptionMethod,
      };
    } catch (e) {
      debugPrint('DownloadService: Error getting statistics: $e');
      return {
        'completed_count': 0,
        'total_size': 0,
        'failed_count': 0,
        'downloading_count': 0,
        'encrypted_count': 0,
        'xor_encrypted_count': 0,
        'encryption_method': _encryptionMethod,
      };
    }
  }

  // Cleanup failed download with enhanced file removal
  static Future<void> _cleanupFailedDownload(int videoId) async {
    try {
      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo != null) {
        await _deletePhysicalFiles([
          downloadInfo.localPath,
          '${downloadInfo.localPath}.tmp',
          '${downloadInfo.localPath}.download',
          if (downloadInfo.thumbnailLocalPath != null)
            downloadInfo.thumbnailLocalPath!,
        ]);
      }

      // Clean associated temp files
      await _cleanupTempFilesForVideo(videoId);

      // Remove from database
      final db = await database;
      await db.delete(_tableName, where: 'video_id = ?', whereArgs: [videoId]);
    } catch (e) {
      debugPrint('DownloadService: Error cleaning up failed download: $e');
    }
  }

  // Delete physical files with enhanced error handling
  static Future<void> _deletePhysicalFiles(List<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('DownloadService: Deleted file: $filePath');
        }
      } catch (e) {
        debugPrint('DownloadService: Error deleting file $filePath: $e');
      }
    }
  }

  // Sanitize filename for safe file system usage
  static String _sanitizeFilename(String filename) {
    // Remove or replace invalid characters
    return filename
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase()
        .substring(0, filename.length > 50 ? 50 : filename.length);
  }

  // Format file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes == 0) ? 0 : (bytes.bitLength - 1) ~/ 10;
    final size = bytes / (1 << (i * 10));

    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  // Get downloads by status with enhanced filtering
  static Future<List<DownloadModel>> getDownloadsByStatus(String status) async {
    try {
      final db = await database;
      final maps = await db.query(
        _tableName,
        where: 'download_status = ?',
        whereArgs: [status],
        orderBy: 'downloaded_at DESC',
      );

      return maps.map((map) => DownloadModel.fromMap(map)).toList();
    } catch (e) {
      debugPrint('DownloadService: Error getting downloads by status: $e');
      return [];
    }
  }

  // Search downloads with enhanced search capabilities
  static Future<List<VideoModel>> searchDownloads(String query) async {
    try {
      if (query.isEmpty) return await getDownloadedVideos();

      final db = await database;
      final maps = await db.query(
        _tableName,
        where:
            'download_status = ? AND (title LIKE ? OR genre LIKE ? OR description LIKE ?)',
        whereArgs: ['completed', '%$query%', '%$query%', '%$query%'],
        orderBy: 'downloaded_at DESC',
      );

      final videos = <VideoModel>[];
      for (final map in maps) {
        try {
          final downloadModel = DownloadModel.fromMap(map);
          final videoModel = downloadModel.toVideoModel();
          videos.add(videoModel);
        } catch (e) {
          debugPrint('DownloadService: Error parsing search result: $e');
        }
      }

      return videos;
    } catch (e) {
      debugPrint('DownloadService: Error searching downloads: $e');
      return [];
    }
  }

  // Export download list with enhanced metadata
  static Future<String> exportDownloadList() async {
    try {
      final downloads = await getDownloadModels();
      final buffer = StringBuffer();

      buffer.writeln('FiveFlix Download List (Enhanced with XOR Encryption)');
      buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Total Downloads: ${downloads.length}');
      buffer.writeln('Encryption Method: $_encryptionMethod');
      buffer.writeln('');

      for (final download in downloads) {
        buffer.writeln('=== Video ${download.videoId} ===');
        buffer.writeln('Title: ${download.title}');
        buffer.writeln('Genre: ${download.genre ?? 'Unknown'}');
        buffer.writeln('Year: ${download.year ?? 'Unknown'}');
        buffer.writeln('Size: ${download.displayFileSize}');
        buffer.writeln('Status: ${download.downloadStatus}');
        buffer.writeln(
          'Downloaded: ${download.downloadedAt.toIso8601String()}',
        );
        buffer.writeln('Encrypted: ${download.isEncrypted ? 'Yes' : 'No'}');
        buffer.writeln(
          'Encryption Method: ${download.encryptionMethod ?? 'None'}',
        );
        if (download.lastAccessedAt != null) {
          buffer.writeln(
            'Last Accessed: ${DateTime.fromMillisecondsSinceEpoch(download.lastAccessedAt!).toIso8601String()}',
          );
        }
        buffer.writeln('Local Path: ${download.localPath}');
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('DownloadService: Error exporting download list: $e');
      return 'Error generating download list: ${e.toString()}';
    }
  }

  // Enhanced storage optimization with encryption integrity checks
  static Future<Map<String, int>> optimizeStorage() async {
    try {
      debugPrint('DownloadService: Starting enhanced storage optimization');

      int tempFilesDeleted = 0;
      int failedDownloadsRemoved = 0;
      int orphanedFilesDeleted = 0;
      int corruptedFilesFixed = 0;

      // Clean temporary files
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final tempFiles = tempDir.listSync().where(
          (entity) =>
              entity is File &&
              (entity.path.contains('temp_') || entity.path.endsWith('.tmp')),
        );

        for (final file in tempFiles) {
          if (file is File) {
            try {
              await file.delete();
              tempFilesDeleted++;
            } catch (e) {
              debugPrint('DownloadService: Error deleting temp file: $e');
            }
          }
        }
      }

      // Remove failed downloads
      final failedDownloads = await getDownloadsByStatus('failed');
      for (final download in failedDownloads) {
        await deleteDownload(download.videoId);
        failedDownloadsRemoved++;
      }

      // Check completed downloads for corruption
      final completedDownloads = await getDownloadsByStatus('completed');
      for (final download in completedDownloads) {
        try {
          final isValid = await verifyDownloadIntegrity(download.videoId);
          if (!isValid) {
            debugPrint(
              'DownloadService: Found corrupted download: ${download.videoId}',
            );
            await _updateDownloadRecord(download.videoId, status: 'corrupted');
            corruptedFilesFixed++;
          }
        } catch (e) {
          debugPrint(
            'DownloadService: Error checking download ${download.videoId}: $e',
          );
        }
      }

      // Find and remove orphaned files
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/downloads');

      if (await downloadDir.exists()) {
        final allDownloads = await getDownloadModels();
        final validPaths = allDownloads
            .where((d) => d.downloadStatus == 'completed')
            .map((d) => d.localPath)
            .toSet();

        final videoDir = Directory('${downloadDir.path}/videos');
        if (await videoDir.exists()) {
          final videoFiles = videoDir.listSync();
          for (final file in videoFiles) {
            if (file is File && !validPaths.contains(file.path)) {
              try {
                await file.delete();
                orphanedFilesDeleted++;
              } catch (e) {
                debugPrint('DownloadService: Error deleting orphaned file: $e');
              }
            }
          }
        }
      }

      debugPrint('DownloadService: Enhanced storage optimization completed');

      return {
        'temp_files_deleted': tempFilesDeleted,
        'failed_downloads_removed': failedDownloadsRemoved,
        'orphaned_files_deleted': orphanedFilesDeleted,
        'corrupted_files_found': corruptedFilesFixed,
      };
    } catch (e) {
      debugPrint('DownloadService: Error optimizing storage: $e');
      return {
        'temp_files_deleted': 0,
        'failed_downloads_removed': 0,
        'orphaned_files_deleted': 0,
        'corrupted_files_found': 0,
      };
    }
  }

  // Get XorCipherService performance info
  static Future<Map<String, dynamic>> getEncryptionPerformanceInfo() async {
    try {
      // Get cipher information
      final cipherInfo = await XorCipherService.getCipherInfo();

      // Run performance benchmark
      final benchmark = await XorCipherService.benchmarkPerformance(
        testDataSize: 1024 * 1024, // 1MB test
        iterations: 3,
      );

      return {
        'cipher_info': cipherInfo,
        'benchmark_results': benchmark,
        'integration_status': 'active',
        'chunk_size_mb': (_chunkSize / (1024 * 1024)).toStringAsFixed(1),
      };
    } catch (e) {
      debugPrint(
        'DownloadService: Error getting encryption performance info: $e',
      );
      return {'error': e.toString(), 'integration_status': 'error'};
    }
  }

  // Repair corrupted downloads
  static Future<bool> repairCorruptedDownload(int videoId) async {
    try {
      debugPrint(
        'DownloadService: Attempting to repair corrupted download for video $videoId',
      );

      final downloadInfo = await getDownloadInfo(videoId);
      if (downloadInfo == null) {
        throw Exception('Download info not found');
      }

      // Mark as failed and attempt redownload
      await _updateDownloadRecord(videoId, status: 'failed');

      // Get video info and attempt redownload
      final video = await ApiService.getVideo(videoId);
      if (video == null) {
        throw Exception('Video info not found');
      }

      return await downloadVideo(video);
    } catch (e) {
      debugPrint('DownloadService: Error repairing corrupted download: $e');
      return false;
    }
  }

  // Get download health report
  static Future<Map<String, dynamic>> getDownloadHealthReport() async {
    try {
      final allDownloads = await getDownloadModels();
      final stats = await getDownloadStatistics();

      int healthyCount = 0;
      int corruptedCount = 0;
      int missingFilesCount = 0;

      for (final download in allDownloads.where(
        (d) => d.downloadStatus == 'completed',
      )) {
        final file = File(download.localPath);

        if (!await file.exists()) {
          missingFilesCount++;
          continue;
        }

        final isHealthy = await verifyDownloadIntegrity(download.videoId);
        if (isHealthy) {
          healthyCount++;
        } else {
          corruptedCount++;
        }
      }

      return {
        'total_downloads': allDownloads.length,
        'completed_downloads': stats['completed_count'],
        'healthy_downloads': healthyCount,
        'corrupted_downloads': corruptedCount,
        'missing_files': missingFilesCount,
        'health_percentage': allDownloads.isEmpty
            ? 100.0
            : (healthyCount / allDownloads.length * 100),
        'encryption_method': _encryptionMethod,
        'encryption_version': 3,
        'last_check': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('DownloadService: Error generating health report: $e');
      return {
        'error': e.toString(),
        'last_check': DateTime.now().toIso8601String(),
      };
    }
  }

  // Migrate old downloads to new encryption format
  static Future<Map<String, dynamic>> migrateToEnhancedEncryption() async {
    try {
      debugPrint('DownloadService: Starting migration to enhanced encryption');

      final db = await database;
      final oldDownloads = await db.query(
        _tableName,
        where: 'encryption_version < ? OR encryption_version IS NULL',
        whereArgs: [3],
      );

      int migratedCount = 0;
      int failedCount = 0;

      for (final downloadMap in oldDownloads) {
        try {
          final download = DownloadModel.fromMap(downloadMap);
          final videoId = download.videoId;

          debugPrint(
            'DownloadService: Migrating video $videoId to enhanced encryption',
          );

          // Get video info for redownload
          final video = await ApiService.getVideo(videoId);
          if (video == null) {
            failedCount++;
            continue;
          }

          // Delete old file
          final oldFile = File(download.localPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }

          // Redownload with new encryption
          final success = await downloadVideo(video);

          if (success) {
            migratedCount++;
          } else {
            failedCount++;
          }
        } catch (e) {
          debugPrint('DownloadService: Error migrating download: $e');
          failedCount++;
        }
      }

      debugPrint(
        'DownloadService: Migration completed - Success: $migratedCount, Failed: $failedCount',
      );

      return {
        'migrated_count': migratedCount,
        'failed_count': failedCount,
        'total_processed': oldDownloads.length,
      };
    } catch (e) {
      debugPrint('DownloadService: Error during migration: $e');
      return {
        'migrated_count': 0,
        'failed_count': 0,
        'total_processed': 0,
        'error': e.toString(),
      };
    }
  }

  // Close database connection
  static Future<void> closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        debugPrint('DownloadService: Database connection closed');
      }
    } catch (e) {
      debugPrint('DownloadService: Error closing database: $e');
    }
  }

  // Initialize service with integrity checks
  static Future<void> initialize() async {
    try {
      debugPrint('DownloadService: Initializing with enhanced XOR encryption');

      // Initialize database
      await database;

      // Test XorCipherService integration
      final testResult = await testEncryptionIntegrity();
      if (!testResult) {
        debugPrint('DownloadService: Warning - XorCipherService test failed');
      }

      // Clean old temporary files on startup
      await cleanTemporaryFiles();

      debugPrint('DownloadService: Initialization completed');
    } catch (e) {
      debugPrint('DownloadService: Error during initialization: $e');
      rethrow;
    }
  }
}
