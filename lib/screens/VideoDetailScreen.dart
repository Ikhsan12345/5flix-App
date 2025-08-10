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
    _debugVideoInfo();
  }

  Future<void> _checkDownloadStatus() async {
    final isDownloaded = await DownloadService.isVideoDownloaded(widget.video.id);
    setState(() {
      _isDownloaded = isDownloaded;
    });
  }

  void _debugVideoInfo() {
    debugPrint('=== VIDEO DETAIL DEBUG INFO ===');
    debugPrint('Video: ${widget.video.toDebugString()}');
    debugPrint('Thumbnail URL: ${widget.video.displayThumbnailUrl}');
    debugPrint('Playback URL: ${widget.video.playbackUrl}');
    debugPrint('Duration: ${widget.video.displayDuration}');
    debugPrint('Is B2 Video: ${widget.video.isB2Video}');
    debugPrint('Is B2 Thumbnail: ${widget.video.isB2Thumbnail}');
    debugPrint('Stream URL available: ${widget.video.streamUrl != null}');
    debugPrint('Auth token available: ${ApiService.getCurrentToken() != null}');
    debugPrint('================================');
  }

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
    });

    try {
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
    } catch (e) {
      debugPrint('Download error: $e');
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Download failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
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
      debugPrint('Playing offline video: ${widget.video.title}');
      
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
                'Preparing offline video...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      final decryptedFile = await DownloadService.getDecryptedVideoFile(widget.video.id);
      
      if (mounted) Navigator.pop(context);

      if (decryptedFile != null && decryptedFile.existsSync()) {
        debugPrint('Playing decrypted file: ${decryptedFile.path}');
        
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
        throw Exception('Decrypted video file not found or inaccessible');
      }
    } catch (e) {
      debugPrint('Error playing offline video: $e');
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing offline video: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    }
  }

  Future<void> _playOnlineVideo() async {
    try {
      debugPrint('=== PLAYING ONLINE VIDEO ===');
      debugPrint('Video: ${widget.video.title}');
      debugPrint('Stream URL: ${widget.video.streamUrl}');
      debugPrint('Video URL: ${widget.video.videoUrl}');
      debugPrint('Playback URL: ${widget.video.playbackUrl}');
      debugPrint('Is B2 Video: ${widget.video.isB2Video}');

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
              Text('Preparing video stream...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      String? playableUrl;

      // Handle different URL scenarios
      if (widget.video.isB2Video) {
        debugPrint('B2 Video detected - getting authorized stream URL');
        
        // Try to get stream URL from backend
        playableUrl = await ApiService.getVideoStreamUrl(widget.video.id);
        
        if (playableUrl == null) {
          // Close loading dialog
          if (mounted) Navigator.pop(context);
          
          // Show B2 authorization error
          if (mounted) {
            _showB2AuthError();
          }
          return;
        }
        
        debugPrint('Got authorized B2 stream URL: $playableUrl');
      } else {
        // Use the best available URL
        playableUrl = widget.video.playbackUrl;
        debugPrint('Using direct playback URL: $playableUrl');
      }

      // Validate URL
      if (playableUrl.isEmpty || Uri.tryParse(playableUrl) == null) {
        throw Exception('Invalid video URL: $playableUrl');
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      debugPrint('Final playable URL: $playableUrl');

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
      debugPrint('Error playing online video: $e');
      
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

  void _showB2AuthError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Video Not Available', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This video is stored in B2 cloud storage and requires backend authorization to stream.',
              style: TextStyle(color: Color(0xFFB3B3B3)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Solution:',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Contact administrator to enable B2 streaming\n'
                    '• Or download the video for offline playback',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video ID: ${widget.video.id}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_isDownloaded && !_isDownloading)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadVideo();
              },
              icon: const Icon(Icons.download, color: Colors.blue, size: 18),
              label: const Text('Download', style: TextStyle(color: Colors.blue)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  void _playVideo() {
    debugPrint('=== PLAY VIDEO REQUESTED ===');
    debugPrint('Is Downloaded: $_isDownloaded');
    debugPrint('Is Downloading: $_isDownloading');
    
    if (_isDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for download to complete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_isDownloaded) {
      debugPrint('Playing offline video...');
      _playOfflineVideo();
    } else {
      debugPrint('Playing online video...');
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
                  if (widget.video.description?.isNotEmpty == true)
                    ...[_buildDescription(), const SizedBox(height: 24)],
                  _buildVideoSpecs(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            // Thumbnail image
            _buildThumbnailImage(),
            
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
                  onPressed: _playVideo,
                  icon: Icon(
                    _isDownloaded ? Icons.play_circle_filled : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
            
            // Status badges
            _buildStatusBadges(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadges() {
    return Stack(
      children: [
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
        
        // B2 Storage badge
        if (widget.video.isB2Video && !_isDownloaded)
          Positioned(
            top: widget.video.isFeatured ? 100 : 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'B2 STORAGE',
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
    );
  }

  Widget _buildThumbnailImage() {
    final thumbnailUrl = widget.video.displayThumbnailUrl;
    
    if (thumbnailUrl.isEmpty) {
      return _buildPlaceholderThumbnail('No thumbnail available');
    }

    return Image.network(
      thumbnailUrl,
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
                if (loadingProgress.expectedTotalBytes != null)
                  Text(
                    '${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Thumbnail loading error: $error');
        debugPrint('Thumbnail URL: $thumbnailUrl');
        
        return Container(
          color: const Color(0xFF333333),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.video.isB2Thumbnail ? Icons.cloud_off : Icons.broken_image,
                color: widget.video.isB2Thumbnail ? Colors.orange : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 8),
              Text(
                widget.video.isB2Thumbnail 
                    ? 'B2 Authorization Required' 
                    : 'Thumbnail failed to load',
                style: TextStyle(
                  color: widget.video.isB2Thumbnail ? Colors.orange : Colors.red,
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
              widget.video.displayDuration,
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
            onPressed: _isDownloading ? null : _playVideo,
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
              ? _buildDownloadedActions()
              : _buildDownloadButton(),
        ),
        
        // Download progress
        if (_isDownloading && _downloadProgress > 0)
          _buildDownloadProgress(),
      ],
    );
  }

  Widget _buildDownloadedActions() {
    return Row(
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
    );
  }

  Widget _buildDownloadButton() {
    return OutlinedButton.icon(
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
    );
  }

  Widget _buildDownloadProgress() {
    return Padding(
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
              Expanded(
                child: Text(
                  _downloadStatus,
                  style: const TextStyle(
                    color: Color(0xFFB3B3B3),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildDescription() {
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
          widget.video.description!,
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
        _buildSpecRow('Duration', widget.video.displayDuration),
        _buildSpecRow('Video ID', '#${widget.video.id}'),
        _buildSpecRow(
          'Storage Type', 
          widget.video.isB2Video ? 'B2 Cloud Storage' : 'Direct URL'
        ),
        _buildSpecRow(
          'Stream URL', 
          widget.video.streamUrl != null ? 'Available' : 'Not Available'
        ),
        if (_isDownloaded) ...[
          _buildSpecRow('Download Status', 'Downloaded & Encrypted'),
          _buildSpecRow('Local Storage', 'Secure Encrypted'),
        ] else if (_isDownloading) ...[
          _buildSpecRow('Download Status', 'Downloading...'),
          _buildSpecRow('Progress', '${(_downloadProgress * 100).toInt()}%'),
        ] else
          _buildSpecRow('Download Status', 'Online Only'),
        
        // Debug info for development
        if (widget.userRole == 'admin') ...[
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF333333)),
          const SizedBox(height: 8),
          const Text(
            'Debug Info (Admin Only)',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildSpecRow('Original Video URL', widget.video.originalVideoUrl ?? 'N/A'),
          _buildSpecRow('Original Thumbnail URL', widget.video.originalThumbnailUrl ?? 'N/A'),
          _buildSpecRow('Stream URL', widget.video.streamUrl ?? 'N/A'),
          _buildSpecRow('Is B2 Video', widget.video.isB2Video.toString()),
          _buildSpecRow('Is B2 Thumbnail', widget.video.isB2Thumbnail.toString()),
          _buildSpecRow('Created At', widget.video.createdAt?.toString() ?? 'N/A'),
          _buildSpecRow('Updated At', widget.video.updatedAt?.toString() ?? 'N/A'),
        ],
      ],
    );
  }

  Widget _buildSpecRow(String label, String value) {
    // Determine color based on content
    Color valueColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;
    
    if (value.contains('Downloaded') || value.contains('Encrypted') || value.contains('Available')) {
      valueColor = Colors.green;
      fontWeight = FontWeight.bold;
    } else if (value.contains('B2 Cloud') || value.contains('true')) {
      valueColor = Colors.orange;
      fontWeight = FontWeight.bold;
    } else if (value.contains('Downloading') || value.contains('%')) {
      valueColor = Colors.blue;
      fontWeight = FontWeight.bold;
    } else if (value.contains('N/A') || value.contains('Not Available') || value.contains('false')) {
      valueColor = const Color(0xFF666666);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: fontWeight,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}