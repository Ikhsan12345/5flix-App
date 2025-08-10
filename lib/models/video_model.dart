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
    return VideoModel(
      id: json['id'],
      title: json['title'],
      genre: json['genre'],
      thumbnailUrl: json['thumbnail_url'],
      videoUrl: json['video_url'],
      description: json['description'],
      duration: json['duration'],
      year: json['year'],
      isFeatured: json['is_featured'] ?? false,
    );
  }
}
