import 'package:flutter/material.dart';
import 'package:five_flix/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class UploadVideoWidget extends StatefulWidget {
  final VoidCallback onUploadSuccess;

  const UploadVideoWidget({super.key, required this.onUploadSuccess});

  @override
  State<UploadVideoWidget> createState() => _UploadVideoWidgetState();
}

class _UploadVideoWidgetState extends State<UploadVideoWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _yearController = TextEditingController();

  bool _isFeatured = false;
  bool _isUploading = false;
  File? _thumbnailFile;
  File? _videoFile;

  @override
  void dispose() {
    _titleController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(_titleController, 'Title', required: true),
            const SizedBox(height: 16),
            _buildTextField(_genreController, 'Genre', required: true),
            const SizedBox(height: 16),
            _buildTextField(_descriptionController, 'Description', maxLines: 3),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _durationController,
                    'Duration (min)',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    _yearController,
                    'Year',
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Featured', style: TextStyle(color: Colors.white)),
              value: _isFeatured,
              onChanged: (value) => setState(() => _isFeatured = value),
              activeColor: const Color(0xFFE50914),
            ),
            const SizedBox(height: 24),
            _buildFileButton(
              'Select Thumbnail',
              _thumbnailFile?.path.split('/').last,
              Icons.image,
              _pickThumbnail,
            ),
            const SizedBox(height: 12),
            _buildFileButton(
              'Select Video',
              _videoFile?.path.split('/').last,
              Icons.video_file,
              _pickVideo,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Upload Video',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFB3B3B3)),
        filled: true,
        fillColor: const Color(0xFF181818),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE50914)),
        ),
      ),
      validator: required
          ? (value) => value?.isEmpty == true ? '$label is required' : null
          : null,
    );
  }

  Widget _buildFileButton(
    String label,
    String? fileName,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (fileName != null)
            Text(
              fileName,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB3B3B3)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: fileName != null ? const Color(0xFFE50914) : const Color(0xFFB3B3B3),
        ),
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _thumbnailFile = File(image.path));
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() => _videoFile = File(result.files.single.path!));
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_thumbnailFile == null || _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both thumbnail and video file'),
          backgroundColor: Color(0xFFE50914),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final result = await ApiService.uploadVideo(
        title: _titleController.text.trim(),
        genre: _genreController.text.trim(),
        description: _descriptionController.text.trim(),
        duration: int.parse(_durationController.text.trim()),
        year: int.parse(_yearController.text.trim()),
        isFeatured: _isFeatured,
        thumbnailFile: _thumbnailFile!,
        videoFile: _videoFile!,
      );

      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
        widget.onUploadSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _genreController.clear();
    _descriptionController.clear();
    _durationController.clear();
    _yearController.clear();
    setState(() {
      _isFeatured = false;
      _thumbnailFile = null;
      _videoFile = null;
    });
  }
}