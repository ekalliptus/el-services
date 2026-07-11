import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/core/widgets/widgets.dart';
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
  bool _hasUnsavedChanges = false;
  File? _selectedImage;
  File? _selectedVideo;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _complaintController.addListener(_updateUnsavedChangesState);
  }

  @override
  void dispose() {
    _complaintController.removeListener(_updateUnsavedChangesState);
    _complaintController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _updateUnsavedChangesState() {
    final hasText = _complaintController.text.isNotEmpty;
    final hasMedia = _selectedImage != null || _selectedVideo != null;

    final newHasUnsavedChanges = hasText || hasMedia;

    if (newHasUnsavedChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = newHasUnsavedChanges;
      });
    }
  }

  // Ambil inisial nama secara aman (hindari RangeError pada string kosong).
  String _initialNama(dynamic customerName, String? displayName) {
    final c = customerName?.toString().trim() ?? '';
    if (c.isNotEmpty) return c[0].toUpperCase();
    final d = displayName?.trim() ?? '';
    if (d.isNotEmpty) return d[0].toUpperCase();
    return 'A';
  }

  Widget _buildAvatar(Map<String, dynamic> service, firebase_auth.User? user) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            user?.photoURL != null ? Colors.transparent : colorScheme.primary,
      ),
      child: CircleAvatar(
        backgroundColor: user?.photoURL != null
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Text(
                _initialNama(service['customer_name'], user?.displayName),
                style: GoogleFonts.poppins(
                  color: colorScheme.onPrimary,
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
          final colorScheme = Theme.of(context).colorScheme;
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
                          if (!mounted) return;
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
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: colorScheme.primary,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
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
                          if (!mounted) return;
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
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.photo_library,
                                color: AppColors.success,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
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
      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: 'Gagal memilih foto. Silakan coba lagi.',
        btnOkColor: Theme.of(context).colorScheme.error,
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
          final colorScheme = Theme.of(context).colorScheme;
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
                          if (!mounted) return;
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
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.videocam,
                                color: colorScheme.primary,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
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
                          if (!mounted) return;
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
                                color: AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.video_library,
                                color: AppColors.success,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
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
      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: 'Gagal memilih video. Silakan coba lagi.',
        btnOkColor: Theme.of(context).colorScheme.error,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
    }
  }

  // Hapus objek yang sudah terupload ke storage bila alur komplain gagal,
  // agar tidak meninggalkan file yatim.
  Future<void> _cleanupUploads(List<String> fileNames) async {
    if (fileNames.isEmpty) return;
    try {
      await _supabase.storage.from('services').remove(fileNames);
    } catch (e) {
      print('Gagal membersihkan media terupload: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_selectedVideo != null) {
      // Buang controller sebelumnya bila ada agar tidak bocor saat pengguna
      // mengganti video tanpa menekan "Hapus Video".
      await _videoController?.dispose();
      _videoController = VideoPlayerController.file(_selectedVideo!);
      await _videoController!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _submitComplaint() async {
    if (_complaintController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detail komplain wajib diisi'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        btnOkColor: Theme.of(context).colorScheme.error,
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
      // Lacak objek yang sudah terupload agar bisa dibersihkan bila alur gagal.
      final List<String> uploadedFiles = [];

      // Upload foto jika ada
      if (_selectedImage != null) {
        try {
          final fileName =
              'complaint_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _supabase.storage
              .from('services')
              .upload(fileName, _selectedImage!);
          uploadedFiles.add(fileName);
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
          uploadedFiles.add(fileName);
          videoUrl = _supabase.storage.from('services').getPublicUrl(fileName);
          print('Video berhasil diupload: $videoUrl');
        } catch (e) {
          print('Error saat upload video: $e');
          // Bersihkan media yang sudah terlanjur terupload.
          await _cleanupUploads(uploadedFiles);
          throw Exception('Gagal mengupload video');
        }
      }

      // Insert data komplain LEBIH DULU (sumber kebenaran). Status service
      // baru diubah setelah komplain tersimpan, agar status tidak terlanjur
      // menjadi COMPLAINED bila insert gagal.
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

        // Baru setelah komplain tersimpan, tandai status service.
        // ponytail: mutasi status ini dipercaya dari client; idealnya
        // divalidasi kepemilikan via RLS/server (lihat SECURITY-PAYMENT.md).
        try {
          await _supabase.from('services').update({
            'status': 'COMPLAINED',
            'complain': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', widget.service['id']);
          print('Status service berhasil diupdate');
        } catch (e) {
          print('Peringatan: komplain tersimpan tapi gagal update status: $e');
          // Tidak fatal: komplain sudah tercatat. Jangan gagalkan alur.
        }

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
          btnOkColor: Theme.of(context).colorScheme.primary,
          btnOkText: 'Ke Beranda',
          btnOkOnPress: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/',
              (route) => false,
            );
          },
          btnCancelText: 'Ke Riwayat',
          btnCancelColor: AppColors.success,
          btnCancelOnPress: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/history',
              (route) => route.isFirst,
            );
          },
        ).show();
      } catch (e) {
        print('Error detail saat insert komplain: $e');
        // Bersihkan media yang sudah terupload agar tidak jadi objek yatim.
        await _cleanupUploads(uploadedFiles);
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
        btnOkColor: Theme.of(context).colorScheme.error,
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
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isSubmitting && !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isSubmitting) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mohon tunggu, komplain sedang diproses...',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (_hasUnsavedChanges) {
          bool shouldPop = false;

          await showDialog<bool>(
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
                  color: colorScheme.onSurface,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'TIDAK',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    shouldPop = true;
                    Navigator.pop(context);
                  },
                  child: Text(
                    'YA',
                    style: GoogleFonts.poppins(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (!mounted) return;
          if (shouldPop) {
            Navigator.of(context).pop();
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'TIDAK',
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'YA',
                          style: GoogleFonts.poppins(
                            color: colorScheme.error,
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
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnrCard(
                child: Row(
                  children: [
                    _buildAvatar(widget.service, currentUser),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service #${widget.service['id']}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.service['device']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'android'
                                ? '${widget.service['brand']} - ${widget.service['model']}'
                                : '${widget.service['brand']} - ${widget.service['model']}',
                            style: GoogleFonts.poppins(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              AnrSectionHeader(
                title: 'Detail Komplain',
                subtitle: 'Jelaskan masalah yang Anda alami.',
                trailing: Text(
                  'Wajib',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.error,
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _complaintController,
                maxLines: 8,
                maxLength: 500,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Jelaskan detail komplain Anda...',
                  counterText: '',
                  fillColor: _isSubmitting
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface,
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Maksimal 500 karakter',
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 24),
              AnrSectionHeader(
                title: 'Dokumentasi',
                subtitle: 'Tambahkan foto atau video pendukung.',
                trailing: Text(
                  'Opsional',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
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
                                    color: colorScheme.onSurfaceVariant,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tambah Foto',
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSurfaceVariant,
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
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: _selectedVideo != null
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_videoController?.value.isInitialized ??
                                      false)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
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
                                    color: colorScheme.onSurfaceVariant,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tambah Video',
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSurfaceVariant,
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
                            color: _isSubmitting
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error),
                        label: Text(
                          'Hapus Foto',
                          style: GoogleFonts.poppins(
                            color: _isSubmitting
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error,
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
                            color: _isSubmitting
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error),
                        label: Text(
                          'Hapus Video',
                          style: GoogleFonts.poppins(
                            color: _isSubmitting
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              SizedBox(height: 24),
              AnrButton(
                label: 'Kirim Komplain',
                onPressed: _isSubmitting ? null : _submitComplaint,
                icon: Icons.send_rounded,
                loading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
