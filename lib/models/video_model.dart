class VideoModel {
  final int id;
  final String title;
  final String genre;
  final String thumbnailUrl;
  final String videoUrl;
  final String? description;
  final int duration;
  final int year;
  final bool isFeatured;
  
  // Enhanced fields from backend API
  final double? durationMinutes;
  final String? durationFormatted;
  final String? streamUrl;
  final String? originalVideoUrl;
  final String? originalThumbnailUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Additional fields for better API integration
  final int? fileSize;
  final String? mimeType;
  final String? quality;

  VideoModel({
    required this.id,
    required this.title,
    required this.genre,
    required this.thumbnailUrl,
    required this.videoUrl,
    this.description,
    required this.duration,
    required this.year,
    required this.isFeatured,
    this.durationMinutes,
    this.durationFormatted,
    this.streamUrl,
    this.originalVideoUrl,
    this.originalThumbnailUrl,
    this.createdAt,
    this.updatedAt,
    this.fileSize,
    this.mimeType,
    this.quality,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    try {
      return VideoModel(
        id: _parseInt(json['id']),
        title: json['title']?.toString() ?? '',
        genre: json['genre']?.toString() ?? '',
        // Use the appropriate thumbnail URL based on API response
        thumbnailUrl: json['thumbnail_url']?.toString() ?? 
                     json['original_thumbnail_url']?.toString() ?? '',
        // Prioritize stream_url for video playback
        videoUrl: json['stream_url']?.toString() ?? 
                 json['video_url']?.toString() ?? 
                 json['original_video_url']?.toString() ?? '',
        description: json['description']?.toString(),
        duration: _parseInt(json['duration']),
        year: _parseInt(json['year']),
        isFeatured: _parseBool(json['is_featured']),
        
        // Enhanced fields
        durationMinutes: _parseDouble(json['duration_minutes']),
        durationFormatted: json['duration_formatted']?.toString(),
        streamUrl: json['stream_url']?.toString(),
        originalVideoUrl: json['original_video_url']?.toString(),
        originalThumbnailUrl: json['original_thumbnail_url']?.toString(),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
        
        // Additional fields
        fileSize: _parseInt(json['file_size']),
        mimeType: json['mime_type']?.toString(),
        quality: json['quality']?.toString(),
      );
    } catch (e) {
      print('VideoModel.fromJson error: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  // Check if this video uses Backblaze B2 storage
  bool get isB2Video {
    return (originalVideoUrl?.contains('backblazeb2.com') ?? false) || 
           (originalVideoUrl?.contains('.b2.') ?? false) ||
           videoUrl.contains('backblazeb2.com') || 
           videoUrl.contains('.b2.');
  }

  bool get isB2Thumbnail {
    return (originalThumbnailUrl?.contains('backblazeb2.com') ?? false) || 
           (originalThumbnailUrl?.contains('.b2.') ?? false) ||
           thumbnailUrl.contains('backblazeb2.com') || 
           thumbnailUrl.contains('.b2.');
  }

  // Get the appropriate URL for streaming
  String get playbackUrl {
    // For API-based streaming, always use the backend streaming endpoint
    return streamUrl ?? '/api/videos/$id/stream';
  }

  // Get the appropriate URL for thumbnails
  String get displayThumbnailUrl {
    // For API-based thumbnails, use the backend thumbnail endpoint
    if (isB2Thumbnail || streamUrl != null) {
      return '/api/videos/$id/thumbnail';
    }
    return thumbnailUrl;
  }

  // Get formatted duration string
  String get displayDuration {
    if (durationFormatted != null && durationFormatted!.isNotEmpty) {
      return durationFormatted!;
    }
    return formatDuration(duration);
  }

  // Get file size in human readable format
  String get displayFileSize {
    if (fileSize == null || fileSize == 0) return 'Unknown';
    
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = fileSize!.toDouble();
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  // Check if video has high quality indicators
  bool get isHighQuality {
    if (quality != null) {
      final q = quality!.toLowerCase();
      return q.contains('1080') || q.contains('4k') || q.contains('hd') || q.contains('uhd');
    }
    return false;
  }

  // Get quality badge text
  String get qualityBadge {
    if (quality != null && quality!.isNotEmpty) {
      return quality!.toUpperCase();
    }
    if (fileSize != null && fileSize! > 500 * 1024 * 1024) { // > 500MB
      return 'HD';
    }
    return 'SD';
  }

  // Helper parsing methods
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    if (value is double) return value != 0.0;
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds > 0 ? '${remainingSeconds}s' : ''}';
    } else {
      return '${remainingSeconds}s';
    }
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'genre': genre,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'description': description,
      'duration': duration,
      'year': year,
      'is_featured': isFeatured,
      'duration_minutes': durationMinutes,
      'duration_formatted': durationFormatted,
      'stream_url': streamUrl,
      'original_video_url': originalVideoUrl,
      'original_thumbnail_url': originalThumbnailUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'file_size': fileSize,
      'mime_type': mimeType,
      'quality': quality,
    };
  }

  // Convert to map for local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'genre': genre,
      'thumbnail_url': thumbnailUrl,
      'video_url': videoUrl,
      'description': description,
      'duration': duration,
      'year': year,
      'is_featured': isFeatured ? 1 : 0,
      'duration_minutes': durationMinutes,
      'duration_formatted': durationFormatted,
      'stream_url': streamUrl,
      'original_video_url': originalVideoUrl,
      'original_thumbnail_url': originalThumbnailUrl,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'file_size': fileSize,
      'mime_type': mimeType,
      'quality': quality,
    };
  }

  // Create from local storage map
  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      genre: map['genre'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      videoUrl: map['video_url'] ?? '',
      description: map['description'],
      duration: map['duration'] ?? 0,
      year: map['year'] ?? 0,
      isFeatured: (map['is_featured'] ?? 0) == 1,
      durationMinutes: map['duration_minutes']?.toDouble(),
      durationFormatted: map['duration_formatted'],
      streamUrl: map['stream_url'],
      originalVideoUrl: map['original_video_url'],
      originalThumbnailUrl: map['original_thumbnail_url'],
      createdAt: map['created_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      fileSize: map['file_size'],
      mimeType: map['mime_type'],
      quality: map['quality'],
    );
  }
}

extension VideoModelExtension on VideoModel {
  VideoModel copyWith({
    int? id,
    String? title,
    String? genre,
    String? description,
    int? duration,
    int? year,
    bool? isFeatured,
    String? thumbnailUrl,
    String? videoUrl,
    double? durationMinutes,
    String? durationFormatted,
    String? streamUrl,
    String? originalVideoUrl,
    String? originalThumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? fileSize,
    String? mimeType,
    String? quality,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      isFeatured: isFeatured ?? this.isFeatured,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      streamUrl: streamUrl ?? this.streamUrl,
      originalVideoUrl: originalVideoUrl ?? this.originalVideoUrl,
      originalThumbnailUrl: originalThumbnailUrl ?? this.originalThumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      quality: quality ?? this.quality,
    );
  }

  String toDebugString() {
    return 'VideoModel(id: $id, title: "$title", streamUrl: ${streamUrl != null ? "available" : "null"}, isB2Video: $isB2Video, isB2Thumbnail: $isB2Thumbnail, quality: ${quality ?? "unknown"}, size: ${displayFileSize})';
  }

  // Check if video is recently added (within last 30 days)
  bool get isRecentlyAdded {
    if (createdAt == null) return false;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return createdAt!.isAfter(thirtyDaysAgo);
  }

  // Get age of video in days
  int get ageInDays {
    if (createdAt == null) return 0;
    return DateTime.now().difference(createdAt!).inDays;
  }

  // Get a summary for search/filtering
  String get searchableText {
    return '$title $genre ${description ?? ''}'.toLowerCase();
  }

  // Check if video matches search query
  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    return searchableText.contains(query.toLowerCase());
  }
}