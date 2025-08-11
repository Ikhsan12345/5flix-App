import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';

class ApiService {
  static const String baseUrl = 'https://5flix-backend-production.up.railway.app/api';
  static String? _authToken;
  
  // Set auth token
  static void setAuthToken(String token) {
    _authToken = token;
    debugPrint('ApiService: Auth token set - ${token.substring(0, 10)}...');
  }
  
  // Get current auth token
  static String? getCurrentToken() {
    return _authToken;
  }
  
  // Clear auth token
  static void clearAuthToken() {
    _authToken = null;
    debugPrint('ApiService: Auth token cleared');
  }
  
  // Get auth headers
  static Map<String, String> get _headers {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'FiveFlix-Mobile-App/1.0',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      debugPrint('ApiService: Using auth token for request');
    } else {
      debugPrint('ApiService: No auth token available');
    }
    
    return headers;
  }

  // Get multipart headers (for file uploads)
  static Map<String, String> get _multipartHeaders {
    Map<String, String> headers = {
      'Accept': 'application/json',
      'User-Agent': 'FiveFlix-Mobile-App/1.0',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      debugPrint('ApiService: Attempting login for user: $username');
      
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FiveFlix-Mobile-App/1.0',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Login response status: ${response.statusCode}');

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        setAuthToken(data['token']);
        return {
          'success': true,
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      debugPrint('ApiService: Login error - $e');
      return {
        'success': false,
        'message': 'Koneksi bermasalah: $e',
      };
    }
  }

  // Register
  static Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      debugPrint('ApiService: Attempting registration for user: $username');
      
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'FiveFlix-Mobile-App/1.0',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Registration response status: ${response.statusCode}');
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201 && data['success'] == true) {
        debugPrint('ApiService: Registration successful');
        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        debugPrint('ApiService: Registration failed - ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      debugPrint('ApiService: Registration error - $e');
      return {
        'success': false,
        'message': 'Koneksi bermasalah: $e',
      };
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      if (_authToken != null) {
        debugPrint('ApiService: Attempting logout');
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: _headers,
        ).timeout(const Duration(seconds: 15));
        debugPrint('ApiService: Logout request sent');
      }
    } catch (e) {
      debugPrint('ApiService: Logout error - $e');
    } finally {
      clearAuthToken();
    }
  }

  // Get user info (NEW - sesuai dengan route /user)
  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      debugPrint('ApiService: Fetching user info');
      
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ApiService: User info response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      } else if (response.statusCode == 401) {
        debugPrint('ApiService: Unauthorized - clearing token');
        clearAuthToken();
      }
      
      return null;
    } catch (e) {
      debugPrint('ApiService: Error fetching user info: $e');
      return null;
    }
  }

  // Get all videos (PUBLIC route with throttling)
  static Future<List<VideoModel>> getVideos() async {
    try {
      debugPrint('ApiService: Fetching videos...');
      debugPrint('ApiService: Using URL: $baseUrl/videos');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Videos response status: ${response.statusCode}');
      debugPrint('ApiService: Videos response length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('ApiService: Response parsed - success: ${data['success']}');
        
        if (data['success'] == true && data['data'] != null) {
          List<VideoModel> videos = [];
          final videoList = data['data'] as List;
          
          debugPrint('ApiService: Processing ${videoList.length} videos');
          
          for (int i = 0; i < videoList.length; i++) {
            try {
              final videoJson = videoList[i];
              debugPrint('ApiService: Processing video $i: ${videoJson['title']}');
              
              final video = VideoModel.fromJson(videoJson);
              videos.add(video);
              
              debugPrint('ApiService: Successfully parsed video: ${video.toDebugString()}');
            } catch (e, stackTrace) {
              debugPrint('ApiService: Error parsing video $i: $e');
              debugPrint('ApiService: Stack trace: $stackTrace');
              debugPrint('ApiService: Problematic video data: ${videoList[i]}');
            }
          }
          
          debugPrint('ApiService: Successfully parsed ${videos.length} out of ${videoList.length} videos');
          return videos;
        } else {
          debugPrint('ApiService: API response indicates failure: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 429) {
        debugPrint('ApiService: Rate limit exceeded');
        throw Exception('Rate limit exceeded. Please try again later.');
      } else {
        debugPrint('ApiService: HTTP error ${response.statusCode}: ${response.body}');
      }
      
      return [];
    } catch (e, stackTrace) {
      debugPrint('ApiService: Exception in getVideos: $e');
      debugPrint('ApiService: Stack trace: $stackTrace');
      return [];
    }
  }

  // Get single video (PUBLIC route)
  static Future<VideoModel?> getVideo(int id) async {
    try {
      debugPrint('ApiService: Fetching video with ID: $id');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ApiService: Single video response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return VideoModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('ApiService: Error fetching single video: $e');
      return null;
    }
  }

  // Get video info (NEW - sesuai dengan route baru)
  static Future<Map<String, dynamic>?> getVideoInfo(int videoId) async {
    try {
      debugPrint('ApiService: Getting video info for ID: $videoId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$videoId/info'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ApiService: Video info response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('ApiService: Error getting video info: $e');
      return null;
    }
  }

  // Get video stream URL (PUBLIC route dengan throttling tinggi)
  static Future<String?> getVideoStreamUrl(int videoId) async {
    try {
      debugPrint('ApiService: Getting stream URL for video ID: $videoId');
      
      // Return the direct streaming endpoint
      return '$baseUrl/videos/$videoId/stream';
      
    } catch (e) {
      debugPrint('ApiService: Error getting stream URL: $e');
      return null;
    }
  }

  // Get video thumbnail URL (PUBLIC route dengan throttling tinggi)
  static String getVideoThumbnailUrl(int videoId) {
    return '$baseUrl/videos/$videoId/thumbnail';
  }

  // Get featured videos (PROTECTED route)
  static Future<List<VideoModel>> getFeaturedVideos() async {
    try {
      debugPrint('ApiService: Fetching featured videos...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos-featured'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Featured videos response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        debugPrint('ApiService: Unauthorized - token required for featured videos');
        clearAuthToken();
        return [];
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          List<VideoModel> videos = [];
          final videoList = data['data'] as List;
          
          for (int i = 0; i < videoList.length; i++) {
            try {
              final video = VideoModel.fromJson(videoList[i]);
              videos.add(video);
            } catch (e) {
              debugPrint('ApiService: Error parsing featured video $i: $e');
            }
          }
          
          return videos;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('ApiService: Exception in getFeaturedVideos: $e');
      return [];
    }
  }

  // Upload video (ADMIN ONLY - PROTECTED route)
  static Future<Map<String, dynamic>> uploadVideo({
    required String title,
    required String genre,
    required String description,
    required int duration,
    required int year,
    required bool isFeatured,
    required File thumbnailFile,
    required File videoFile,
  }) async {
    try {
      debugPrint('ApiService: Uploading video: $title');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/videos'),
      );

      // Add headers
      request.headers.addAll(_multipartHeaders);

      // Add fields
      request.fields['title'] = title;
      request.fields['genre'] = genre;
      request.fields['description'] = description;
      request.fields['duration'] = duration.toString();
      request.fields['year'] = year.toString();
      request.fields['is_featured'] = isFeatured ? '1' : '0';

      // Add files
      request.files.add(await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailFile.path,
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'video',
        videoFile.path,
      ));

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('ApiService: Upload response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized - Admin access required',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Rate limit exceeded - Please wait before uploading again',
        };
      }

      final data = jsonDecode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
        'data': data['data'],
      };
    } catch (e) {
      debugPrint('ApiService: Upload error: $e');
      return {
        'success': false,
        'message': 'Upload error: $e',
      };
    }
  }

  // Update video (ADMIN ONLY - PROTECTED route)
  static Future<Map<String, dynamic>> updateVideo({
    required int id,
    String? title,
    String? genre,
    String? description,
    int? duration,
    int? year,
    bool? isFeatured,
    File? thumbnailFile,
    File? videoFile,
  }) async {
    try {
      debugPrint('ApiService: Updating video ID: $id');
      
      var request = http.MultipartRequest(
        'POST', // Backend expects POST with _method override
        Uri.parse('$baseUrl/videos/$id/update'), // Updated endpoint sesuai route
      );

      // Add headers
      request.headers.addAll(_multipartHeaders);

      // Add fields only if provided
      if (title != null) request.fields['title'] = title;
      if (genre != null) request.fields['genre'] = genre;
      if (description != null) request.fields['description'] = description;
      if (duration != null) request.fields['duration'] = duration.toString();
      if (year != null) request.fields['year'] = year.toString();
      if (isFeatured != null) request.fields['is_featured'] = isFeatured ? '1' : '0';

      // Add files if provided
      if (thumbnailFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'thumbnail',
          thumbnailFile.path,
        ));
      }
      if (videoFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'video',
          videoFile.path,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('ApiService: Update response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized - Admin access required',
        };
      }

      final data = jsonDecode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
        'data': data['data'],
      };
    } catch (e) {
      debugPrint('ApiService: Update error: $e');
      return {
        'success': false,
        'message': 'Update error: $e',
      };
    }
  }

  // Delete video (ADMIN ONLY - PROTECTED route)
  static Future<Map<String, dynamic>> deleteVideo(int id) async {
    try {
      debugPrint('ApiService: Deleting video ID: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/videos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Delete response status: ${response.statusCode}');
      
      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized - Admin access required',
        };
      }

      final data = jsonDecode(response.body);
      
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      debugPrint('ApiService: Delete error: $e');
      return {
        'success': false,
        'message': 'Delete error: $e',
      };
    }
  }

  // Get download URL (PROTECTED route dengan rate limiting khusus)
  static Future<Map<String, dynamic>> getDownloadUrl(int id) async {
    try {
      debugPrint('ApiService: Getting download URL for video ID: $id');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$id/download'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ApiService: Download URL response status: ${response.statusCode}');
      
      if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication required for downloads',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'message': 'Download rate limit exceeded - Please wait before downloading again',
        };
      }

      final data = jsonDecode(response.body);
      
      return {
        'success': data['success'] ?? false,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      debugPrint('ApiService: Error getting download URL: $e');
      return {
        'success': false,
        'message': 'Error getting download URL: $e',
      };
    }
  }

  // Check connection
  static Future<bool> checkConnection() async {
    try {
      debugPrint('ApiService: Checking connection to: $baseUrl/videos');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('ApiService: Connection check response: ${response.statusCode}');
      
      // 200 = OK, 401 = Unauthorized but server is reachable, 429 = Rate limited but reachable
      return response.statusCode == 200 || response.statusCode == 401 || response.statusCode == 429;
    } catch (e) {
      debugPrint('ApiService: Connection check failed: $e');
      return false;
    }
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    if (_authToken == null) return false;
    
    try {
      final userInfo = await getUserInfo();
      return userInfo != null;
    } catch (e) {
      debugPrint('ApiService: Authentication check failed: $e');
      return false;
    }
  }

  // Get authorized media URLs (for using with authenticated requests)
  static String getAuthorizedStreamUrl(int videoId) {
    return '$baseUrl/videos/$videoId/stream';
  }

  static String getAuthorizedThumbnailUrl(int videoId) {
    return '$baseUrl/videos/$videoId/thumbnail';
  }

  // Download file with progress and authentication
  static Future<void> downloadFileWithProgress(
    String url,
    String savePath,
    Function(int received, int total) onProgress,
  ) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_headers);
      
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final contentLength = streamedResponse.contentLength ?? 0;
        final file = File(savePath);
        final sink = file.openWrite();
        
        int received = 0;
        
        await for (var chunk in streamedResponse.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, contentLength);
        }
        
        await sink.close();
      } else if (streamedResponse.statusCode == 401) {
        throw Exception('Authentication required for download');
      } else if (streamedResponse.statusCode == 429) {
        throw Exception('Download rate limit exceeded');
      } else {
        throw Exception('Failed to download: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      rethrow;
    }
  }

  // Handle rate limiting with retry logic
  static Future<T?> _makeRequestWithRetry<T>(
    Future<T> Function() request,
    {int maxRetries = 3, Duration delayBetweenRetries = const Duration(seconds: 2)}
  ) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        
        if (e.toString().contains('429') || e.toString().contains('rate limit')) {
          if (attempts < maxRetries) {
            debugPrint('Rate limit hit, retrying in ${delayBetweenRetries.inSeconds} seconds... (attempt $attempts/$maxRetries)');
            await Future.delayed(delayBetweenRetries);
            continue;
          }
        }
        
        rethrow;
      }
    }
    
    return null;
  }

  // Debug method
  static Future<void> debugRawResponse() async {
    try {
      debugPrint('=== DEBUG RAW API RESPONSE ===');
      debugPrint('URL: $baseUrl/videos');
      debugPrint('Auth token: ${_authToken != null ? '${_authToken!.substring(0, 10)}...' : 'null'}');
      debugPrint('Headers: $_headers');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Raw Response Body:');
      debugPrint(response.body);
      debugPrint('Response Body Length: ${response.body.length}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('=== PARSED JSON ===');
          debugPrint('Success: ${data['success']}');
          debugPrint('Data type: ${data['data'].runtimeType}');
          debugPrint('Data length: ${data['data']?.length ?? 'null'}');
          
          if (data['data'] != null && data['data'] is List) {
            final videoList = data['data'] as List;
            for (int i = 0; i < (videoList.length > 2 ? 2 : videoList.length); i++) {
              debugPrint('--- Video $i ---');
              final video = videoList[i];
              debugPrint('Video data: $video');
              
              try {
                final parsedVideo = VideoModel.fromJson(video);
                debugPrint('✅ Successfully parsed video: ${parsedVideo.title}');
              } catch (e) {
                debugPrint('❌ Failed to parse video: $e');
              }
            }
          }
          
        } catch (e) {
          debugPrint('JSON parsing error: $e');
        }
      }
      
      debugPrint('=== END DEBUG ===');
      
    } catch (e) {
      debugPrint('Debug request error: $e');
    }
  }
}