import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import '../controllers/video_controller.dart';
import '../models/video_model.dart';
import '../widgets/video_player_widget.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final VideoController _controller = VideoController();
  VideoModel? _originalVideo;
  VideoModel? _compressedVideo;
  bool _isCompressing = false;
  bool _permissionsRequested = false;
  double _compressionProgress = 0.0;
  VideoQuality _selectedQuality = VideoQuality.LowQuality;
  String _compressionTimeInfo = '';
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }
  
  Future<void> _requestPermissions() async {
    if (!_permissionsRequested) {
      bool permissionsGranted = await _controller.requestPermissions(context);
      
      setState(() {
        _permissionsRequested = true;
      });
      
      if (!permissionsGranted) {
        _showPermissionDeniedDialog();
      }
    }
  }
  
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: const Text(
          'Aplikasi memerlukan izin kamera dan penyimpanan untuk berfungsi dengan baik. '
          'Silakan berikan izin melalui pengaturan aplikasi.'
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVideo() async {
    final video = await _controller.pickVideo();
    
    if (video != null) {
      setState(() {
        // Reset semua state ketika memilih video baru
        _originalVideo = video;
        _compressedVideo = null;
        _compressionProgress = 0.0;
        _compressionTimeInfo = '';
        _isCompressing = false;
        // Reset kualitas ke default
        _selectedQuality = VideoQuality.LowQuality;
      });
    }
  }

  Future<void> _compressVideo() async {
    if (_originalVideo == null) return;
    
    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
      _compressionTimeInfo = '';
    });
    
    final compressedVideo = await _controller.compressVideo(
      _originalVideo!,
      (errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      },
      onProgress: (progress) {
        setState(() {
          _compressionProgress = progress;
        });
      },
      quality: _selectedQuality,
      onCompressionTime: (timeInfo) {
        setState(() {
          _compressionTimeInfo = timeInfo;
        });
      },
    );
    
    setState(() {
      _compressedVideo = compressedVideo;
      _isCompressing = false;
      _compressionProgress = 0.0;
    });
    
    // Tampilkan pesan sukses jika video berhasil dikompres
    if (_compressedVideo != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video berhasil dikompres!')),
      );
    }
  }

  void _cancelCompression() {
    _controller.cancelCompression();
    setState(() {
      _isCompressing = false;
      _compressionProgress = 0.0;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kompresi dibatalkan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('Pilih Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 24),
            if (_originalVideo != null && _originalVideo!.videoFile != null) ...[              
              const Text(
                'Video Asli:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              VideoPlayerWidget(
                key: ValueKey(_originalVideo!.path), // Unique key based on video path
                videoFile: _originalVideo!.videoFile!,
                videoSize: _originalVideo!.size,
                videoPath: _originalVideo!.path,
              ),
              const SizedBox(height: 16),
              // Pilihan kualitas kompresi
              const Text(
                'Kualitas Kompresi:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButton<VideoQuality>(
                value: _selectedQuality,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: VideoQuality.LowQuality,
                    child: Text('Cepat (Kualitas Rendah) - Rekomendasi untuk video panjang'),
                  ),
                  DropdownMenuItem(
                    value: VideoQuality.MediumQuality,
                    child: Text('Sedang (Kualitas Medium)'),
                  ),
                  DropdownMenuItem(
                    value: VideoQuality.HighestQuality,
                    child: Text('Lambat (Kualitas Tinggi)'),
                  ),
                ],
                onChanged: _isCompressing ? null : (VideoQuality? value) {
                  setState(() {
                    _selectedQuality = value ?? VideoQuality.LowQuality;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCompressing ? null : _compressVideo,
                      icon: const Icon(Icons.compress),
                      label: _isCompressing 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: _compressionProgress / 100,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Mengkompresi... ${_compressionProgress.toStringAsFixed(0)}%'),
                            ],
                          )
                        : const Text('Kompres Video'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ),
                  if (_isCompressing) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _cancelCompression,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Batal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
            ],
            if (_compressedVideo != null && _compressedVideo!.videoFile != null) ...[              
              const Text(
                'Video Hasil Kompresi:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              VideoPlayerWidget(
                key: ValueKey(_compressedVideo!.path), // Unique key based on video path
                videoFile: _compressedVideo!.videoFile!,
                videoSize: _compressedVideo!.size,
                videoPath: _compressedVideo!.path,
              ),
              const SizedBox(height: 8),
              if (_originalVideo != null) ...[
                Text(
                  'Rasio Kompresi: ${_controller.calculateCompressionRatio(_originalVideo!, _compressedVideo!)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_compressionTimeInfo.isNotEmpty) ...[
                  const Text(
                    'Informasi Waktu Kompresi:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _compressionTimeInfo,
                      style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.cancelCompression();
    super.dispose();
  }
}