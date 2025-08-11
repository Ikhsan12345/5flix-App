import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:five_flix/services/api_service.dart';

class SessionService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _sessionExpiredKey = 'session_expired';

  // Save user session
  static Future<void> saveSession(
    String token,
    Map<String, dynamic> user,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user));
      await prefs.remove(_sessionExpiredKey); // Clear expired flag
      
      // Set token in API service
      ApiService.setAuthToken(token);
      
      debugPrint('SessionService: Session saved for user: ${user['username']}');
    } catch (e) {
      debugPrint('SessionService: Error saving session: $e');
    }
  }

  // Get current session
  static Future<Map<String, dynamic>?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userData = prefs.getString(_userKey);

      if (token != null && userData != null) {
        // Set token in API service
        ApiService.setAuthToken(token);
        
        final user = jsonDecode(userData);
        debugPrint('SessionService: Session loaded for user: ${user['username']}');
        
        return {'token': token, 'user': user};
      }
      
      debugPrint('SessionService: No valid session found');
      return null;
    } catch (e) {
      debugPrint('SessionService: Error loading session: $e');
      return null;
    }
  }

  // Check if session is valid by verifying with server
  static Future<bool> validateSession() async {
    try {
      final session = await getSession();
      if (session == null) return false;

      // Try to get user info from server to validate token
      final userInfo = await ApiService.getUserInfo();
      
      if (userInfo != null) {
        // Update local user data if server returns updated info
        await _updateUserData(userInfo);
        debugPrint('SessionService: Session validated successfully');
        return true;
      } else {
        // Token is invalid, clear session
        debugPrint('SessionService: Session validation failed - clearing session');
        await clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('SessionService: Error validating session: $e');
      return false;
    }
  }

  // Update user data in local storage
  static Future<void> _updateUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(userData));
      debugPrint('SessionService: User data updated');
    } catch (e) {
      debugPrint('SessionService: Error updating user data: $e');
    }
  }

  // Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final session = await getSession();
      return session?['user'];
    } catch (e) {
      debugPrint('SessionService: Error getting current user: $e');
      return null;
    }
  }

  // Check if current user is admin
  static Future<bool> isAdmin() async {
    try {
      final user = await getCurrentUser();
      return user?['role'] == 'admin';
    } catch (e) {
      debugPrint('SessionService: Error checking admin status: $e');
      return false;
    }
  }

  // Clear session and logout
  static Future<void> clearSession() async {
    try {
      // Logout from server first
      await ApiService.logout();
      
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_sessionExpiredKey);
      
      debugPrint('SessionService: Session cleared');
    } catch (e) {
      debugPrint('SessionService: Error clearing session: $e');
    }
  }

  // Mark session as expired (for handling 401 responses)
  static Future<void> markSessionExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionExpiredKey, true);
      debugPrint('SessionService: Session marked as expired');
    } catch (e) {
      debugPrint('SessionService: Error marking session expired: $e');
    }
  }

  // Check if session was marked as expired
  static Future<bool> wasSessionExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_sessionExpiredKey) ?? false;
    } catch (e) {
      debugPrint('SessionService: Error checking session expired status: $e');
      return false;
    }
  }

  // Auto-login with saved credentials (optional feature)
  static Future<bool> attemptAutoLogin() async {
    try {
      final session = await getSession();
      if (session == null) return false;

      // Validate existing session
      return await validateSession();
    } catch (e) {
      debugPrint('SessionService: Auto-login failed: $e');
      return false;
    }
  }

  // Refresh session (get fresh token if needed)
  static Future<bool> refreshSession() async {
    try {
      final userInfo = await ApiService.getUserInfo();
      
      if (userInfo != null) {
        await _updateUserData(userInfo);
        return true;
      } else {
        await clearSession();
        return false;
      }
    } catch (e) {
      debugPrint('SessionService: Error refreshing session: $e');
      return false;
    }
  }

  // Handle session timeout/expiry gracefully
  static Future<void> handleSessionTimeout() async {
    try {
      await markSessionExpired();
      await clearSession();
      debugPrint('SessionService: Session timeout handled');
    } catch (e) {
      debugPrint('SessionService: Error handling session timeout: $e');
    }
  }

  // Get session info for debugging
  static Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasToken = prefs.getString(_tokenKey) != null;
      final hasUserData = prefs.getString(_userKey) != null;
      final wasExpired = prefs.getBool(_sessionExpiredKey) ?? false;
      final currentUser = await getCurrentUser();
      
      return {
        'hasToken': hasToken,
        'hasUserData': hasUserData,
        'wasExpired': wasExpired,
        'currentUser': currentUser?['username'] ?? 'None',
        'userRole': currentUser?['role'] ?? 'None',
        'apiTokenSet': ApiService.getCurrentToken() != null,
      };
    } catch (e) {
      debugPrint('SessionService: Error getting debug info: $e');
      return {'error': e.toString()};
    }
  }
}