import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/download_service.dart';


class DownloadModel {
  final int? id;
  final int videoId;
  final String title;
  final String localPath;
  final String thumbnailUrl;
  final String? thumbnailLocalPath;
  final int fileSize;
  final DateTime downloadedAt;
  final String? genre;
  final int? year;
  final int? duration;
  final String? description;
  final bool isFeatured;
  final String downloadStatus;
  final double progress;
  
  // Additional fields for better API integration
  final String? originalVideoUrl;
  final String? originalThumbnailUrl;
  final bool isEncrypted;
  final String? encryptionMethod;
  final String? mimeType;
  final String? quality;
  final DateTime? lastAccessedAt;

  DownloadModel({
    this.id,
    required this.videoId,
    required this.title,
    required this.localPath,
    required this.thumbnailUrl,
    this.thumbnailLocalPath,
    required this.fileSize,
    required this.downloadedAt,
    this.genre,
    this.year,
    this.duration,
    this.description,
    this.isFeatured = false,
    this.downloadStatus = 'completed',
    this.progress = 1.0,
    this.originalVideoUrl,
    this.originalThumbnailUrl,
    this.isEncrypted = true,
    this.encryptionMethod = 'XOR',
    this.mimeType,
    this.quality,
    this.lastAccessedAt,
  });

  factory DownloadModel.fromMap(Map<String, dynamic> map) {
    return DownloadModel(
      id: map['id'],
      videoId: map['video_id'],
      title: map['title'],
      localPath: map['local_path'],
      thumbnailUrl: map['thumbnail_url'],
      thumbnailLocalPath: map['thumbnail_local_path'],
      fileSize: map['file_size'] ?? 0,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(map['downloaded_at']),
      genre: map['genre'],
      year: map['year'],
      duration: map['duration'],
      description: map['description'],
      isFeatured: (map['is_featured'] ?? 0) == 1,
      downloadStatus: map['download_status'] ?? 'completed',
      progress: map['progress']?.toDouble() ?? 1.0,
      originalVideoUrl: map['original_video_url'],
      originalThumbnailUrl: map['original_thumbnail_url'],
      isEncrypted: (map['is_encrypted'] ?? 1) == 1,
      encryptionMethod: map['encryption_method'] ?? 'XOR',
      mimeType: map['mime_type'],
      quality: map['quality'],
      lastAccessedAt: map['last_accessed_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_accessed_at'])
          : null,
    );
  }

  factory DownloadModel.fromVideoModel(
    VideoModel video, {
    required String localPath,
    String? thumbnailLocalPath,
    required int fileSize,
    String downloadStatus = 'completed',
    double progress = 1.0,
  }) {
    return DownloadModel(
      videoId: video.id,
      title: video.title,
      localPath: localPath,
      thumbnailUrl: video.thumbnailUrl,
      thumbnailLocalPath: thumbnailLocalPath,
      fileSize: fileSize,
      downloadedAt: DateTime.now(),
      genre: video.genre,
      year: video.year,
      duration: video.duration,
      description: video.description,
      isFeatured: video.isFeatured,
      downloadStatus: downloadStatus,
      progress: progress,
      originalVideoUrl: video.originalVideoUrl,
      originalThumbnailUrl: video.originalThumbnailUrl,
      mimeType: video.mimeType,
      quality: video.quality,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'video_id': videoId,
      'title': title,
      'local_path': localPath,
      'thumbnail_url': thumbnailUrl,
      'thumbnail_local_path': thumbnailLocalPath,
      'file_size': fileSize,
      'downloaded_at': downloadedAt.millisecondsSinceEpoch,
      'genre': genre,
      'year': year,
      'duration': duration,
      'description': description,
      'is_featured': isFeatured ? 1 : 0,
      'download_status': downloadStatus,
      'progress': progress,
      'original_video_url': originalVideoUrl,
      'original_thumbnail_url': originalThumbnailUrl,
      'is_encrypted': isEncrypted ? 1 : 0,
      'encryption_method': encryptionMethod,
      'mime_type': mimeType,
      'quality': quality,
      'last_accessed_at': lastAccessedAt?.millisecondsSinceEpoch,
    };
  }

  DownloadModel copyWith({
    int? id,
    int? videoId,
    String? title,
    String? localPath,
    String? thumbnailUrl,
    String? thumbnailLocalPath,
    int? fileSize,
    DateTime? downloadedAt,
    String? genre,
    int? year,
    int? duration,
    String? description,
    bool? isFeatured,
    String? downloadStatus,
    double? progress,
    String? originalVideoUrl,
    String? originalThumbnailUrl,
    bool? isEncrypted,
    String? encryptionMethod,
    String? mimeType,
    String? quality,
    DateTime? lastAccessedAt,
  }) {
    return DownloadModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      localPath: localPath ?? this.localPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      fileSize: fileSize ?? this.fileSize,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      progress: progress ?? this.progress,
      originalVideoUrl: originalVideoUrl ?? this.originalVideoUrl,
      originalThumbnailUrl: originalThumbnailUrl ?? this.originalThumbnailUrl,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      encryptionMethod: encryptionMethod ?? this.encryptionMethod,
      mimeType: mimeType ?? this.mimeType,
      quality: quality ?? this.quality,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }

  // Convert to VideoModel for playback
  VideoModel toVideoModel({String? decryptedVideoPath}) {
    return VideoModel(
      id: videoId,
      title: title,
      genre: genre ?? '',
      thumbnailUrl: thumbnailLocalPath ?? thumbnailUrl,
      videoUrl: decryptedVideoPath ?? localPath,
      description: description,
      duration: duration ?? 0,
      year: year ?? 0,
      isFeatured: isFeatured,
      originalVideoUrl: originalVideoUrl,
      originalThumbnailUrl: originalThumbnailUrl,
      mimeType: mimeType,
      quality: quality,
      fileSize: fileSize,
    );
  }

  // Format file size
  String get displayFileSize {
    return DownloadService.formatFileSize(fileSize);
  }

  // Get quality badge
  String get qualityBadge {
    if (quality != null && quality!.isNotEmpty) {
      return quality!.toUpperCase();
    }
    if (fileSize > 500 * 1024 * 1024) { // > 500MB
      return 'HD';
    }
    return 'SD';
  }

  // Check if recently downloaded
  bool get isRecentlyDownloaded {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return downloadedAt.isAfter(sevenDaysAgo);
  }

  // Update last accessed time
  DownloadModel markAsAccessed() {
    return copyWith(lastAccessedAt: DateTime.now());
  }
}