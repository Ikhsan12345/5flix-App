import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/download_service.dart';
// import 'package:five_flix/screens/VideoDetailScreen.dart';
import 'package:five_flix/screens/VideoPlayerScreen.dart';
import 'dart:io';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<VideoModel> downloadedVideos = [];
  bool isLoading = true;
  int totalSize = 0;
  bool isSelectionMode = false;
  Set<int> selectedVideos = {};

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  @override
  void dispose() {
    // Clean temporary files when leaving downloads screen
    DownloadService.cleanTemporaryFiles();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() => isLoading = true);

    try {
      final videos = await DownloadService.getDownloadedVideos();
      final size = await DownloadService.getTotalDownloadSize();

      setState(() {
        downloadedVideos = videos;
        totalSize = size;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading downloads: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (selectedVideos.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Delete Downloads', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${selectedVideos.length} downloaded video${selectedVideos.length > 1 ? 's' : ''}? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        for (final videoId in selectedVideos) {
          await DownloadService.deleteDownload(videoId);
        }

        setState(() {
          isSelectionMode = false;
          selectedVideos.clear();
        });

        _loadDownloads();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloads deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting downloads: $e'),
              backgroundColor: const Color(0xFFE50914),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Clear All Downloads', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all downloaded videos and free up storage space. This action cannot be undone.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        await DownloadService.clearAllDownloads();
        _loadDownloads();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All downloads cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing downloads: $e'),
              backgroundColor: const Color(0xFFE50914),
            ),
          );
        }
      }
    }
  }

  void _toggleSelection(int videoId) {
    setState(() {
      if (selectedVideos.contains(videoId)) {
        selectedVideos.remove(videoId);
        if (selectedVideos.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedVideos.add(videoId);
      }
    });
  }

  void _startSelectionMode(int videoId) {
    setState(() {
      isSelectionMode = true;
      selectedVideos.add(videoId);
    });
  }

  void _selectAll() {
    setState(() {
      selectedVideos = downloadedVideos.map((v) => v.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      isSelectionMode = false;
      selectedVideos.clear();
    });
  }

  Future<void> _playOfflineVideo(VideoModel video) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF181818),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFE50914)),
              SizedBox(height: 16),
              Text(
                'Preparing video...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Decrypt video file
      final decryptedFile = await DownloadService.getDecryptedVideoFile(video.id);
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (decryptedFile != null && await decryptedFile.exists()) {
        // Navigate to video player with decrypted file
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              video: video.copyWith(videoUrl: decryptedFile.path),
              isOffline: true,
            ),
          ),
        );
      } else {
        throw Exception('Failed to decrypt video file');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing video: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  void _showVideoInfo(VideoModel video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(video.thumbnailUrl), // Local thumbnail path
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 60,
                      color: const Color(0xFF333333),
                      child: const Icon(Icons.movie, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${video.year} • ${video.genre} • ${video.duration} min',
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              video.description ?? 'No description',
              style: const TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _playOfflineVideo(video);
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('Play', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteVideo(video.id);
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVideo(int videoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this downloaded video? This action cannot be undone.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DownloadService.deleteDownload(videoId);
        _loadDownloads();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting video: $e'),
              backgroundColor: const Color(0xFFE50914),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          isSelectionMode 
              ? '${selectedVideos.length} selected'
              : 'Downloads',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              onPressed: _selectAll,
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
            ),
            IconButton(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Selected',
            ),
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
              tooltip: 'Clear Selection',
            ),
          ] else ...[
            if (downloadedVideos.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF181818),
                onSelected: (value) {
                  switch (value) {
                    case 'clear_all':
                      _clearAllDownloads();
                      break;
                    case 'clean_temp':
                      DownloadService.cleanTemporaryFiles();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Temporary files cleaned'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'clean_temp',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services, color: Colors.orange, size: 20),
                        SizedBox(width: 12),
                        Text('Clean Temp Files', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Clear All Downloads', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              )
            : Column(
                children: [
                  if (downloadedVideos.isNotEmpty) _buildStorageInfo(),
                  Expanded(
                    child: downloadedVideos.isEmpty
                        ? _buildEmptyState()
                        : _buildDownloadsList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, color: Color(0xFFE50914)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${downloadedVideos.length} videos downloaded',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total size: ${DownloadService.formatFileSize(totalSize)}',
                  style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.security, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Videos are encrypted and secure',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Downloaded Videos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Download videos to watch offline',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.explore, color: Colors.white),
            label: const Text('Browse Movies', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    return RefreshIndicator(
      onRefresh: _loadDownloads,
      color: const Color(0xFFE50914),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: downloadedVideos.length,
        itemBuilder: (context, index) {
          final video = downloadedVideos[index];
          final isSelected = selectedVideos.contains(video.id);

          return Card(
            color: isSelected ? const Color(0xFFE50914).withOpacity(0.2) : const Color(0xFF181818),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                if (isSelectionMode) {
                  _toggleSelection(video.id);
                } else {
                  _playOfflineVideo(video);
                }
              },
              onLongPress: () {
                if (!isSelectionMode) {
                  _startSelectionMode(video.id);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.file(
                            File(video.thumbnailUrl), // Local thumbnail path
                            width: 80,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 80,
                              height: 60,
                              color: const Color(0xFF333333),
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                          ),
                          // Encryption indicator
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                          // Play overlay
                          if (!isSelectionMode)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          // Selection indicator
                          if (isSelectionMode)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0xFFE50914).withOpacity(0.8)
                                      : Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Video info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${video.year} • ${video.genre}',
                            style: const TextStyle(
                              color: Color(0xFFB3B3B3),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${video.duration} min',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.offline_pin,
                                size: 16,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Offline',
                                style: TextStyle(
                                  color: Colors.green.shade400,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action button
                    if (!isSelectionMode)
                      IconButton(
                        onPressed: () => _showVideoInfo(video),
                        icon: const Icon(
                          Icons.more_vert,
                          color: Color(0xFFB3B3B3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}