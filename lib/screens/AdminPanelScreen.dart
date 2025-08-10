import 'package:flutter/material.dart';
import 'package:five_flix/models/video_model.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:five_flix/widgets/admin/video_manage_widget.dart';
import 'package:five_flix/widgets/admin/upload_video_widget.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<VideoModel> videos = [];
  bool isLoading = false;
  String? debugMessage;
  String? errorMessage;
  bool _showDebugInfo = false;
  
  // Statistics
  int totalVideos = 0;
  int featuredVideos = 0;
  int b2Videos = 0;
  int regularVideos = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Added debug tab
    _loadVideos();
    _checkApiConnection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkApiConnection() async {
    try {
      final hasConnection = await ApiService.checkConnection();
      final currentToken = ApiService.getCurrentToken();
      
      setState(() {
        debugMessage = 'Connection: ${hasConnection ? 'OK' : 'Failed'} | '
                     'Auth: ${currentToken != null ? 'Available' : 'Missing'}';
      });
    } catch (e) {
      setState(() {
        debugMessage = 'Connection check failed: $e';
      });
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      debugPrint('AdminPanel: Loading videos...');
      
      final loadedVideos = await ApiService.getVideos();
      debugPrint('AdminPanel: Loaded ${loadedVideos.length} videos');
      
      // Calculate statistics
      _calculateStatistics(loadedVideos);
      
      setState(() {
        videos = loadedVideos;
        isLoading = false;
        debugMessage = 'Loaded ${loadedVideos.length} videos successfully';
      });
    } catch (e) {
      debugPrint('AdminPanel: Error loading videos: $e');
      
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load videos: $e';
        debugMessage = 'Error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: $e'),
            backgroundColor: const Color(0xFFE50914),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadVideos,
            ),
          ),
        );
      }
    }
  }

  void _calculateStatistics(List<VideoModel> videoList) {
    totalVideos = videoList.length;
    featuredVideos = videoList.where((v) => v.isFeatured).length;
    b2Videos = videoList.where((v) => v.isB2Video).length;
    regularVideos = totalVideos - b2Videos;
  }

  Future<void> _performApiTest() async {
    setState(() {
      debugMessage = 'Testing API connection...';
    });
    
    try {
      debugPrint('=== ADMIN API TEST ===');
      
      // Test 1: Basic connection
      final hasConnection = await ApiService.checkConnection();
      debugPrint('✓ Connection: $hasConnection');
      
      // Test 2: Auth token
      final currentToken = ApiService.getCurrentToken();
      debugPrint('✓ Auth token: ${currentToken != null ? 'Available' : 'Missing'}');
      
      // Test 3: Raw API response
      await ApiService.debugRawResponse();
      
      // Test 4: Video count
      final testVideos = await ApiService.getVideos();
      debugPrint('✓ Videos loaded: ${testVideos.length}');
      
      setState(() {
        debugMessage = 'API Test Complete - Check console for details';
      });
      
      // Show results dialog
      if (mounted) {
        _showApiTestResults(hasConnection, testVideos.length, currentToken != null);
      }
      
    } catch (e) {
      debugPrint('API test error: $e');
      setState(() {
        debugMessage = 'API Test Failed: $e';
      });
      
      if (mounted) {
        _showErrorDialog('API Test Failed', e.toString());
      }
    }
  }

  void _showApiTestResults(bool connected, int videoCount, bool hasToken) {
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
              _buildTestResultRow('Backend Connection', connected ? 'Success' : 'Failed', connected),
              _buildTestResultRow('Authentication', hasToken ? 'Valid Token' : 'No Token', hasToken),
              _buildTestResultRow('Video API', '$videoCount videos loaded', videoCount > 0),
              _buildTestResultRow('Upload Ready', connected && hasToken ? 'Yes' : 'No', connected && hasToken),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'System Status:',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Total Videos: $totalVideos\n'
                      '• Featured Videos: $featuredVideos\n'
                      '• B2 Storage Videos: $b2Videos\n'
                      '• Regular Videos: $regularVideos',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ],
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

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Clear Server Cache', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will refresh the video list from the server. Continue?',
          style: TextStyle(color: Color(0xFFB3B3B3)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Admin Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF181818),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadVideos();
                  break;
                case 'test_api':
                  _performApiTest();
                  break;
                case 'clear_cache':
                  _clearCache();
                  break;
                case 'debug_toggle':
                  setState(() => _showDebugInfo = !_showDebugInfo);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.white70, size: 18),
                    SizedBox(width: 12),
                    Text('Refresh Videos', style: TextStyle(color: Colors.white)),
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
                    Icon(Icons.clear_all, color: Colors.orange, size: 18),
                    SizedBox(width: 12),
                    Text('Clear Cache', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'debug_toggle',
                child: Row(
                  children: [
                    Icon(
                      _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
                      color: _showDebugInfo ? Colors.green : Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showDebugInfo ? 'Hide Debug' : 'Show Debug',
                      style: TextStyle(
                        color: _showDebugInfo ? Colors.green : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showDebugInfo ? 110 : 70),
          child: Column(
            children: [
              // Statistics bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF181818),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip('Total', totalVideos.toString(), Colors.blue),
                    _buildStatChip('Featured', featuredVideos.toString(), const Color(0xFFE50914)),
                    _buildStatChip('B2 Storage', b2Videos.toString(), Colors.orange),
                    _buildStatChip('Regular', regularVideos.toString(), Colors.green),
                  ],
                ),
              ),
              
              // Debug info
              if (_showDebugInfo && debugMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue.shade800,
                  child: Row(
                    children: [
                      const Icon(Icons.developer_mode, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          debugMessage!,
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
                          'Test',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFE50914),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFFB3B3B3),
                tabs: const [
                  Tab(text: 'Manage Videos'),
                  Tab(text: 'Upload New'),
                  Tab(text: 'Debug'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Error banner
          if (errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => errorMessage = null),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                VideoManageWidget(
                  videos: videos,
                  isLoading: isLoading,
                  onRefresh: _loadVideos,
                ),
                UploadVideoWidget(
                  onUploadSuccess: () {
                    _loadVideos();
                    _tabController.animateTo(0);
                  },
                ),
                _buildDebugTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // API Status
          Card(
            color: const Color(0xFF181818),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDebugRow('Auth Token', ApiService.getCurrentToken() != null ? 'Available' : 'Missing'),
                  _buildDebugRow('Base URL', ApiService.baseUrl),
                  _buildDebugRow('Last Debug Message', debugMessage ?? 'None'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _performApiTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.api),
                      label: const Text('Run API Test'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Video Statistics
          Card(
            color: const Color(0xFF181818),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Video Statistics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDebugRow('Total Videos', totalVideos.toString()),
                  _buildDebugRow('Featured Videos', featuredVideos.toString()),
                  _buildDebugRow('B2 Storage Videos', b2Videos.toString()),
                  _buildDebugRow('Regular Videos', regularVideos.toString()),
                  _buildDebugRow('Loading State', isLoading ? 'Loading...' : 'Idle'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // System Actions
          Card(
            color: const Color(0xFF181818),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loadVideos,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _clearCache,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Cache'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}