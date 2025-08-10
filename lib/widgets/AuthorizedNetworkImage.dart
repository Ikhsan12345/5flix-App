import 'package:flutter/material.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/models/video_model.dart';

class AuthorizedNetworkImage extends StatefulWidget {
  final VideoModel video;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AuthorizedNetworkImage({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AuthorizedNetworkImage> createState() => _AuthorizedNetworkImageState();
}

class _AuthorizedNetworkImageState extends State<AuthorizedNetworkImage> {
  String? authorizedUrl;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAuthorizedImage();
  }

  Future<void> _loadAuthorizedImage() async {
    if (!widget.video.isB2Thumbnail) {
      // Regular URL, no need for authorization
      setState(() {
        authorizedUrl = widget.video.thumbnailUrl;
        isLoading = false;
      });
      return;
    }

    try {
      // Try to get authorized URL from backend
      final authUrl = await ApiService.getAuthorizedMediaUrl(widget.video.id, 'thumbnail');
      
      if (authUrl != null) {
        setState(() {
          authorizedUrl = authUrl;
          isLoading = false;
        });
      } else {
        // Fallback: try original URL with different headers
        final canAccess = await ApiService.testUrlAccess(
          widget.video.thumbnailUrl,
          headers: {
            'Authorization': 'Bearer ${ApiService.getCurrentToken() ?? ''}',
            'User-Agent': 'FiveFlix-Mobile-App/1.0',
            'Accept': 'image/*',
            'Referer': 'https://5flix-backend-production.up.railway.app',
          },
        );

        if (canAccess) {
          setState(() {
            authorizedUrl = widget.video.thumbnailUrl;
            isLoading = false;
          });
        } else {
          setState(() {
            hasError = true;
            isLoading = false;
            errorMessage = 'B2 authorization required';
          });
        }
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
        errorMessage = 'Failed to load thumbnail: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return widget.placeholder ?? Container(
        color: const Color(0xFF333333),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (hasError || authorizedUrl == null) {
      return widget.errorWidget ?? Container(
        color: const Color(0xFF333333),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Image failed to load',
              style: const TextStyle(color: Colors.red, fontSize: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.video.title,
              style: const TextStyle(color: Colors.white54, fontSize: 8),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Image.network(
      authorizedUrl!,
      fit: widget.fit,
      headers: {
        'User-Agent': 'FiveFlix-Mobile-App/1.0',
        'Accept': 'image/*',
        'Authorization': 'Bearer ${ApiService.getCurrentToken() ?? ''}',
        'Referer': 'https://5flix-backend-production.up.railway.app',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ?? Container(
          color: const Color(0xFF333333),
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image network error: $error');
        debugPrint('Image URL: $authorizedUrl');
        
        return widget.errorWidget ?? Container(
          color: const Color(0xFF333333),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_not_supported, color: Colors.orange, size: 40),
              const SizedBox(height: 8),
              Text(
                'Network error',
                style: const TextStyle(color: Colors.orange, fontSize: 10),
              ),
              Text(
                widget.video.title,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}