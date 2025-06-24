import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_model.dart';

class VideoController {
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
    final XFile? pickedFile =
        await picker.pickVideo(source: ImageSource.gallery);

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
  Future<VideoModel?> compressVideo(
      VideoModel originalVideo, Function(String) onError,
      {Function(double)? onProgress,
      VideoQuality quality = VideoQuality.LowQuality,
      Function(String)? onCompressionTime}) async {
    if (originalVideo.videoFile == null) return null;

    // Subscribe to progress stream if callback is provided
    dynamic progressSubscription;
    if (onProgress != null) {
      progressSubscription =
          VideoCompress.compressProgress$.subscribe((progress) {
        onProgress(progress);
      });
    }

    // Waktu mulai kompresi
    DateTime startTime = DateTime.now();

    try {
      // Kompres semua video tanpa batasan ukuran atau durasi
      // Kompresi video dengan pengaturan yang dapat disesuaikan
      final info = await VideoCompress.compressVideo(
        originalVideo.videoFile!.path,
        quality: quality, // Menggunakan kualitas yang dipilih user
        deleteOrigin: false,
        includeAudio: true,
        frameRate: quality == VideoQuality.LowQuality
            ? 15
            : (quality == VideoQuality.MediumQuality
                ? 24
                : 30), // Frame rate disesuaikan dengan kualitas
      );

      if (info != null) {
        // Waktu selesai kompresi
        DateTime finishTime = DateTime.now();
        Duration compressionDuration = finishTime.difference(startTime);

        // Format waktu kompresi
        String formattedDuration = _formatDuration(compressionDuration);

        // Kirim informasi waktu kompresi jika callback tersedia
        if (onCompressionTime != null) {
          onCompressionTime(
              'Dimulai: ${_formatTime(startTime)}\nSelesai: ${_formatTime(finishTime)}\nDurasi: $formattedDuration');
        }

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
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // Fungsi untuk menghitung rasio kompresi
  String calculateCompressionRatio(
      VideoModel originalVideo, VideoModel compressedVideo) {
    if (originalVideo.videoFile == null || compressedVideo.videoFile == null) {
      return '0';
    }

    try {
      double originalSize = double.parse(originalVideo.size.split(' ')[0]);
      String originalUnit = originalVideo.size.split(' ')[1];

      double compressedSize = double.parse(compressedVideo.size.split(' ')[0]);
      String compressedUnit = compressedVideo.size.split(' ')[1];

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

  // Fungsi untuk mengkonversi ukuran ke bytes
  double _convertToBytes(double size, String unit) {
    switch (unit) {
      case 'KB':
        return size * 1024;
      case 'MB':
        return size * 1024 * 1024;
      case 'GB':
        return size * 1024 * 1024 * 1024;
      case 'TB':
        return size * 1024 * 1024 * 1024 * 1024;
      default:
        return size;
    }
  }

  // Fungsi untuk membatalkan kompresi
  void cancelCompression() {
    VideoCompress.cancelCompression();
  }

  // Fungsi untuk memformat waktu
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Fungsi untuk memformat durasi
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}
