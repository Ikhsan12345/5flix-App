import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/services/session_service.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:five_flix/database/user_db_helper.dart';
import 'package:five_flix/widgets/authorized_network_image.dart'; // Import the new widget
import 'package:five_flix/screens/VideoDetailScreen.dart';
import 'package:five_flix/screens/AdminPanelScreen.dart';
import 'package:five_flix/screens/DownloadsScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<VideoModel> videos = [];
  List<VideoModel> featuredVideos = [];
  List<VideoModel> downloadedVideos = [];
  bool isLoading = true;
  bool isOffline = false;
  String? userRole;
  String? username;
  String? debugMessage;
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> filteredVideos = [];
  late TabController _tabController;
  bool _showDebugInfo = false; // Toggle for debug information

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      userRole = args?['role'] ?? 'user';
      username = args?['username'] ?? '';

      debugPrint('HomeScreen - User Role: $userRole, Username: $username');
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      debugMessage = 'Initializing...';
    });

    try {
      debugPrint('=== Starting Data Load Process ===');
      
      // Check network connectivity with improved error handling
      final hasConnection = await ApiService.checkConnection();
      debugPrint('Network connectivity status: $hasConnection');

      setState(() {
        isOffline = !hasConnection;
        debugMessage = hasConnection
            ? 'Connected - Loading from server'
            : 'Offline - Loading cached content';
      });

      if (hasConnection) {
        await _loadOnlineData();
      } else {
        await _loadOfflineData();
      }
    } catch (e, stackTrace) {
      debugPrint('Critical error in _loadData: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() {
        isOffline = true;
        debugMessage = 'Connection failed - using offline mode';
      });
      
      // Always try offline data as fallback
      await _loadOfflineData();
    }

    // Load downloaded videos regardless of online status
    await _loadDownloadedVideos();

    setState(() {
      isLoading = false;
      debugMessage = isOffline 
          ? 'Offline: ${videos.length} cached videos'
          : 'Online: ${videos.length} videos loaded';
    });

    debugPrint('=== Data Load Process Complete ===');
  }

  Future<void> _loadOnlineData() async {
    try {
      debugPrint('Loading videos from API...');
      setState(() => debugMessage = 'Fetching videos from server...');

      // Add debugging for API connection
      final isConnected = await ApiService.checkConnection();
      debugPrint('API connection test: $isConnected');
      
      if (!isConnected) {
        debugPrint('API connection failed, switching to offline mode');
        setState(() {
          isOffline = true;
          debugMessage = 'Connection failed - switching to offline';
        });
        await _loadOfflineData();
        return;
      }

      // Perform comprehensive debugging
      if (_showDebugInfo) {
        await ApiService.debugRawResponse();
      }

      final loadedVideos = await ApiService.getVideos();
      debugPrint('API Response: Successfully loaded ${loadedVideos.length} videos from API');
      
      // Log each video for debugging
      for (int i = 0; i < loadedVideos.length && i < 3; i++) {
        debugPrint('Video $i: ${loadedVideos[i].toDebugString()}');
      }

      if (loadedVideos.isNotEmpty) {
        final featured = loadedVideos.where((v) => v.isFeatured).toList();
        debugPrint('Found ${featured.length} featured videos');

        // Cache videos for offline access
        try {
          await UserDbHelper.cacheVideoMetadata(loadedVideos);
          debugPrint('Videos successfully cached for offline access');
        } catch (cacheError) {
          debugPrint('Warning: Failed to cache videos - $cacheError');
          // Don't fail the entire operation for cache errors
        }

        setState(() {
          videos = loadedVideos;
          featuredVideos = featured;
          filteredVideos = loadedVideos;
          debugMessage = 'Server: ${loadedVideos.length} videos (${featured.length} featured)';
        });
      } else {
        debugPrint('No videos received from API, checking authentication...');
        
        // Check if it's an authentication issue
        final isAuth = await ApiService.isAuthenticated();
        debugPrint('Authentication status: $isAuth');
        
        if (!isAuth) {
          // Try to refresh session
          final sessionRefreshed = await SessionService.refreshSession();
          if (sessionRefreshed) {
            debugPrint('Session refreshed, retrying API call...');
            final retryVideos = await ApiService.getVideos();
            if (retryVideos.isNotEmpty) {
              final featured = retryVideos.where((v) => v.isFeatured).toList();
              setState(() {
                videos = retryVideos;
                featuredVideos = featured;
                filteredVideos = retryVideos;
                debugMessage = 'Server (after auth refresh): ${retryVideos.length} videos';
              });
              return;
            }
          }
        }
        
        setState(() => debugMessage = 'No server data - checking cache...');
        await _loadOfflineData();
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _loadOnlineData: $e');
      debugPrint('Stack trace: $stackTrace');
      
      setState(() => debugMessage = 'Server error: $e - loading cache...');
      
      // Always fallback to offline data on any error
      await _loadOfflineData();
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      debugPrint('Loading videos from local cache...');
      setState(() => debugMessage = 'Loading cached videos...');

      final cachedVideos = await UserDbHelper.getCachedVideos();
      debugPrint('Loaded ${cachedVideos.length} videos from cache');

      final featured = cachedVideos.where((v) => v.isFeatured).toList();

      setState(() {
        videos = cachedVideos;
        featuredVideos = featured;
        filteredVideos = cachedVideos;
        debugMessage = 'Cache: ${cachedVideos.length} videos (${featured.length} featured)';
      });

      if (cachedVideos.isEmpty) {
        setState(() => debugMessage = 'No cached content available');
      }
    } catch (e) {
      debugPrint('Error loading cached videos: $e');
      setState(() {
        videos = [];
        featuredVideos = [];
        filteredVideos = [];
        debugMessage = 'Cache error: No videos available';
      });
    }
  }

  Future<void> _loadDownloadedVideos() async {
    try {
      final downloaded = await DownloadService.getDownloadedVideos();
      debugPrint('Loaded ${downloaded.length} downloaded videos');
      setState(() => downloadedVideos = downloaded);
    } catch (e) {
      debugPrint('Error loading downloaded videos: $e');
      setState(() => downloadedVideos = []);
    }
  }

  void _filterVideos(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredVideos = videos;
      } else {
        filteredVideos = videos
            .where((video) => video.matchesSearch(query))
            .toList();
      }
    });
  }

  Future<void> _logout() async {
    try {
      debugPrint('Initiating logout process...');
      
      if (!isOffline) {
        await ApiService.logout();
        debugPrint('Server logout completed');
      } else {
        debugPrint('Offline logout - clearing local session only');
      }
      
      await SessionService.clearSession();
      debugPrint('Local session cleared');
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      // Force logout even if server call fails
      await SessionService.clearSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _refreshData() async {
    debugPrint('Manual refresh triggered');
    await _loadData();
  }

  Future<void> _performApiTest() async {
    setState(() => debugMessage = 'Testing API connection...');
    
    try {
      debugPrint('=== Starting comprehensive API test ===');
      
      // Test 1: Basic connectivity
      final hasConnection = await ApiService.checkConnection();
      debugPrint('✓ Basic connectivity: $hasConnection');

      if (hasConnection) {
        // Test 2: Get current token info
        final currentToken = ApiService.getCurrentToken();
        debugPrint('✓ Auth token status: ${currentToken != null ? 'Available' : 'Missing'}');

        // Test 3: Debug raw response
        await ApiService.debugRawResponse();
        
        // Test 4: Actual API call
        final videos = await ApiService.getVideos();
        debugPrint('✓ Videos fetched: ${videos.length}');

        // Test 5: Check authentication status
        final isAuth = await ApiService.isAuthenticated();
        debugPrint('✓ Authentication status: $isAuth');

        // Show comprehensive results
        if (mounted) {
          _showApiTestResults(hasConnection, videos.length, currentToken != null, isAuth);
        }
      } else {
        if (mounted) {
          _showApiTestResults(false, 0, false, false);
        }
      }
    } catch (e) {
      debugPrint('API test error: $e');
      if (mounted) {
        _showErrorDialog('API Test Failed', 'Error: $e\n\nCheck console for detailed logs.');
      }
    }
  }

  void _showApiTestResults(bool connected, int videoCount, bool hasToken, bool isAuth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Row(
          children: [
            Icon(
              connected ? Icons.check_circle : Icons.error,
              color: connected ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'API Test Results',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTestResultRow('Connection', connected ? 'Success' : 'Failed', connected),
              _buildTestResultRow('Auth Token', hasToken ? 'Available' : 'Missing', hasToken),
              _buildTestResultRow('Authenticated', isAuth ? 'Yes' : 'No', isAuth),
              _buildTestResultRow('Videos Loaded', '$videoCount', videoCount > 0),
              _buildTestResultRow('Debug Mode', _showDebugInfo ? 'Enabled' : 'Disabled', true),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '💡 Check console output for detailed technical information',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _showDebugInfo = !_showDebugInfo);
              Navigator.pop(context);
            },
            child: Text(
              _showDebugInfo ? 'Hide Debug' : 'Show Debug',
              style: const TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(String label, String value, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check : Icons.close,
            color: isSuccess ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.red)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (isOffline) _buildOfflineBanner(),
            if (_showDebugInfo && debugMessage != null) _buildDebugBanner(),
            _buildTabBar(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE50914),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOnlineTab(),
                        _buildDownloadsTab(),
                        _buildSearchTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade800,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.developer_mode, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEBUG: ${debugMessage ?? 'No debug info'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _performApiTest,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: const Size(0, 0),
            ),
            child: const Text(
              'Test API',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
  return Container(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Flexible(
          child: Image.asset(
            'lib/images/bannerlogo1.png',
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Text(
              '5FLIX',
              style: TextStyle(
                color: Color(0xFFE50914),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Spacer(flex: 2,), // Add Spacer to push the next widgets to the right
        if (userRole == 'admin' && !isOffline)
          IconButton(
            icon: const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFFE50914),
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPanelScreen(),
                ),
              );
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.account_circle,
            color: Colors.white70,
            size: 22,
          ),
          color: const Color(0xFF181818),
          onSelected: (value) {
            switch (value) {
              case 'downloads':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadsScreen(),
                  ),
                );
                break;
              case 'clear_cache':
                _showClearCacheDialog();
                break;
              case 'debug_toggle':
                setState(() => _showDebugInfo = !_showDebugInfo);
                break;
              case 'test_api':
                _performApiTest();
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem<String>(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      username ?? 'User',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'downloads',
              child: Row(
                children: [
                  Icon(Icons.download, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Text('Downloads', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'debug_toggle',
              child: Row(
                children: [
                  Icon(
                    _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
                    color: _showDebugInfo ? Colors.orange : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _showDebugInfo ? 'Hide Debug' : 'Show Debug',
                    style: TextStyle(
                      color: _showDebugInfo ? Colors.orange : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'test_api',
              child: Row(
                children: [
                  Icon(Icons.api, color: Colors.blue, size: 18),
                  SizedBox(width: 12),
                  Text('Test API', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'clear_cache',
              child: Row(
                children: [
                  Icon(Icons.clear_all, color: Colors.white70, size: 18),
                  SizedBox(width: 12),
                  Text('Clear Cache', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Offline Mode - Showing cached content',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          TextButton(
            onPressed: _refreshData,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF141414),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFE50914),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFFB3B3B3),
        isScrollable: false,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isOffline ? Icons.cached : Icons.home, size: 14),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    isOffline ? 'Cached' : 'Home',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download, size: 14),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    'Downloads (${downloadedVideos.length})',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: 14),
                SizedBox(width: 2),
                Flexible(
                  child: Text(
                    'Search',
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineTab() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFFE50914),
      child: CustomScrollView(
        slivers: [
          if (featuredVideos.isNotEmpty) _buildFeaturedSection(),
          _buildAllVideosSection(videos, 'All Movies'),
        ],
      ),
    );
  }

  Widget _buildDownloadsTab() {
    if (downloadedVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloaded Videos',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download videos to watch offline',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDownloadedVideos,
      color: const Color(0xFFE50914),
      child: CustomScrollView(
        slivers: [
          _buildAllVideosSection(downloadedVideos, 'Downloaded Videos'),
        ],
      ),
    );
  }

 Widget _buildSearchTab() {
  return SingleChildScrollView(
    child: Column(
      children: [
        // Search TextField
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search movies...',
              hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFB3B3B3)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFFB3B3B3)),
                      onPressed: () {
                        _searchController.clear();
                        _filterVideos('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF181818),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _filterVideos,
          ),
        ),
        // Display filtered videos in a grid
        _buildVideoGrid(filteredVideos),
      ],
    ),
  );
}



  SliverToBoxAdapter _buildFeaturedSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Featured',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: featuredVideos.length,
              itemBuilder: (context, index) {
                return _buildFeaturedVideoCard(featuredVideos[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildAllVideosSection(
    List<VideoModel> videoList,
    String title,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildVideoGrid(videoList),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(List<VideoModel> videoList) {
    if (videoList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No videos found',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (isOffline)
                Text(
                  'Check your connection or try refreshing',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  'No videos available at the moment',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (_showDebugInfo && debugMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Debug: $debugMessage',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate optimal grid parameters to avoid overflow
          final screenWidth = constraints.maxWidth;
          final padding = 16.0 * 2; // horizontal padding
          final spacing = 12.0; // crossAxisSpacing
          final availableWidth = screenWidth - padding;
          final itemWidth = (availableWidth - spacing) / 2; // 2 columns
          final childAspectRatio = itemWidth / (itemWidth / 0.7); // height calculation
          
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.68, // Slightly adjusted to prevent overflow
            ),
            itemCount: videoList.length,
            itemBuilder: (context, index) {
              return _buildVideoCard(videoList[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildFeaturedVideoCard(VideoModel video) {
    final isDownloaded = downloadedVideos.any((d) => d.id == video.id);

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _navigateToVideoDetail(video),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Use SmartVideoThumbnail instead of Image.network
                      SmartVideoThumbnail(
                        video: video,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: const Color(0xFF333333),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE50914),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: const Color(0xFF333333),
                          child: const Icon(
                            Icons.movie,
                            color: Colors.white54,
                            size: 50,
                          ),
                        ),
                      ),
                      if (isDownloaded)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.download_done,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${video.year} • ${video.genre}',
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(VideoModel video) {
    final isDownloaded = downloadedVideos.any((d) => d.id == video.id);

    return Card(
      color: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToVideoDetail(video),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    // Use SmartVideoThumbnail instead of Image.network
                    SmartVideoThumbnail(
                      video: video,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: const Color(0xFF333333),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE50914),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: Container(
                        color: const Color(0xFF333333),
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white54,
                          size: 50,
                        ),
                      ),
                    ),
                    if (video.isFeatured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEATURED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (isDownloaded)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.download_done,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    // Quality badge from VideoModel
                    if (video.isHighQuality)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            video.qualityBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Duration overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.displayDuration,
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
            ),
            // Fix overflow issue with Flexible widget
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.min, // Important for overflow fix
                  children: [
                    Flexible(
                      child: Text(
                        video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4), // Fixed spacing instead of spaceEvenly
                    Flexible(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${video.year} • ${video.genre}',
                              style: const TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (video.isRecentlyAdded)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2), // Fixed spacing
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              video.displayDuration,
                              style: const TextStyle(
                                color: Color(0xFFB3B3B3),
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (video.fileSize != null && video.fileSize! > 0)
                            Flexible(
                              child: Text(
                                video.displayFileSize,
                                style: const TextStyle(
                                  color: Color(0xFFB3B3B3),
                                  fontSize: 9,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
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

  void _navigateToVideoDetail(VideoModel video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoDetailScreen(video: video, userRole: userRole ?? 'user'),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will clear all cached videos and offline data. Downloaded videos will not be affected.',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFB3B3B3)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await UserDbHelper.clearOldCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cache cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                await _refreshData();
              } catch (e) {
                debugPrint('Error clearing cache: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing cache: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFE50914)),
            ),
          ),
        ],
      ),
    );
  }
}