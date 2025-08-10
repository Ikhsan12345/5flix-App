import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/services/session_service.dart';
import 'package:five_flix/services/download_service.dart';
import 'package:five_flix/database/user_db_helper.dart';
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
  String? debugMessage; // Debug message untuk troubleshooting
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> filteredVideos = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      userRole = args?['role'] ?? 'user';
      username = args?['username'] ?? '';

      // Debug: Print user info
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
      debugMessage = 'Loading data...';
    });

    try {
      debugPrint('Checking network connection...');

      // Check network connectivity
      final hasConnection = await ApiService.checkConnection();
      debugPrint('Network connection: $hasConnection');

      setState(() {
        isOffline = !hasConnection;
        debugMessage = hasConnection
            ? 'Connected - Loading from API'
            : 'Offline - Loading cached data';
      });

      if (hasConnection) {
        // Online mode - load from API
        await _loadOnlineData();
      } else {
        // Offline mode - load from cache
        await _loadOfflineData();
      }
    } catch (e) {
      debugPrint('Error in _loadData: $e');
      setState(() {
        isOffline = true;
        debugMessage = 'Error occurred: $e';
      });
      await _loadOfflineData();
    }

    // Always load downloaded videos
    await _loadDownloadedVideos();

    setState(() => isLoading = false);
  }

  Future<void> _loadOnlineData() async {
    try {
      debugPrint('Loading videos from API...');

      final loadedVideos = await ApiService.getVideos();
      debugPrint('API returned ${loadedVideos.length} videos');

      // Debug: Print first video if exists
      if (loadedVideos.isNotEmpty) {
        debugPrint('First video: ${loadedVideos[0].title}');
      }

      final featured = loadedVideos.where((v) => v.isFeatured).toList();
      debugPrint('Featured videos: ${featured.length}');

      // Cache videos untuk offline
      try {
        await UserDbHelper.cacheVideoMetadata(loadedVideos);
        debugPrint('Videos cached successfully');
      } catch (cacheError) {
        debugPrint('Cache error: $cacheError');
      }

      setState(() {
        videos = loadedVideos;
        featuredVideos = featured;
        filteredVideos = loadedVideos;
        debugMessage = 'Loaded ${loadedVideos.length} videos from API';
      });
    } catch (e) {
      debugPrint('Error in _loadOnlineData: $e');
      setState(() {
        debugMessage = 'API Error: $e';
      });
      // Fallback to offline data
      await _loadOfflineData();
    }
  }

  Future<void> _loadOfflineData() async {
    try {
      debugPrint('Loading videos from cache...');

      final cachedVideos = await UserDbHelper.getCachedVideos();
      debugPrint('Cache returned ${cachedVideos.length} videos');

      final featured = cachedVideos.where((v) => v.isFeatured).toList();

      setState(() {
        videos = cachedVideos;
        featuredVideos = featured;
        filteredVideos = cachedVideos;
        debugMessage = 'Loaded ${cachedVideos.length} videos from cache';
      });
    } catch (e) {
      debugPrint('Error in _loadOfflineData: $e');
      setState(() {
        videos = [];
        featuredVideos = [];
        filteredVideos = [];
        debugMessage = 'Cache Error: $e';
      });
    }
  }

  Future<void> _loadDownloadedVideos() async {
    try {
      final downloaded = await DownloadService.getDownloadedVideos();
      debugPrint('Downloaded videos: ${downloaded.length}');
      setState(() {
        downloadedVideos = downloaded;
      });
    } catch (e) {
      debugPrint('Error loading downloaded videos: $e');
      setState(() {
        downloadedVideos = [];
      });
    }
  }

  void _filterVideos(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredVideos = videos;
      } else {
        filteredVideos = videos
            .where(
              (video) =>
                  video.title.toLowerCase().contains(query.toLowerCase()) ||
                  video.genre.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _logout() async {
    try {
      if (!isOffline) {
        await ApiService.logout();
      }
      await SessionService.clearSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  // Debug method untuk test API connection
  Future<void> _testApiConnection() async {
    try {
      debugPrint('Testing API connection...');

      // Test basic connection
      final hasConnection = await ApiService.checkConnection();
      debugPrint('Basic connection test: $hasConnection');

      if (hasConnection) {
        // Debug raw response first
        await ApiService.debugRawResponse();

        // Test getVideos
        final videos = await ApiService.getVideos();
        debugPrint('getVideos returned: ${videos.length} videos');

        // Show result in dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF181818),
              title: const Text(
                'API Test Result',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Connection: $hasConnection\nVideos loaded: ${videos.length}',
                      style: const TextStyle(color: Color(0xFFB3B3B3)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Check console for detailed debug info',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                    if (videos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Sample video:',
                        style: TextStyle(color: Colors.white),
                      ),
                      Text(
                        '${videos[0].title} (${videos[0].year})',
                        style: const TextStyle(
                          color: Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
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
      }
    } catch (e) {
      debugPrint('API test error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF181818),
            title: const Text(
              'API Test Error',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Error: $e\nCheck console for details',
              style: const TextStyle(color: Colors.red),
            ),
            actions: [
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
    }
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
            if (debugMessage != null) _buildDebugBanner(), // Debug banner
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

  // Debug banner untuk troubleshooting
  Widget _buildDebugBanner() {
    return Container(
      width: double.infinity,
      color: Colors.blue.shade800,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.bug_report, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              debugMessage ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _testApiConnection,
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
                case 'test_api':
                  _testApiConnection();
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
    return Column(
      children: [
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
        Expanded(child: _buildVideoGrid(filteredVideos)),
      ],
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
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'No videos found',
            style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: videoList.length,
        itemBuilder: (context, index) {
          return _buildVideoCard(videoList[index]);
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
                      Image.network(
                        video.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFF333333),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE50914),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
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
                    Image.network(
                      video.thumbnailUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFF333333),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE50914),
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
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
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
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
                    Text(
                      '${video.duration} min',
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 10,
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
              await UserDbHelper.clearOldCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _refreshData();
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
