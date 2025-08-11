import 'package:flutter/material.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/models/video_model.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AuthorizedNetworkImage extends StatefulWidget {
  final VideoModel video;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const AuthorizedNetworkImage({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  State<AuthorizedNetworkImage> createState() => _AuthorizedNetworkImageState();
}

class _AuthorizedNetworkImageState extends State<AuthorizedNetworkImage> {
  Uint8List? imageData;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(AuthorizedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      isLoading = true;
      hasError = false;
      imageData = null;
    });

    try {
      // Use the authorized thumbnail URL from API
      final thumbnailUrl = ApiService.getAuthorizedThumbnailUrl(widget.video.id);
      
      debugPrint('AuthorizedNetworkImage: Loading thumbnail for video ${widget.video.id}');
      debugPrint('AuthorizedNetworkImage: URL: $thumbnailUrl');

      // Make request with authorization headers
      final response = await http.get(
        Uri.parse(thumbnailUrl),
        headers: {
          'Authorization': 'Bearer ${ApiService.getCurrentToken() ?? ''}',
          'User-Agent': 'FiveFlix-Mobile-App/1.0',
          'Accept': 'image/*',
          'Referer': 'https://5flix-backend-production.up.railway.app',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('AuthorizedNetworkImage: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        setState(() {
          imageData = response.bodyBytes;
          isLoading = false;
          hasError = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Authentication required';
        });
      } else if (response.statusCode == 404) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Thumbnail not found';
        });
      } else if (response.statusCode == 429) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Rate limit exceeded';
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Failed to load (${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('AuthorizedNetworkImage: Error loading thumbnail: $e');
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Network error: ${e.toString().split(':').first}';
      });
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1a1a1a),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ?? Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF2a2a2a),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.red[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Image failed to load',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.video.title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _loadImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              imageData!,
              fit: widget.fit,
              gaplessPlayback: true,
            ),
            // Quality badge overlay
            if (widget.video.isHighQuality)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    widget.video.qualityBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Featured badge overlay
            if (widget.video.isFeatured)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'FEATURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Duration overlay
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.video.displayDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildPlaceholder();
    }

    if (hasError || imageData == null) {
      return _buildErrorWidget();
    }

    return _buildImage();
  }
}

// Alternative simple network image for non-B2 thumbnails
class SimpleNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const SimpleNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: Image.network(
        imageUrl,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          return placeholder ?? Container(
            color: const Color(0xFF1a1a1a),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? Container(
            color: const Color(0xFF2a2a2a),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.red,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Smart image widget that chooses the appropriate loading method
class SmartVideoThumbnail extends StatelessWidget {
  final VideoModel video;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const SmartVideoThumbnail({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Use AuthorizedNetworkImage for B2 storage or when stream URL is available
    if (video.isB2Thumbnail || video.streamUrl != null) {
      return AuthorizedNetworkImage(
        video: video,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        width: width,
        height: height,
      );
    }
    
    // Use simple network image for regular URLs
    return SimpleNetworkImage(
      imageUrl: video.thumbnailUrl,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
      width: width,
      height: height,
    );
  }
}