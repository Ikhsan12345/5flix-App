import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';

class ApiService {
  static const String baseUrl = 'https://5flix-backend-production.up.railway.app/api'; // Ganti dengan URL server Anda
  static String? _authToken;
  
  // Set auth token
  static void setAuthToken(String token) {
    _authToken = "0Qw2UTwRI2Ib5zykFGrbw8edmjZVyaAJf3X3W1kKdb83cb7b";
  }
  
  // Get auth headers
  static Map<String, String> get _headers {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

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
      return {
        'success': false,
        'message': 'Koneksi bermasalah: $e',
      };
    }
  }

  // Register
  static Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'user': data['user'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi bermasalah: $e',
      };
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: _headers,
      );
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _authToken = null;
    }
  }

  // Get all videos
  static Future<List<VideoModel>> getVideos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          List<VideoModel> videos = [];
          for (var videoJson in data['data']) {
            videos.add(VideoModel.fromJson(videoJson));
          }
          return videos;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching videos: $e');
      return [];
    }
  }

  // Get single video
  static Future<VideoModel?> getVideo(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return VideoModel.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching video: $e');
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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/videos'),
      );

      // Add headers
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
        'data': data['data'],
      };
    } catch (e) {
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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/videos/$id/update'),
      );

      // Add headers
      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

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

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
        'data': data['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Update error: $e',
      };
    }
  }

  // Delete video (Admin only)
  static Future<Map<String, dynamic>> deleteVideo(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/videos/$id'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Unknown error',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Delete error: $e',
      };
    }
  }

  // Get download URL
  static Future<Map<String, dynamic>> getDownloadUrl(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos/$id/download'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'data': data['data'],
        'message': data['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting download URL: $e',
      };
    }
  }

  // Check connection
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/videos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}