import 'dart:io';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Compressor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Video Compressor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _videoFile;
  MediaInfo? _compressedInfo;
  bool _isCompressing = false;
  bool _permissionsRequested = false;
  
  // Informasi video sebelum dan sesudah kompresi
  String _originalSize = '';
  String _compressedSize = '';
  String _originalPath = '';
  String _compressedPath = '';
  
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }
  
  Future<void> _requestPermissions() async {
    if (!_permissionsRequested) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.storage,
        Permission.photos,
      ].request();
      
      setState(() {
        _permissionsRequested = true;
      });
      
      // Tampilkan dialog jika izin ditolak
      if (statuses[Permission.camera]!.isDenied || 
          statuses[Permission.storage]!.isDenied ||
          statuses[Permission.photos]!.isDenied) {
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
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      File videoFile = File(pickedFile.path);
      
      // Mendapatkan ukuran file asli
      int fileSize = await videoFile.length();
      String fileSizeStr = _formatBytes(fileSize, 2);
      
      setState(() {
        _videoFile = videoFile;
        _originalSize = fileSizeStr;
        _originalPath = videoFile.path;
        _compressedInfo = null;
        _compressedSize = '';
        _compressedPath = '';
      });
    }
  }

  Future<void> _compressVideo() async {
    if (_videoFile == null) return;
    
    setState(() {
      _isCompressing = true;
    });
    
    try {
      // Mendapatkan direktori sementara untuk menyimpan video hasil kompresi
      // Catatan: VideoCompress akan otomatis menentukan lokasi penyimpanan
      // Variabel ini dihapus karena tidak digunakan dan menyebabkan warning
      // final tempDir = await getTemporaryDirectory();
      // final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Kompresi video
      final info = await VideoCompress.compressVideo(
        _videoFile!.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );
      
      if (info != null) {
        // Mendapatkan ukuran file hasil kompresi
        int compressedSize = await File(info.path!).length();
        String compressedSizeStr = _formatBytes(compressedSize, 2);
        
        setState(() {
          _compressedInfo = info;
          _compressedSize = compressedSizeStr;
          _compressedPath = info.path!;
        });
      }
    } catch (e) {
      print('Error compressing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengkompresi video: $e')),
      );
    } finally {
      setState(() {
        _isCompressing = false;
      });
    }
  }
  
  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
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
            ),
            const SizedBox(height: 20),
            if (_videoFile != null) ...[              
              const Text(
                'Video Asli:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildVideoPreview(_videoFile!),
              const SizedBox(height: 8),
              Text('Ukuran: $_originalSize'),
              Text('Path: $_originalPath'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isCompressing ? null : _compressVideo,
                icon: const Icon(Icons.compress),
                label: _isCompressing 
                  ? const Row(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(width: 8), Text('Mengkompresi...')]) 
                  : const Text('Kompres Video'),
              ),
              const SizedBox(height: 20),
            ],
            if (_compressedInfo != null) ...[              
              const Text(
                'Video Hasil Kompresi:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildVideoPreview(File(_compressedInfo!.path!)),
              const SizedBox(height: 8),
              Text('Ukuran: $_compressedSize'),
              Text('Path: $_compressedPath'),
              const SizedBox(height: 8),
              Text(
                'Rasio Kompresi: ${_calculateCompressionRatio()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _calculateCompressionRatio() {
    if (_videoFile == null || _compressedInfo == null) return '0';
    
    try {
      double originalSize = double.parse(_originalSize.split(' ')[0]);
      String originalUnit = _originalSize.split(' ')[1];
      
      double compressedSize = double.parse(_compressedSize.split(' ')[0]);
      String compressedUnit = _compressedSize.split(' ')[1];
      
      // Konversi ke bytes jika unit berbeda
      if (originalUnit != compressedUnit) {
        originalSize = _convertToBytes(originalSize, originalUnit);
        compressedSize = _convertToBytes(compressedSize, compressedUnit);
      }
      
      double ratio = ((originalSize - compressedSize) / originalSize) * 100;
      return ratio.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }
  
  double _convertToBytes(double size, String unit) {
    switch (unit) {
      case 'KB': return size * 1024;
      case 'MB': return size * 1024 * 1024;
      case 'GB': return size * 1024 * 1024 * 1024;
      case 'TB': return size * 1024 * 1024 * 1024 * 1024;
      default: return size;
    }
  }
  
  Widget _buildVideoPreview(File file) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.video_file,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Text(
              file.path.split('/').last,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    VideoCompress.cancelCompression();
    super.dispose();
  }
}
