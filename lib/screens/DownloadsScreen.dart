import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/models/download_model.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:five_flix/screens/VideoPlayerScreen.dart';
import 'dart:io';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<VideoModel> downloadedVideos = [];
  List<DownloadModel> downloadModels = [];
  bool isLoading = true;
  Map<String, dynamic> statistics = {};
  bool isSelectionMode = false;
  Set<int> selectedVideos = {};
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  @override
  void dispose() {
    // Clean temporary files when leaving downloads screen
    DownloadService.cleanTemporaryFiles();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() => isLoading = true);

    try {
      final videos = await DownloadService.getDownloadedVideos();
      final models = await DownloadService.getDownloadModels();
      final stats = await DownloadService.getDownloadStatistics();

      if (mounted) {
        setState(() {
          downloadedVideos = videos;
          downloadModels = models;
          statistics = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error loading downloads: $e');
      }
    }
  }

  Future<void> _searchDownloads(String query) async {
    if (!mounted) return;
    
    setState(() {
      searchQuery = query;
      isLoading = true;
    });

    try {
      final results = await DownloadService.searchDownloads(query);
      
      if (mounted) {
        setState(() {
          downloadedVideos = results;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error searching downloads: $e');
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (selectedVideos.isEmpty) return;

    final confirm = await _showConfirmDialog(
      'Delete Downloads',
      'Delete ${selectedVideos.length} downloaded video${selectedVideos.length > 1 ? 's' : ''}? This action cannot be undone.',
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

        await _loadDownloads();
        _showSuccessSnackBar('Downloads deleted successfully');
      } catch (e) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error deleting downloads: $e');
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirm = await _showConfirmDialog(
      'Clear All Downloads',
      'This will delete all downloaded videos and free up storage space. This action cannot be undone.',
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        await DownloadService.clearAllDownloads();
        await _loadDownloads();
        _showSuccessSnackBar('All downloads cleared successfully');
      } catch (e) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Error clearing downloads: $e');
      }
    }
  }

  Future<void> _optimizeStorage() async {
    setState(() => isLoading = true);

    try {
      final results = await DownloadService.optimizeStorage();
      await _loadDownloads();
      
      final message = 'Storage optimized!\n'
          'Temp files deleted: ${results['temp_files_deleted']}\n'
          'Failed downloads removed: ${results['failed_downloads_removed']}\n'
          'Orphaned files deleted: ${results['orphaned_files_deleted']}';
      
      _showSuccessSnackBar(message);
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error optimizing storage: $e');
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
      _showLoadingDialog('Preparing video...');

      // Verify download integrity
      final isValid = await DownloadService.verifyDownloadIntegrity(video.id);
      if (!isValid) {
        throw Exception('Download corrupted or incomplete');
      }

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
      
      _showErrorSnackBar('Error playing video: $e');
    }
  }

  void _showVideoInfo(VideoModel video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildVideoInfoSheet(video),
    );
  }

  Future<void> _deleteVideo(int videoId) async {
    final confirm = await _showConfirmDialog(
      'Delete Download',
      'Are you sure you want to delete this downloaded video? This action cannot be undone.',
    );

    if (confirm == true) {
      try {
        await DownloadService.deleteDownload(videoId);
        await _loadDownloads();
        _showSuccessSnackBar('Video deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Error deleting video: $e');
      }
    }
  }

  Future<void> _exportDownloadList() async {
    try {
      final exportData = await DownloadService.exportDownloadList();
      
      // In a real app, you might want to save this to a file or share it
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF181818),
          title: const Text('Download List', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Text(
              exportData,
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFFE50914))),
            ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error exporting download list: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFE50914)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Color(0xFFB3B3B3))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE50914),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              )
            : Column(
                children: [
                  if (!isSelectionMode) _buildSearchBar(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
                  case 'optimize_storage':
                    _optimizeStorage();
                    break;
                  case 'clean_temp':
                    DownloadService.cleanTemporaryFiles();
                    _showSuccessSnackBar('Temporary files cleaned');
                    break;
                  case 'export_list':
                    _exportDownloadList();
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
                  value: 'optimize_storage',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Text('Optimize Storage', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'export_list',
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Text('Export List', style: TextStyle(color: Colors.white)),
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
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search downloads...',
          hintStyle: TextStyle(color: Color(0xFFB3B3B3)),
          prefixIcon: Icon(Icons.search, color: Color(0xFFB3B3B3)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (query) {
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == query) {
              _searchDownloads(query);
            }
          });
        },
      ),
    );
  }

  Widget _buildStorageInfo() {
    final totalSize = statistics['total_size'] ?? 0;
    final completedCount = statistics['completed_count'] ?? 0;
    final failedCount = statistics['failed_count'] ?? 0;
    final downloadingCount = statistics['downloading_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, color: Color(0xFFE50914)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedCount videos downloaded',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total size: ${DownloadService.formatFileSize(totalSize)}',
                      style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (failedCount > 0 || downloadingCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (downloadingCount > 0) ...[
                  Icon(Icons.download, color: Colors.blue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$downloadingCount downloading',
                    style: TextStyle(color: Colors.blue, fontSize: 11),
                  ),
                  const SizedBox(width: 16),
                ],
                if (failedCount > 0) ...[
                  Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$failedCount failed',
                    style: TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isNotEmpty ? Icons.search_off : Icons.download_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty ? 'No downloads found' : 'No Downloaded Videos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty 
                ? 'Try a different search term'
                : 'Download videos to watch offline',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (searchQuery.isEmpty)
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
          final downloadModel = downloadModels.firstWhere(
            (model) => model.videoId == video.id,
            orElse: () => DownloadModel.fromVideoModel(
              video,
              localPath: '',
              fileSize: 0,
            ),
          );

          return _buildDownloadItem(video, downloadModel, isSelected);
        },
      ),
    );
  }

  Widget _buildDownloadItem(VideoModel video, DownloadModel downloadModel, bool isSelected) {
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
              _buildThumbnail(video, downloadModel, isSelected),
              const SizedBox(width: 12),
              // Video info
              Expanded(
                child: _buildVideoInfo(video, downloadModel),
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
  }

  Widget _buildThumbnail(VideoModel video, DownloadModel downloadModel, bool isSelected) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Thumbnail image
          _buildThumbnailImage(downloadModel),
          
          // Encryption indicator
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: downloadModel.isEncrypted 
                    ? Colors.green.withOpacity(0.8)
                    : Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                downloadModel.isEncrypted ? Icons.security : Icons.warning,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
          
          // Quality badge
          if (downloadModel.quality != null)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  downloadModel.qualityBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          // Play/Selection overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelectionMode
                    ? (isSelected ? Icons.check_circle : Icons.radio_button_unchecked)
                    : Icons.play_circle_filled,
                color: isSelectionMode && isSelected
                    ? const Color(0xFFE50914)
                    : Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage(DownloadModel downloadModel) {
    final thumbnailPath = downloadModel.thumbnailLocalPath ?? downloadModel.thumbnailUrl;
    
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      return Image.file(
        File(thumbnailPath),
        width: 80,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderThumbnail(),
      );
    }
    
    return _buildPlaceholderThumbnail();
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 80,
      height: 60,
      color: const Color(0xFF333333),
      child: const Icon(
        Icons.movie,
        color: Colors.white54,
        size: 30,
      ),
    );
  }

  Widget _buildVideoInfo(VideoModel video, DownloadModel downloadModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
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
        
        // Genre and year
        Text(
          '${video.year} • ${video.genre}',
          style: const TextStyle(
            color: Color(0xFFB3B3B3),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        
        // Duration, size, and status
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
            const SizedBox(width: 8),
            Icon(
              Icons.storage,
              size: 12,
              color: Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              downloadModel.displayFileSize,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            _buildStatusIndicator(downloadModel),
          ],
        ),
        
        // Download date
        const SizedBox(height: 2),
        Text(
          'Downloaded ${_formatDownloadDate(downloadModel.downloadedAt)}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(DownloadModel downloadModel) {
    Color color;
    IconData icon;
    String text;

    switch (downloadModel.downloadStatus) {
      case 'completed':
        color = Colors.green.shade400;
        icon = Icons.offline_pin;
        text = 'Offline';
        break;
      case 'downloading':
        color = Colors.blue.shade400;
        icon = Icons.download;
        text = 'Downloading';
        break;
      case 'failed':
        color = Colors.red.shade400;
        icon = Icons.error;
        text = 'Failed';
        break;
      case 'cancelled':
        color = Colors.orange.shade400;
        icon = Icons.cancel;
        text = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        text = 'Unknown';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfoSheet(VideoModel video) {
    final downloadModel = downloadModels.firstWhere(
      (model) => model.videoId == video.id,
      orElse: () => DownloadModel.fromVideoModel(video, localPath: '', fileSize: 0),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _buildThumbnailImage(downloadModel),
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
                    const SizedBox(height: 4),
                    _buildStatusIndicator(downloadModel),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
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
            video.description ?? 'No description available',
            style: const TextStyle(
              color: Color(0xFFB3B3B3),
              fontSize: 12,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Download details
          _buildDownloadDetails(downloadModel),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              if (downloadModel.downloadStatus == 'completed') ...[
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
              ],
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
    );
  }

  Widget _buildDownloadDetails(DownloadModel downloadModel) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download Details:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildDetailRow('Size', downloadModel.displayFileSize),
          _buildDetailRow('Quality', downloadModel.qualityBadge),
          _buildDetailRow('Encryption', downloadModel.isEncrypted ? 'Enabled (XOR)' : 'Disabled'),
          _buildDetailRow('Downloaded', _formatDownloadDate(downloadModel.downloadedAt)),
          if (downloadModel.lastAccessedAt != null)
            _buildDetailRow('Last Played', _formatDownloadDate(downloadModel.lastAccessedAt!)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDownloadDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}