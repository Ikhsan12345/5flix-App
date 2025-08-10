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
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    try {
      return VideoModel(
        id: _parseInt(json['id']),
        title: json['title']?.toString() ?? '',
        genre: json['genre']?.toString() ?? '',
        thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
        videoUrl: json['video_url']?.toString() ?? '',
        description: json['description']?.toString(),
        duration: _parseInt(json['duration']),
        year: _parseInt(json['year']),
        isFeatured: _parseBool(json['is_featured']),
      );
    } catch (e) {
      // Debug print the problematic JSON
      print('VideoModel.fromJson error: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  // Helper method untuk parsing integer dengan fallback
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }

  // Helper method untuk parsing boolean dari berbagai format
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

  // Convert to JSON
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
    );
  }

  // Helper untuk debug
  String toDebugString() {
    return 'VideoModel(id: $id, title: "$title", genre: "$genre", year: $year, duration: $duration, isFeatured: $isFeatured)';
  }
}