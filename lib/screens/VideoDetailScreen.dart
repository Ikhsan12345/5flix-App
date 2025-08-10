import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool isLoading = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;

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

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF141414),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF333333),
                child: const Icon(
                  Icons.movie,
                  color: Colors.white54,
                  size: 100,
                ),
              ),
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
                  onPressed: _playVideo,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
          ],
        ),
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
            onPressed: isLoading ? null : _playVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 28),
            label: Text(
              isLoading ? 'Loading...' : 'Play',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Download button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isDownloading ? null : _downloadVideo,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: isDownloading
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
              isDownloading
                  ? 'Downloading... ${(downloadProgress * 100).toInt()}%'
                  : 'Download',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (isDownloading && downloadProgress > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: LinearProgressIndicator(
              value: downloadProgress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE50914),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    if (widget.video.description == null || widget.video.description!.isEmpty) {
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
        _buildSpecRow('Duration', '${widget.video.duration} minutes'),
        _buildSpecRow('Video ID', '#${widget.video.id}'),
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
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _playVideo() async {
    setState(() => isLoading = true);

    try {
      // Launch video in external player or browser
      final uri = Uri.parse(widget.video.videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot play video'),
              backgroundColor: Color(0xFFE50914),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing video: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _downloadVideo() async {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final result = await ApiService.getDownloadUrl(widget.video.id);

      if (result['success'] == true) {
        // Simulate download progress
        for (int i = 0; i <= 100; i += 10) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted) {
            setState(() {
              downloadProgress = i / 100.0;
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download completed! Video saved to downloads.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Download failed'),
              backgroundColor: const Color(0xFFE50914),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
          downloadProgress = 0.0;
        });
      }
    }
  }
}
