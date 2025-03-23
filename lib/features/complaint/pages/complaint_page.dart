import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';

class ComplaintPage extends StatefulWidget {
  final Map<String, dynamic> service;

  const ComplaintPage({
    Key? key,
    required this.service,
  }) : super(key: key);

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final _supabase = Supabase.instance.client;
  final _auth = firebase_auth.FirebaseAuth.instance;
  final _complaintController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isSubmitting = false;
  File? _selectedImage;
  File? _selectedVideo;
  VideoPlayerController? _videoController;

  Widget _buildAvatar(Map<String, dynamic> service, firebase_auth.User? user) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user?.photoURL != null ? Colors.transparent : Colors.blue,
      ),
      child: CircleAvatar(
        backgroundColor:
            user?.photoURL != null ? Colors.grey[200] : Colors.blue,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Text(
                (service['customer_name'] ?? user?.displayName ?? 'A')[0]
                    .toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Sumber Foto',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 1080,
                            maxHeight: 1080,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setState(() {
                              _selectedImage = File(image.path);
                            });
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(
                                    red: 33, green: 150, blue: 243, alpha: 26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1080,
                            maxHeight: 1080,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setState(() {
                              _selectedImage = File(image.path);
                            });
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(
                                    red: 76, green: 175, blue: 80, alpha: 26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.photo_library,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error picking image: $e');
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: 'Gagal memilih foto. Silakan coba lagi.',
        btnOkColor: Colors.red,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> _pickVideo() async {
    try {
      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Sumber Video',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? video = await _imagePicker.pickVideo(
                            source: ImageSource.camera,
                            maxDuration: Duration(minutes: 1),
                          );
                          if (video != null) {
                            setState(() {
                              _selectedVideo = File(video.path);
                            });
                            _initializeVideoPlayer();
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(
                                    red: 33, green: 150, blue: 243, alpha: 26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.videocam,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? video = await _imagePicker.pickVideo(
                            source: ImageSource.gallery,
                            maxDuration: Duration(minutes: 1),
                          );
                          if (video != null) {
                            setState(() {
                              _selectedVideo = File(video.path);
                            });
                            _initializeVideoPlayer();
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(
                                    red: 76, green: 175, blue: 80, alpha: 26),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.video_library,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error picking video: $e');
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: 'Gagal memilih video. Silakan coba lagi.',
        btnOkColor: Colors.red,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideo != null) {
      _videoController = VideoPlayerController.file(_selectedVideo!);
      await _videoController!.initialize();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (_complaintController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detail komplain wajib diisi'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Peringatan',
        desc: 'Mohon isi detail komplain Anda',
        btnOkColor: Colors.red,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception(
            'Silakan login terlebih dahulu untuk mengajukan komplain');
      }

      if (widget.service['id'] == null) {
        throw Exception('Data service tidak valid');
      }

      String? imageUrl;
      String? videoUrl;

      // Upload foto jika ada
      if (_selectedImage != null) {
        try {
          final fileName =
              'complaint_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage
              .from('services')
              .upload(fileName, _selectedImage!);
          imageUrl = _supabase.storage.from('services').getPublicUrl(fileName);
          print('Foto berhasil diupload: $imageUrl');
        } catch (e) {
          print('Error saat upload foto: $e');
          throw Exception('Gagal mengupload foto');
        }
      }

      // Upload video jika ada
      if (_selectedVideo != null) {
        try {
          final fileName =
              'complaint_${DateTime.now().millisecondsSinceEpoch}.mp4';
          await _supabase.storage
              .from('services')
              .upload(fileName, _selectedVideo!);
          videoUrl = _supabase.storage.from('services').getPublicUrl(fileName);
          print('Video berhasil diupload: $videoUrl');
        } catch (e) {
          print('Error saat upload video: $e');
          throw Exception('Gagal mengupload video');
        }
      }

      // Update status service
      try {
        await _supabase.from('services').update({
          'status': 'COMPLAINED',
          'complain': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.service['id']);
        print('Status service berhasil diupdate');
      } catch (e) {
        print('Error saat update status service: $e');
        throw Exception('Gagal mengupdate status service');
      }

      // Insert data komplain
      final complaintData = {
        'service_id': widget.service['id'],
        'user_id': firebaseUser.uid,
        'description': _complaintController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'PENDING',
        'fullname': widget.service['customer_name'] ??
            firebaseUser.displayName ??
            firebaseUser.email?.split('@')[0] ??
            'Anonymous',
        'photo_url': imageUrl,
        'video_url': videoUrl,
      };

      print('Mencoba insert data komplain: $complaintData');

      try {
        final response = await _supabase
            .from('complaints')
            .insert(complaintData)
            .select()
            .single();
        print('Komplain berhasil disimpan dengan ID: ${response['id']}');

        if (!mounted) return;

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          dismissOnTouchOutside: false,
          dismissOnBackKeyPress: false,
          title: 'Berhasil',
          desc:
              'Komplain Anda telah dikirim. Admin akan segera menindaklanjuti.',
          btnOkColor: Colors.blue,
          btnOkText: 'OK',
          btnOkOnPress: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ).show();
      } catch (e) {
        print('Error detail saat insert komplain: $e');
        throw Exception('Gagal menyimpan data komplain ke database');
      }
    } catch (e) {
      print('Error saat mengirim komplain: $e');

      if (!mounted) return;

      String errorMessage = 'Gagal mengirim komplain. ';
      if (e.toString().contains('login')) {
        errorMessage += 'Silakan login terlebih dahulu.';
      } else if (e.toString().contains('service')) {
        errorMessage += 'Data service tidak valid.';
      } else if (e.toString().contains('foto')) {
        errorMessage += 'Gagal mengupload foto.';
      } else if (e.toString().contains('video')) {
        errorMessage += 'Gagal mengupload video.';
      } else if (e.toString().contains('database')) {
        errorMessage += 'Gagal menyimpan ke database.';
      } else {
        errorMessage += e.toString();
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: errorMessage,
        btnOkColor: Colors.red,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) {
          return false;
        }

        if (_complaintController.text.isNotEmpty ||
            _selectedImage != null ||
            _selectedVideo != null) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Batalkan Komplain?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'TIDAK',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: Text(
                    'YA',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (_isSubmitting) return;

              if (_complaintController.text.isNotEmpty ||
                  _selectedImage != null ||
                  _selectedVideo != null) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Batalkan Komplain?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: Text(
                      'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'TIDAK',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        child: Text(
                          'YA',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (shouldPop ?? false) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Ajukan Komplain',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildAvatar(widget.service, currentUser),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service #${widget.service['id']}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.service['device']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'android'
                                  ? '${widget.service['brand']} - ${widget.service['model']}'
                                  : '${widget.service['brand']} - ${widget.service['model']}',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Detail Komplain',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "(Wajib Diisi)",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _isSubmitting ? Colors.grey[100] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _complaintController,
                  maxLines: 8,
                  maxLength: 500,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan detail komplain Anda...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    counterText: '',
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Maksimal 500 karakter',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Dokumentasi',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "(Opsional)",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.grey[600],
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tambah Foto',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickVideo,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _selectedVideo != null
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_videoController?.value.isInitialized ??
                                      false)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: AspectRatio(
                                        aspectRatio:
                                            _videoController!.value.aspectRatio,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    ),
                                  Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam_outlined,
                                    color: Colors.grey[600],
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tambah Video',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedImage != null || _selectedVideo != null) ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    if (_selectedImage != null)
                      TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _selectedImage = null),
                        icon: Icon(Icons.delete_outline,
                            color: _isSubmitting ? Colors.grey : Colors.red),
                        label: Text(
                          'Hapus Foto',
                          style: GoogleFonts.poppins(
                            color: _isSubmitting ? Colors.grey : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_selectedVideo != null)
                      TextButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _selectedVideo = null;
                                  _videoController?.dispose();
                                  _videoController = null;
                                });
                              },
                        icon: Icon(Icons.delete_outline,
                            color: _isSubmitting ? Colors.grey : Colors.red),
                        label: Text(
                          'Hapus Video',
                          style: GoogleFonts.poppins(
                            color: _isSubmitting ? Colors.grey : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Kirim Komplain',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
