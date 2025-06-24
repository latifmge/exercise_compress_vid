import 'package:flutter/material.dart';
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
        _originalVideo = video;
        _compressedVideo = null;
      });
    }
  }

  Future<void> _compressVideo() async {
    if (_originalVideo == null) return;
    
    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
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
    );
    
    setState(() {
      _compressedVideo = compressedVideo;
      _isCompressing = false;
      _compressionProgress = 0.0;
    });
    
    // Tampilkan pesan jika video tidak dikompresi karena ukurannya kecil
    if (_compressedVideo != null && 
        _originalVideo!.path == _compressedVideo!.path) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video kurang dari 8MB, tidak perlu dikompresi')),
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
                videoFile: _originalVideo!.videoFile!,
                videoSize: _originalVideo!.size,
                videoPath: _originalVideo!.path,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
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
              const SizedBox(height: 32),
            ],
            if (_compressedVideo != null && _compressedVideo!.videoFile != null) ...[              
              const Text(
                'Video Hasil Kompresi:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              VideoPlayerWidget(
                videoFile: _compressedVideo!.videoFile!,
                videoSize: _compressedVideo!.size,
                videoPath: _compressedVideo!.path,
              ),
              const SizedBox(height: 8),
              if (_originalVideo != null) Text(
                'Rasio Kompresi: ${_controller.calculateCompressionRatio(_originalVideo!, _compressedVideo!)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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