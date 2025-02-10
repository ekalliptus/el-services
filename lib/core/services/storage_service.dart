import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'service-media';
  static const int maxImageSize = 2 * 1024 * 1024; // 2MB
  static const int maxVideoSize = 3 * 1024 * 1024; // 3MB

  Future<File?> _compressImage(File imageFile) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        path.join(dir.path, 'compressed_${path.basename(imageFile.path)}');
    final fileSize = await imageFile.length();

    if (fileSize <= maxImageSize) {
      return imageFile;
    }

    try {
      final quality = (maxImageSize / fileSize * 100).round();
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: quality.clamp(1, 100),
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        throw Exception('Kompresi gambar gagal');
      }

      // Konversi XFile ke File
      final compressedFile = File(result.path);

      // Jika masih terlalu besar, kompres lagi dengan kualitas lebih rendah
      if (await compressedFile.length() > maxImageSize) {
        return await _compressImage(compressedFile);
      }

      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<File?> _compressVideo(File videoFile) async {
    final fileSize = await videoFile.length();

    if (fileSize <= maxVideoSize) {
      return videoFile;
    }

    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo?.file == null) {
        throw Exception('Kompresi video gagal');
      }

      // Jika masih terlalu besar, kompres lagi dengan kualitas lebih rendah
      if (await mediaInfo!.file!.length() > maxVideoSize) {
        return await _compressVideo(mediaInfo.file!);
      }

      return mediaInfo.file;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  Future<String?> uploadImage(File imageFile, String serviceId) async {
    try {
      // Kompres gambar sebelum upload
      final compressedImage = await _compressImage(imageFile);
      if (compressedImage == null) {
        throw Exception('Kompresi gambar gagal');
      }

      final fileSize = await compressedImage.length();
      if (fileSize > maxImageSize) {
        throw Exception('Ukuran gambar terlalu besar (max 2MB)');
      }

      final fileExt = path.extension(compressedImage.path);
      final fileName =
          'service_$serviceId${DateTime.now().millisecondsSinceEpoch}$fileExt';

      final storageResponse = await _supabase.storage.from(_bucketName).upload(
            'images/$fileName',
            compressedImage,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      if (storageResponse.isEmpty) {
        throw Exception('Upload gambar gagal');
      }

      final imageUrl =
          _supabase.storage.from(_bucketName).getPublicUrl('images/$fileName');

      // Hapus file temporary
      if (compressedImage.path != imageFile.path) {
        await compressedImage.delete();
      }

      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> uploadVideo(File videoFile, String serviceId) async {
    try {
      // Kompres video sebelum upload
      final compressedVideo = await _compressVideo(videoFile);
      if (compressedVideo == null) {
        throw Exception('Kompresi video gagal');
      }

      final fileSize = await compressedVideo.length();
      if (fileSize > maxVideoSize) {
        throw Exception('Ukuran video terlalu besar (max 3MB)');
      }

      final fileExt = path.extension(compressedVideo.path);
      final fileName =
          'service_$serviceId${DateTime.now().millisecondsSinceEpoch}$fileExt';

      final storageResponse = await _supabase.storage.from(_bucketName).upload(
            'videos/$fileName',
            compressedVideo,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      if (storageResponse.isEmpty) {
        throw Exception('Upload video gagal');
      }

      final videoUrl =
          _supabase.storage.from(_bucketName).getPublicUrl('videos/$fileName');

      // Hapus file temporary
      if (compressedVideo.path != videoFile.path) {
        await compressedVideo.delete();
      }

      // Clear video cache
      await VideoCompress.deleteAllCache();

      return videoUrl;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  Future<bool> deleteMedia(String mediaUrl) async {
    try {
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;
      final filePath =
          pathSegments.sublist(pathSegments.indexOf(_bucketName) + 1).join('/');

      await _supabase.storage.from(_bucketName).remove([filePath]);

      return true;
    } catch (e) {
      print('Error deleting media: $e');
      return false;
    }
  }
}
