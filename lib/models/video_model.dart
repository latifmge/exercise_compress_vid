import 'dart:io';
import 'package:video_compress/video_compress.dart';

class VideoModel {
  final File? videoFile;
  final MediaInfo? mediaInfo;
  final String size;
  final String path;

  VideoModel({
    this.videoFile,
    this.mediaInfo,
    this.size = '',
    this.path = '',
  });

  VideoModel copyWith({
    File? videoFile,
    MediaInfo? mediaInfo,
    String? size,
    String? path,
  }) {
    return VideoModel(
      videoFile: videoFile ?? this.videoFile,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      size: size ?? this.size,
      path: path ?? this.path,
    );
  }
}