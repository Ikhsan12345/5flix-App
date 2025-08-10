import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final bool isOffline;

  const VideoPlayerScreen({
    super.key,
    required this.video,
    this.isOffline = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isFullScreen = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;
  bool _useExternalPlayer = false;

  @override
  void initState() {
    super.initState();
    // Set landscape orientation untuk pengalaman menonton yang lebih baik
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Hide system UI untuk fullscreen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    if (widget.isOffline) {
      _initializeOfflinePlayer();
    } else {
      _checkVideoPlayability();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Clean up temporary files if offline
    if (widget.isOffline) {
      _cleanupTempFile();
    }
    // Reset orientation dan system UI ketika keluar
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _checkVideoPlayability() async {
    // For online videos, check if we should use built-in player or external player
    // You can add logic here to determine video format compatibility
    final videoUrl = widget.video.videoUrl.toLowerCase();
    
    if (videoUrl.endsWith('.mp4') || videoUrl.endsWith('.m4v') || 
        videoUrl.endsWith('.mov') || videoUrl.endsWith('.3gp')) {
      // Try to use built-in player for common formats
      _initializeOnlinePlayer();
    } else {
      // Use external player for other formats
      setState(() {
        _useExternalPlayer = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeOnlinePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
      await _controller!.initialize();

      _controller!.addListener(_videoListener);

      setState(() {
        _duration = _controller!.value.duration;
        _isLoading = false;
      });

      // Auto-hide controls after 3 seconds
      _startControlsTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _useExternalPlayer = true; // Fallback to external player
      });
    }
  }

  Future<void> _initializeOfflinePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // For offline videos, the video path is already decrypted
      _controller = VideoPlayerController.file(File(widget.video.videoUrl));
      await _controller!.initialize();

      _controller!.addListener(_videoListener);

      setState(() {
        _duration = _controller!.value.duration;
        _isLoading = false;
      });

      // Auto-hide controls after 3 seconds
      _startControlsTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading offline video: ${e.toString()}';
      });
    }
  }

  void _videoListener() {
    if (mounted && _controller != null) {
      setState(() {
        _position = _controller!.value.position;
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
        _startControlsTimer();
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _seek(Duration position) {
    _controller?.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  Future<void> _cleanupTempFile() async {
    try {
      if (widget.isOffline && widget.video.videoUrl.contains('temp_')) {
        final file = File(widget.video.videoUrl);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp file: $e');
    }
  }

  Future<void> _playInExternalPlayer() async {
    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(widget.video.videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Cannot play video in external player');
      }
    } catch (e) {
      _showErrorSnackBar('Error playing video: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE50914),
        ),
      );
    }
  }

  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181818),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isOffline) ...[
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.white),
                title: const Text('Open in External Player', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _playInExternalPlayer();
                },
              ),
            ],
            ListTile(
              leading: Icon(
                widget.isOffline ? Icons.offline_pin : Icons.cloud,
                color: widget.isOffline ? Colors.green : Colors.blue,
              ),
              title: Text(
                widget.isOffline ? 'Playing Offline (Encrypted)' : 'Playing Online',
                style: TextStyle(
                  color: widget.isOffline ? Colors.green : Colors.blue,
                ),
              ),
              subtitle: Text(
                widget.isOffline 
                    ? 'Video is decrypted for playback only'
                    : 'Streaming from server',
                style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Video Info', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showVideoInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Text(
          widget.video.title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Genre: ${widget.video.genre}', style: const TextStyle(color: Color(0xFFB3B3B3))),
            Text('Year: ${widget.video.year}', style: const TextStyle(color: Color(0xFFB3B3B3))),
            Text('Duration: ${widget.video.duration} minutes', style: const TextStyle(color: Color(0xFFB3B3B3))),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  widget.isOffline ? Icons.offline_pin : Icons.cloud,
                  color: widget.isOffline ? Colors.green : Colors.blue,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isOffline ? 'Offline (Encrypted)' : 'Online',
                  style: TextStyle(
                    color: widget.isOffline ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            if ((widget.video.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Description:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.video.description ?? '',
                style: const TextStyle(color: Color(0xFFB3B3B3)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video player or thumbnail
            Center(
              child: _isLoading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFE50914)),
                        SizedBox(height: 16),
                        Text(
                          'Loading video...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    )
                  : _errorMessage != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE50914),
                              ),
                              child: const Text(
                                'Go Back',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        )
                      : _useExternalPlayer
                          ? GestureDetector(
                              onTap: _toggleControls,
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(widget.video.thumbnailUrl),
                                    fit: BoxFit.cover,
                                    onError: (error, stackTrace) {
                                      // Handle image load error
                                    },
                                  ),
                                ),
                                child: Container(
                                  color: Colors.black.withOpacity(0.3),
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: _playInExternalPlayer,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE50914).withOpacity(0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : GestureDetector(
                              onTap: _toggleControls,
                              child: _controller != null
                                  ? AspectRatio(
                                      aspectRatio: _controller!.value.aspectRatio,
                                      child: VideoPlayer(_controller!),
                                    )
                                  : Container(),
                            ),
            ),

            // Offline indicator
            if (widget.isOffline)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Encrypted Offline',
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

            // Controls overlay
            if (_showControls && !_isLoading && _errorMessage == null && !_useExternalPlayer)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.video.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${widget.video.year} • ${widget.video.genre} • ${widget.video.duration} min',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showVideoOptions,
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),

                    // Center play/pause button
                    if (_controller != null)
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                    const Spacer(),
                    
                    // Bottom controls
                    if (_controller != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Progress bar
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFFE50914),
                                inactiveTrackColor: Colors.white.withOpacity(0.3),
                                thumbColor: const Color(0xFFE50914),
                                overlayColor: const Color(0xFFE50914).withOpacity(0.2),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _duration.inMilliseconds > 0 
                                    ? _position.inMilliseconds.toDouble()
                                    : 0.0,
                                max: _duration.inMilliseconds > 0 
                                    ? _duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  _seek(Duration(milliseconds: value.round()));
                                },
                              ),
                            ),

                            // Time indicators
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_position),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            
                            // Control buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    final newPosition = _position - const Duration(seconds: 10);
                                    _seek(newPosition > Duration.zero ? newPosition : Duration.zero);
                                  },
                                  icon: const Icon(
                                    Icons.replay_10,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                
                                // Main play button
                                GestureDetector(
                                  onTap: _togglePlayPause,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                
                                IconButton(
                                  onPressed: () {
                                    final newPosition = _position + const Duration(seconds: 10);
                                    _seek(newPosition < _duration ? newPosition : _duration);
                                  },
                                  icon: const Icon(
                                    Icons.forward_10,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // External player controls overlay
            if (_useExternalPlayer && _showControls)
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.video.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${widget.video.year} • ${widget.video.genre} • ${widget.video.duration} min',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showVideoOptions,
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // External player message
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'External Player Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This video format requires an external media player to play properly.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Play button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: _playInExternalPlayer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 28),
                        label: const Text(
                          'Open in External Player',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}