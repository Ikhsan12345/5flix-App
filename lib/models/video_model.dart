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
  
  // New fields from backend
  final double? durationMinutes;
  final String? durationFormatted;
  final String? streamUrl;
  final String? originalVideoUrl;
  final String? originalThumbnailUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    try {
      return VideoModel(
        id: _parseInt(json['id']),
        title: json['title']?.toString() ?? '',
        genre: json['genre']?.toString() ?? '',
        // Use stream_url from backend if available, fallback to thumbnail_url
        thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
        // Use stream_url from backend if available, fallback to video_url or original_video_url
        videoUrl: json['stream_url']?.toString() ?? 
                 json['video_url']?.toString() ?? 
                 json['original_video_url']?.toString() ?? '',
        description: json['description']?.toString(),
        duration: _parseInt(json['duration']),
        year: _parseInt(json['year']),
        isFeatured: _parseBool(json['is_featured']),
        
        // New fields
        durationMinutes: _parseDouble(json['duration_minutes']),
        durationFormatted: json['duration_formatted']?.toString(),
        streamUrl: json['stream_url']?.toString(),
        originalVideoUrl: json['original_video_url']?.toString(),
        originalThumbnailUrl: json['original_thumbnail_url']?.toString(),
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );
    } catch (e) {
      print('VideoModel.fromJson error: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  // Check if this is a B2 URL that needs special handling
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

  // Get the appropriate video URL - prefer stream URL for streaming
  String get playbackUrl {
    return streamUrl ?? videoUrl;
  }

  // Get the appropriate thumbnail URL
  String get displayThumbnailUrl {
    return thumbnailUrl;
  }

  // Get formatted duration
  String get displayDuration {
    if (durationFormatted != null) {
      return durationFormatted!;
    }
    return formatDuration(duration);
  }

  // Helper methods
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
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

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
    };
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
    );
  }

  String toDebugString() {
    return 'VideoModel(id: $id, title: "$title", streamUrl: ${streamUrl != null ? "available" : "null"}, isB2Video: $isB2Video, isB2Thumbnail: $isB2Thumbnail)';
  }
}