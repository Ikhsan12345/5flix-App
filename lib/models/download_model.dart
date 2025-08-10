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
    );
  }
}
