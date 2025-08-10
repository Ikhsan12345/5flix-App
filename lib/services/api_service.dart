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
  
  // Get current auth token (for debugging)
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

  // Get all videos
  static Future<List<VideoModel>> getVideos() async {
    try {
      debugPrint('ApiService: Fetching videos...');
      debugPrint('ApiService: Using URL: $baseUrl/videos');
      debugPrint('ApiService: Auth token available: ${_authToken != null}');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('ApiService: Videos response status: ${response.statusCode}');
      debugPrint('ApiService: Videos response length: ${response.body.length}');

      if (response.statusCode == 401) {
        debugPrint('ApiService: Unauthorized - token might be invalid');
        clearAuthToken();
        return [];
      }

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
              // Continue with next video instead of failing entirely
            }
          }
          
          debugPrint('ApiService: Successfully parsed ${videos.length} out of ${videoList.length} videos');
          return videos;
        } else {
          debugPrint('ApiService: API response indicates failure: ${data['message'] ?? 'Unknown error'}');
        }
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

  // Get single video
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

  // Get video stream URL (for secure streaming)
  static Future<String?> getVideoStreamUrl(int videoId) async {
    try {
      debugPrint('ApiService: Getting stream URL for video ID: $videoId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$videoId/stream'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      debugPrint('ApiService: Stream URL response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // This should return the video file directly or redirect to the file
        return '$baseUrl/videos/$videoId/stream';
      }
      
      return null;
    } catch (e) {
      debugPrint('ApiService: Error getting stream URL: $e');
      return null;
    }
  }

  // Get video thumbnail URL (for secure thumbnails)
  static Future<String?> getVideoThumbnailUrl(int videoId) async {
    try {
      debugPrint('ApiService: Getting thumbnail URL for video ID: $videoId');
      
      final response = await http.head(
        Uri.parse('$baseUrl/videos/$videoId/thumbnail'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('ApiService: Thumbnail URL response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return '$baseUrl/videos/$videoId/thumbnail';
      }
      
      return null;
    } catch (e) {
      debugPrint('ApiService: Error getting thumbnail URL: $e');
      return null;
    }
  }

  // Upload video (Admin only)
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
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.headers['Accept'] = 'application/json';

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
      final data = jsonDecode(response.body);

      debugPrint('ApiService: Upload response status: ${response.statusCode}');

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

  // Update video (Admin only)
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
        'POST', // Backend uses POST with special handling for PUT
        Uri.parse('$baseUrl/videos/$id'),
      );

      // Add method override for PUT
      request.fields['_method'] = 'PUT';

      // Add headers
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.headers['Accept'] = 'application/json';

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
      final data = jsonDecode(response.body);

      debugPrint('ApiService: Update response status: ${response.statusCode}');

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

  // Delete video (Admin only)
  static Future<Map<String, dynamic>> deleteVideo(int id) async {
    try {
      debugPrint('ApiService: Deleting video ID: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/videos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      debugPrint('ApiService: Delete response status: ${response.statusCode}');
      
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

  // Get download URL
  static Future<Map<String, dynamic>> getDownloadUrl(int id) async {
    try {
      debugPrint('ApiService: Getting download URL for video ID: $id');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$id/download'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      debugPrint('ApiService: Download URL response status: ${response.statusCode}');
      
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

  // Check connection with better error handling
  static Future<bool> checkConnection() async {
    try {
      debugPrint('ApiService: Checking connection to: $baseUrl/videos');
      
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('ApiService: Connection check response: ${response.statusCode}');
      
      // Consider both 200 and 401 as "connected" - 401 just means we need to login
      return response.statusCode == 200 || response.statusCode == 401;
    } catch (e) {
      debugPrint('ApiService: Connection check failed: $e');
      return false;
    }
  }

  // Debug method untuk melihat raw response
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
              
              // Try to parse this video
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

  // Test URL access
  static Future<bool> testUrlAccess(String url, {Map<String, String>? headers}) async {
    try {
      debugPrint('ApiService: Testing URL access: ${url.substring(0, 50)}...');
      
      final response = await http.head(
        Uri.parse(url),
        headers: headers ?? _headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('ApiService: URL test response: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      debugPrint('ApiService: URL test error: $e');
      return false;
    }
  }

  // Get authorized media URL (for streaming/thumbnail with auth)
  static String getAuthorizedStreamUrl(int videoId) {
    return '$baseUrl/videos/$videoId/stream';
  }

  static String getAuthorizedThumbnailUrl(int videoId) {
    return '$baseUrl/videos/$videoId/thumbnail';
  }

  // Download file with progress (for downloads)
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
      } else {
        throw Exception('Failed to download: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      rethrow;
    }
  }
}