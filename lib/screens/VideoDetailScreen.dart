// ============================================================================
// FIXED VideoDetailScreen.dart - SliverAppBar Implementation
// ============================================================================

import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/screens/VideoPlayerScreen.dart';

class VideoDetailScreen extends StatefulWidget {
  final VideoModel video;
  final String userRole;

  const VideoDetailScreen({
    super.key,
    required this.video,
    required this.userRole,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
    _debugVideoUrls();
  }

  Future<void> _checkDownloadStatus() async {
    final isDownloaded = await DownloadService.isVideoDownloaded(widget.video.id);
    setState(() {
      _isDownloaded = isDownloaded;
    });
  }

  void _debugVideoUrls() {
    print('=== DEBUG VIDEO URLS ===');
    print('Video ID: ${widget.video.id}');
    print('Video Title: ${widget.video.title}');
    print('Thumbnail URL: ${widget.video.thumbnailUrl}');
    print('Video URL: ${widget.video.videoUrl}');
    print('Is B2 Thumbnail: ${widget.video.isB2Thumbnail ?? 'Property not available'}');
    print('Is B2 Video: ${widget.video.isB2Video ?? 'Property not available'}');
    print('Thumbnail URL length: ${widget.video.thumbnailUrl.length}');
    print('Video URL length: ${widget.video.videoUrl.length}');
    
    // Check if URLs are valid
    bool isThumbnailValid = Uri.tryParse(widget.video.thumbnailUrl) != null;
    bool isVideoValid = Uri.tryParse(widget.video.videoUrl) != null;
    
    print('Thumbnail URL valid: $isThumbnailValid');
    print('Video URL valid: $isVideoValid');
    print('Auth token available: ${ApiService.getCurrentToken() != null}');
    print('========================');
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting download...';
    });

    final success = await DownloadService.downloadVideoWithProgress(
      widget.video,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
      onStatusChange: (status) {
        setState(() {
          _downloadStatus = status;
        });
      },
    );

    setState(() {
      _isDownloading = false;
      _isDownloaded = success;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Video downloaded successfully' : 'Download failed'),
          backgroundColor: success ? Colors.green : const Color(0xFFE50914),
        ),
      );
    }
  }

  Future<void> _deleteDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Delete Download', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this downloaded video?',
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
      final success = await DownloadService.deleteDownload(widget.video.id);
      setState(() {
        _isDownloaded = !success;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Download deleted' : 'Failed to delete download'),
            backgroundColor: success ? Colors.green : const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  Future<void> _playOfflineVideo() async {
    try {
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

      final decryptedFile = await DownloadService.getDecryptedVideoFile(widget.video.id);
      
      if (mounted) Navigator.pop(context);

      if (decryptedFile != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              video: widget.video.copyWith(videoUrl: decryptedFile.path),
              isOffline: true,
            ),
          ),
        );
      } else {
        throw Exception('Failed to decrypt video file');
      }
    } catch (e) {
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

  Future<void> _playOnlineVideo() async {
    try {
      print('=== PLAYING ONLINE VIDEO ===');
      print('Video: ${widget.video.title}');
      print('Original URL: ${widget.video.videoUrl}');
      
      // Check if this is a B2 URL
      bool isB2Url = widget.video.videoUrl.contains('backblazeb2.com') || 
                    widget.video.videoUrl.contains('.b2.');
      print('Is B2 URL: $isB2Url');

      // Show loading
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
              Text('Preparing video...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      String? playableUrl;

      if (isB2Url) {
        // Try to get authorized URL from backend
        playableUrl = await ApiService.getAuthorizedMediaUrl(widget.video.id, 'video');
        
        if (playableUrl == null) {
          // Show error - B2 needs backend support
          if (mounted) Navigator.pop(context);
          
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF181818),
                title: const Text('Video Not Available', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This video is stored in B2 cloud storage and requires backend authorization to stream.',
                      style: TextStyle(color: Color(0xFFB3B3B3)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Contact administrator to enable B2 streaming support',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Video URL: ${widget.video.videoUrl}',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(color: Color(0xFFE50914))),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } else {
        // Regular URL
        playableUrl = widget.video.videoUrl;
      }

      // Close loading
      if (mounted) Navigator.pop(context);

      print('Final playable URL: $playableUrl');

      // Navigate to player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            video: widget.video.copyWith(videoUrl: playableUrl),
            isOffline: false,
          ),
        ),
      );

    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing video: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  void _debugAndPlayVideo() {
    print('=== DEBUG PLAY VIDEO ===');
    print('Is Downloaded: $_isDownloaded');
    print('Video URL: ${widget.video.videoUrl}');
    print('Video URL valid: ${Uri.tryParse(widget.video.videoUrl) != null}');
    
    if (_isDownloaded) {
      print('Playing offline video...');
      _playOfflineVideo();
    } else {
      print('Playing online video...');
      _playOnlineVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVideoInfo(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  _buildVideoSpecs(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FIXED SliverAppBar - Remove conflicting parameters
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF141414),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Use AuthorizedNetworkImage if available, otherwise fallback to regular image
            Container(
              width: double.infinity,
              height: double.infinity,
              child: _buildThumbnailImage(),
            ),
            
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xFF141414)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            
            // Play button overlay
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _debugAndPlayVideo,
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
            
            // Featured badge
            if (widget.video.isFeatured)
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
            // Downloaded badge
            if (_isDownloaded)
              Positioned(
                top: 60,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.offline_pin, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'DOWNLOADED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Separate method to build thumbnail image with proper error handling
  Widget _buildThumbnailImage() {
    // Check if we have AuthorizedNetworkImage available
    // If not, use regular Image.network with enhanced headers
    
    if (widget.video.thumbnailUrl.isEmpty) {
      return _buildPlaceholderThumbnail('No thumbnail URL available');
    }

    // Try with authorization headers first
    return Image.network(
      widget.video.thumbnailUrl,
      fit: BoxFit.cover,
      headers: {
        'User-Agent': 'FiveFlix-Mobile-App/1.0',
        'Accept': 'image/*',
        'Connection': 'keep-alive',
        'Cache-Control': 'no-cache',
        if (ApiService.getCurrentToken() != null)
          'Authorization': 'Bearer ${ApiService.getCurrentToken()}',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return Container(
          color: const Color(0xFF333333),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loading thumbnail...',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '${((loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)) * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Thumbnail loading error: $error');
        print('Thumbnail URL: ${widget.video.thumbnailUrl}');
        print('Stack trace: $stackTrace');
        
        // Check if it's a B2 URL
        bool isB2 = widget.video.thumbnailUrl.contains('backblazeb2.com') || 
                   widget.video.thumbnailUrl.contains('.b2.');
        
        return Container(
          color: const Color(0xFF333333),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isB2 ? Icons.cloud_off : Icons.broken_image,
                color: isB2 ? Colors.orange : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 8),
              Text(
                isB2 ? 'B2 Authorization Required' : 'Thumbnail failed to load',
                style: TextStyle(
                  color: isB2 ? Colors.orange : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              if (isB2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Backend streaming support needed',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'URL: ${widget.video.thumbnailUrl.length > 40 ? '${widget.video.thumbnailUrl.substring(0, 40)}...' : widget.video.thumbnailUrl}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderThumbnail(String message) {
    return Container(
      color: const Color(0xFF333333),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.movie,
            color: Colors.white54,
            size: 100,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Rest of your existing methods remain the same...
  Widget _buildVideoInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.video.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${widget.video.year}',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFB3B3B3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.video.genre,
                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${widget.video.duration} min',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Play button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isDownloaded ? _playOfflineVideo : _playOnlineVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              _isDownloaded ? Icons.offline_pin : Icons.play_arrow,
              size: 28,
            ),
            label: Text(
              _isDownloaded ? 'Play Offline' : 'Play Online',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Download/Delete button
        SizedBox(
          width: double.infinity,
          child: _isDownloaded
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _deleteDownload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.delete, size: 24),
                        label: const Text(
                          'Delete Download',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Encrypted',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : OutlinedButton.icon(
                  onPressed: _isDownloading ? null : _downloadVideo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download, size: 24),
                  label: Text(
                    _isDownloading
                        ? _downloadStatus.isNotEmpty 
                            ? _downloadStatus
                            : 'Downloading... ${(_downloadProgress * 100).toInt()}%'
                        : 'Download & Encrypt',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        if (_isDownloading && _downloadProgress > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _downloadProgress,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE50914),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _downloadStatus,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    final desc = widget.video.description ?? '';
    if (desc.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.video.description ?? '',
          style: const TextStyle(
            color: Color(0xFFB3B3B3),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSpecs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildSpecRow('Genre', widget.video.genre),
        _buildSpecRow('Year', '${widget.video.year}'),
        _buildSpecRow('Duration', '${widget.video.duration} minutes'),
        _buildSpecRow('Video ID', '#${widget.video.id}'),
        _buildSpecRow('Thumbnail URL', widget.video.thumbnailUrl.contains('backblazeb2.com') ? 'B2 Cloud Storage' : 'Local Storage'),
        _buildSpecRow('Video URL', widget.video.videoUrl.contains('backblazeb2.com') ? 'B2 Cloud Storage' : 'Local Storage'),
        if (_isDownloaded) ...[
          _buildSpecRow('Status', 'Downloaded & Encrypted'),
          _buildSpecRow('Storage', 'Secure Local Storage'),
        ] else
          _buildSpecRow('Status', 'Online Only'),
      ],
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value.contains('Downloaded') || 
                       value.contains('Secure') ||
                       value.contains('B2 Cloud')
                    ? Colors.green 
                    : Colors.white,
                fontSize: 14,
                fontWeight: value.contains('Downloaded') || 
                           value.contains('Secure') ||
                           value.contains('B2 Cloud')
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}