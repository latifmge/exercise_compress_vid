import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_model.dart';

class VideoController {
  // Ukuran minimum untuk kompresi (8MB)
  static const int MIN_COMPRESSION_SIZE = 8 * 1024 * 1024;
  
  // Fungsi untuk meminta izin
  Future<bool> requestPermissions(BuildContext context) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();
    
    // Periksa apakah ada izin yang ditolak
    if (statuses[Permission.camera]!.isDenied || 
        statuses[Permission.storage]!.isDenied ||
        statuses[Permission.photos]!.isDenied) {
      return false;
    }
    
    return true;
  }
  
  // Fungsi untuk memilih video dari galeri
  Future<VideoModel?> pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      File videoFile = File(pickedFile.path);
      
      // Mendapatkan ukuran file asli
      int fileSize = await videoFile.length();
      String fileSizeStr = formatBytes(fileSize, 2);
      
      return VideoModel(
        videoFile: videoFile,
        size: fileSizeStr,
        path: videoFile.path,
      );
    }
    
    return null;
  }
  
  // Fungsi untuk mengkompresi video
  Future<VideoModel?> compressVideo(VideoModel originalVideo, Function(String) onError, {Function(double)? onProgress}) async {
    if (originalVideo.videoFile == null) return null;
    
    // Subscribe to progress stream if callback is provided
    var progressSubscription;
    if (onProgress != null) {
      progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
        onProgress(progress);
      });
    }
    
    try {
      // Mendapatkan ukuran file asli dalam bytes
      int originalSizeBytes = await originalVideo.videoFile!.length();
      
      // Hanya kompresi jika ukuran file lebih dari batas minimum
      if (originalSizeBytes > MIN_COMPRESSION_SIZE) {
        // Kompresi video dengan pengaturan yang lebih optimal
        final info = await VideoCompress.compressVideo(
          originalVideo.videoFile!.path,
          quality: VideoQuality.LowQuality,
          deleteOrigin: false,
          includeAudio: true,
          frameRate: 24,
        );
        
        if (info != null) {
          // Mendapatkan ukuran file hasil kompresi
          int compressedSize = await File(info.path!).length();
          String compressedSizeStr = formatBytes(compressedSize, 2);
          
          return VideoModel(
            videoFile: File(info.path!),
            mediaInfo: info,
            size: compressedSizeStr,
            path: info.path!,
          );
        }
        return null;
      } else {
        // Jika ukuran file kurang dari batas minimum, gunakan file asli sebagai hasil
        final info = await VideoCompress.getMediaInfo(originalVideo.videoFile!.path);
        
        return VideoModel(
          videoFile: originalVideo.videoFile,
          mediaInfo: info,
          size: originalVideo.size,
          path: originalVideo.path,
        );
      }
    } catch (e) {
      onError('Gagal mengkompresi video: $e');
      return null;
    } finally {
      // Unsubscribe from progress updates
      progressSubscription?.unsubscribe();
    }
  }
  
  // Fungsi untuk memformat ukuran file
  String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
  }
  
  // Fungsi untuk menghitung rasio kompresi
  String calculateCompressionRatio(VideoModel originalVideo, VideoModel compressedVideo) {
    if (originalVideo.videoFile == null || compressedVideo.videoFile == null) return '0';
    
    try {
      double originalSize = double.parse(originalVideo.size.split(' ')[0]);
      String originalUnit = originalVideo.size.split(' ')[1];
      
      double compressedSize = double.parse(compressedVideo.size.split(' ')[0]);
      String compressedUnit = compressedVideo.size.split(' ')[1];
      
      // Konversi ke bytes jika unit berbeda
      if (originalUnit != compressedUnit) {
        originalSize = convertToBytes(originalSize, originalUnit);
        compressedSize = convertToBytes(compressedSize, compressedUnit);
      }
      
      double ratio = ((originalSize - compressedSize) / originalSize) * 100;
      return ratio.toStringAsFixed(2);
    } catch (e) {
      return '0';
    }
  }
  
  // Fungsi untuk mengkonversi ukuran ke bytes
  double convertToBytes(double size, String unit) {
    switch (unit) {
      case 'KB': return size * 1024;
      case 'MB': return size * 1024 * 1024;
      case 'GB': return size * 1024 * 1024 * 1024;
      case 'TB': return size * 1024 * 1024 * 1024 * 1024;
      default: return size;
    }
  }
  
  // Fungsi untuk membatalkan kompresi
  void cancelCompression() {
    VideoCompress.cancelCompression();
  }
}