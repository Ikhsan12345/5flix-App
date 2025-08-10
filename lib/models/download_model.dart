class DownloadModel {
  final int? id;
  final int videoId;
  final String title;
  final String localPath;
  final String thumbnailUrl;
  final int fileSize;
  final DateTime downloadedAt;

  DownloadModel({
    this.id,
    required this.videoId,
    required this.title,
    required this.localPath,
    required this.thumbnailUrl,
    required this.fileSize,
    required this.downloadedAt
  });
}