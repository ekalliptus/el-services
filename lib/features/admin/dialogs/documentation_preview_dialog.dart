import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

/// Menampilkan preview dokumentasi (gambar atau video)
void showDocumentationPreview(BuildContext context, String url, bool isVideo) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Stack(
        children: [
          // Widget untuk menampilkan preview sesuai jenisnya
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.8,
            child: isVideo
                ? VideoPreviewWidget(url: url)
                : ImagePreviewWidget(url: url),
          ),
          // Tombol close di pojok kanan atas
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Menampilkan preview gambar
class ImagePreviewWidget extends StatelessWidget {
  final String url;

  const ImagePreviewWidget({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Cek apakah URL adalah data base64
    if (url.startsWith('data:image')) {
      // Extract base64 data dari URL
      final base64Data = url.split(',')[1];
      // Decode base64 ke bytes
      final imageBytes = base64Decode(base64Data);

      // Gunakan PhotoView dengan ImageProvider.memory
      return PhotoView(
        imageProvider: MemoryImage(imageBytes),
        backgroundDecoration: BoxDecoration(color: Colors.transparent),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      );
    } else {
      // URL normal, gunakan PhotoView dengan NetworkImage
      return PhotoView(
        imageProvider: NetworkImage(url),
        backgroundDecoration: BoxDecoration(color: Colors.transparent),
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      );
    }
  }
}

/// Menampilkan preview video
class VideoPreviewWidget extends StatefulWidget {
  final String url;

  const VideoPreviewWidget({Key? key, required this.url}) : super(key: key);

  @override
  _VideoPreviewWidgetState createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  String? _errorMessage;
  File? _tempFile;
  bool _isPlaying = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _generateThumbnail() async {
    try {
      if (_videoPlayerController.value.isInitialized) {
        print('Menghasilkan thumbnail dari player video');

        // Ambil frame pertama untuk ditampilkan sebagai thumbnail
        await _videoPlayerController.setVolume(0);
        await _videoPlayerController.seekTo(Duration.zero);
        await _videoPlayerController.pause();

        // Untuk menandai bahwa video sudah memiliki thumbnail
        setState(() {
          // Thumbnail sudah ada di controller, kita hanya perlu menandai untuk menampilkan
          // frame pertama dari video
// dummy data untuk menandai thumbnail ada
        });

        print('Thumbnail berhasil diatur dari frame pertama video');
      } else {
        print(
            'Video player belum diinisialisasi, tidak dapat menghasilkan thumbnail');
      }
    } catch (e) {
      print('Error menghasilkan thumbnail: $e');
    }
  }

  void _addVideoListener() {
    _videoPlayerController.addListener(() {
      if (_videoPlayerController.value.isBuffering) {
        setState(() {
          _isBuffering = true;
        });
      } else {
        setState(() {
          _isBuffering = false;
        });
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isInitialized = false;
        _errorMessage = 'Memuat video... mohon tunggu sebentar';
      });

      if (widget.url.startsWith('data:video')) {
        try {
          final parts = widget.url.split(',');
          if (parts.length != 2) {
            throw Exception('Format base64 video tidak valid');
          }

          final base64Data = parts[1];
          if (base64Data.isEmpty || base64Data.length < 100) {
            throw Exception('Data video tidak valid atau terlalu kecil');
          }

          final bytes = base64Decode(base64Data);
          if (bytes.length < 1000) {
            throw Exception('Data video terlalu kecil atau rusak');
          }

          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${tempDir.path}/temp_video_$timestamp.mp4';
          _tempFile = File(filePath);

          await _tempFile!.writeAsBytes(bytes, flush: true);
          print(
              'File video dibuat: ${_tempFile!.path}, ukuran: ${await _tempFile!.length()} bytes');

          if (!await _tempFile!.exists() || await _tempFile!.length() < 1000) {
            throw Exception('File video gagal dibuat atau tidak valid');
          }

          _videoPlayerController = VideoPlayerController.file(_tempFile!);

          // Konfigurasi controller video
          await _videoPlayerController.initialize().timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Video initialization timed out');
            },
          );

          // Generate thumbnail setelah video diinisialisasi
          await _generateThumbnail();

          await _videoPlayerController.setVolume(1.0);
          await _videoPlayerController.setLooping(false);

          if (_videoPlayerController.value.duration.inSeconds == 0) {
            throw Exception('Video tidak valid atau format tidak didukung');
          }

          _addVideoListener();

          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: false,
            looping: false,
            allowMuting: true,
            showOptions: false,
            showControlsOnInitialize: false, // Jangan tampilkan kontrol dulu
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.blue,
              handleColor: Colors.blue,
              backgroundColor: Colors.grey,
              bufferedColor: Colors.lightBlue,
            ),
            placeholder: Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: $errorMessage',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          );

          setState(() {
            _isInitialized = true;
            _errorMessage = null;
          });
        } catch (e) {
          print('Error processing base64 video: $e');
          setState(() {
            _errorMessage = 'Gagal memproses video: ${e.toString()}';
            _isInitialized = false;
          });
        }
      } else {
        try {
          // URL sanitasi untuk memastikan format yang benar
          String videoUrl = widget.url;

          // Menambahkan log untuk debugging
          print('Mencoba memutar video dari URL: $videoUrl');

          // Cek apakah URL valid dan memiliki skema
          if (!videoUrl.startsWith('http://') &&
              !videoUrl.startsWith('https://')) {
            // Tambahkan protokol jika tidak ada
            videoUrl = 'https://$videoUrl';
            print('URL ditambahkan protokol: $videoUrl');
          }

          // Cek apakah URL berakhiran format video umum
          final validVideoExtensions = [
            '.mp4',
            '.mov',
            '.avi',
            '.mkv',
            '.webm'
          ];
          bool hasValidExtension = validVideoExtensions
              .any((ext) => videoUrl.toLowerCase().endsWith(ext));

          // Jika tidak ada ekstensi video yang valid, coba tambahkan format fallback (supabase sering menghilangkan ekstensi)
          if (!hasValidExtension && !videoUrl.contains('?')) {
            videoUrl = '$videoUrl.mp4';
            print('Menambahkan ekstensi fallback .mp4: $videoUrl');
          }

          // Tambahkan parameter cache buster untuk memaksa reload video
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          if (videoUrl.contains('?')) {
            videoUrl = '$videoUrl&_cb=$timestamp';
          } else {
            videoUrl = '$videoUrl?_cb=$timestamp';
          }

          print('URL final untuk pemutaran video: $videoUrl');

          // Untuk URL video biasa
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
            httpHeaders: {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          );

          // Menambahkan timeout yang lebih lama untuk inisialisasi video
          await _videoPlayerController.initialize().timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                  'Video initialization timed out after 30 seconds');
            },
          );

          // Generate thumbnail setelah video diinisialisasi
          await _generateThumbnail();

          await _videoPlayerController.setVolume(1.0);
          await _videoPlayerController.setLooping(false);

          _addVideoListener();

          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController,
            autoPlay: false,
            looping: false,
            allowMuting: true,
            showOptions: false,
            showControlsOnInitialize: false, // Jangan tampilkan kontrol dulu
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.blue,
              handleColor: Colors.blue,
              backgroundColor: Colors.grey,
              bufferedColor: Colors.lightBlue,
            ),
            placeholder: Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: $errorMessage',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          );

          setState(() {
            _isInitialized = true;
            _errorMessage = null;
          });
        } catch (e) {
          print('Error initializing URL video: $e');
          setState(() {
            _errorMessage = 'Tidak dapat memutar video: ${e.toString()}';
            _isInitialized = false;
          });
        }
      }
    } catch (e) {
      print('General error in video player: $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        _isInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          color: Colors.black54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                  _initializePlayer();
                },
                child: Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Mempersiapkan video...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Background hitam
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
        ),

        // Video player utama - selalu ada tapi dengan opacity berbeda
        Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: _isPlaying
                ? Chewie(controller: _chewieController!)
                : VideoPlayer(
                    _videoPlayerController), // Gunakan VideoPlayer sebagai thumbnail
          ),
        ),

        // Overlay untuk kontrol video
        if (!_isPlaying)
          Positioned.fill(
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  _isPlaying = true;
                });
                await _videoPlayerController.play();
              },
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        // Overlay untuk menampilkan status buffering
        if (_isBuffering)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();

    if (_tempFile != null && _tempFile!.existsSync()) {
      try {
        _tempFile!.deleteSync();
        print('File video sementara dihapus: ${_tempFile!.path}');
      } catch (e) {
        print('Gagal menghapus file sementara: $e');
      }
    }
    super.dispose();
  }
}

/// Widget untuk mengontrol video (play/pause)
class VideoControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControlsOverlay({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (widget.controller.value.isPlaying) {
            widget.controller.pause();
          } else {
            widget.controller.play();
          }
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Icon(
            widget.controller.value.isPlaying
                ? Icons.pause_circle
                : Icons.play_circle,
            size: 64,
            color: Colors.white.withAlpha(179), // 0.7 opacity = 179 (255 * 0.7)
          ),
        ),
      ),
    );
  }
}
