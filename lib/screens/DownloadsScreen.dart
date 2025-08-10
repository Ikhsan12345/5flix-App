import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:five_flix/screens/VideoDetailScreen.dart';
import 'package:five_flix/screens/VideoPlayerScreen.dart';

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
          SnackBar(content: Text('Error loading downloads: $e')),
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
        backgroundColor: const Color(0xFF181414),
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
            ),
            IconButton(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
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
                  }
                },
                itemBuilder: (BuildContext context) => [
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