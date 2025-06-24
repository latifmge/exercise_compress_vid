import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  final String videoSize;
  final String videoPath;

  const VideoPlayerWidget({
    Key? key,
    required this.videoFile,
    required this.videoSize,
    required this.videoPath,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: 64,
                        padding: const EdgeInsets.all(12),
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 64,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                            _isPlaying = !_isPlaying;
                          });
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          colors: const VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ukuran: ${widget.videoSize}',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Path: ${widget.videoPath}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}