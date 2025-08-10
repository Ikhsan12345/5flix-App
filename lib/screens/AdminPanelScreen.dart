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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVideos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => isLoading = true);
    try {
      final loadedVideos = await ApiService.getVideos();
      setState(() {
        videos = loadedVideos;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE50914),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFB3B3B3),
          tabs: const [
            Tab(text: 'Manage Videos'),
            Tab(text: 'Upload New'),
          ],
        ),
      ),
      body: TabBarView(
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
        ],
      ),
    );
  }
}