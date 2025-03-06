// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:servicehponline/data/models/service_model.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:servicehponline/features/user/pages/service_history_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:servicehponline/features/user/widgets/page_indicator_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/mixins/gps_mixin.dart';

class ConfirmationPage extends StatefulWidget {
  final ServiceModel service;
  final VoidCallback prevPage;
  final VoidCallback onConfirm;

  const ConfirmationPage({
    Key? key,
    required this.service,
    required this.prevPage,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage>
    with WidgetsBindingObserver, GPSMixin {
  final _supabase = Supabase.instance.client;
  final _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _submitService() async {
    if (_isLoading || _isSubmitting) return;

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Simpan data service ke Supabase terlebih dahulu
      final serviceData = {
        'user_id': user.uid,
        'fullname': widget.service.fullname,
        'whatsapp': widget.service.whatsapp,
        'address': widget.service.address,
        'device': widget.service.device,
        'brand': widget.service.brand,
        'model': widget.service.model,
        'problem': widget.service.problem,
        'description': widget.service.description,
        'shipping_method': widget.service.shippingMethod,
        'latitude': widget.service.latitude,
        'longitude': widget.service.longitude,
        'status': 'PENDING',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (!mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
        return;
      }

      final response =
          await _supabase.from('services').insert(serviceData).select();
      if (response.isEmpty) {
        throw Exception('Failed to insert service data');
      }
      final serviceId = response[0]['id'];

      // Upload gambar ke storage jika ada
      if (widget.service.pictureDamage != null ||
          widget.service.pictureFront != null ||
          widget.service.pictureBack != null ||
          widget.service.video != null) {
        try {
          Map<String, String> mediaUrls = {};

          // Upload foto kerusakan
          if (widget.service.pictureDamage != null) {
            final damagePicture = File(widget.service.pictureDamage!);
            final damageExt = damagePicture.path.split('.').last;
            final damageFileName =
                'service_${serviceId}_damage_${DateTime.now().millisecondsSinceEpoch}.$damageExt';

            await _supabase.storage
                .from('services')
                .upload(damageFileName, damagePicture);
            mediaUrls['picture_damage_url'] =
                _supabase.storage.from('services').getPublicUrl(damageFileName);
          }

          // Upload foto tampak depan
          if (widget.service.pictureFront != null) {
            final frontPicture = File(widget.service.pictureFront!);
            final frontExt = frontPicture.path.split('.').last;
            final frontFileName =
                'service_${serviceId}_front_${DateTime.now().millisecondsSinceEpoch}.$frontExt';

            await _supabase.storage
                .from('services')
                .upload(frontFileName, frontPicture);
            mediaUrls['picture_front_url'] =
                _supabase.storage.from('services').getPublicUrl(frontFileName);
          }

          // Upload foto tampak belakang
          if (widget.service.pictureBack != null) {
            final backPicture = File(widget.service.pictureBack!);
            final backExt = backPicture.path.split('.').last;
            final backFileName =
                'service_${serviceId}_back_${DateTime.now().millisecondsSinceEpoch}.$backExt';

            await _supabase.storage
                .from('services')
                .upload(backFileName, backPicture);
            mediaUrls['picture_back_url'] =
                _supabase.storage.from('services').getPublicUrl(backFileName);
          }

          // Upload video jika ada
          if (widget.service.video != null) {
            final video = File(widget.service.video!);
            final videoExt = video.path.split('.').last;
            final videoFileName =
                'service_${serviceId}_video_${DateTime.now().millisecondsSinceEpoch}.$videoExt';

            await _supabase.storage
                .from('services')
                .upload(videoFileName, video);
            mediaUrls['video_url'] =
                _supabase.storage.from('services').getPublicUrl(videoFileName);
          }

          // Update service dengan URL media
          if (mediaUrls.isNotEmpty) {
            await _supabase
                .from('services')
                .update(mediaUrls)
                .eq('id', serviceId);
          }
        } catch (e) {
          print('Error uploading media: $e');
          // Lanjutkan eksekusi meskipun upload media gagal
        }
      }

      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.bottomSlide,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        title: 'Berhasil!',
        desc:
            'Permintaan service berhasil dikirim. Admin akan segera menentukan biaya service.',
        btnOkOnPress: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => WillPopScope(
                onWillPop: () async {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                  return false;
                },
                child: const ServiceHistoryPage(),
              ),
            ),
            (route) => false,
          );
        },
        btnOkColor: Colors.blue,
        btnOkText: 'Lihat Riwayat',
      ).show();
    } catch (e) {
      print('Error submitting service: $e');
      if (!mounted) return;

      String errorMessage = 'Gagal mengirim permintaan service. ';
      if (e.toString().contains('PostgrestException')) {
        errorMessage += 'Terjadi kesalahan pada database. Silakan coba lagi.';
      } else {
        errorMessage += e.toString();
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        dismissOnTouchOutside: true,
        title: 'Gagal!',
        desc: errorMessage,
        btnOkOnPress: () {
          Navigator.of(context).pop();
        },
        btnOkColor: Colors.red,
        btnOkText: 'OK',
      ).show();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading || _isSubmitting) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.warning,
            animType: AnimType.scale,
            title: 'Peringatan',
            desc: 'Mohon tunggu hingga proses pengiriman selesai',
            btnOkColor: Colors.orange,
            btnOkText: 'OK',
            btnOkOnPress: () {},
            dismissOnBackKeyPress: false,
            dismissOnTouchOutside: false,
          ).show();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: AbsorbPointer(
                absorbing: _isLoading || _isSubmitting,
                child: Opacity(
                  opacity: isGpsEnabled ? 1.0 : 0.5,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PageIndicator(currentPage: 3, darkMode: false),
                              SizedBox(height: 20.0),
                              Text(
                                "Konfirmasi",
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 32.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 12.0),
                              Text(
                                "Periksa kembali data service Anda",
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 16.0,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSection(
                                  title: "Data Perangkat",
                                  content: [
                                    _buildInfoRow(
                                      label: "Perangkat",
                                      value: DeviceProblems.formatDeviceName({
                                        'device': widget.service.device,
                                        'brand': widget.service.brand,
                                        'model': widget.service.model,
                                      }),
                                    ),
                                    _buildInfoRow(
                                      label: "Masalah",
                                      value: DeviceProblems.getProblemName(
                                          widget.service.problem),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24.0),
                                _buildSection(
                                  title: "Data Diri",
                                  content: [
                                    _buildInfoRow(
                                      label: "Nama Lengkap",
                                      value: widget.service.fullname,
                                    ),
                                    _buildInfoRow(
                                      label: "WhatsApp",
                                      value: widget.service.whatsapp,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24.0),
                                _buildSection(
                                  title: "Lokasi Penjemputan",
                                  content: [
                                    _buildInfoRow(
                                      label: "Alamat",
                                      value: widget.service.address,
                                    ),
                                  ],
                                ),
                                if (widget.service.note.isNotEmpty) ...[
                                  SizedBox(height: 24.0),
                                  _buildSection(
                                    title: "Catatan Tambahan",
                                    content: [
                                      _buildInfoRow(
                                        label: "Catatan",
                                        value: widget.service.note,
                                      ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: 24.0),
                                _buildSection(
                                  title: "Metode Pengiriman",
                                  content: [
                                    _buildInfoRow(
                                      label: "Metode",
                                      value: widget.service.shippingMethod ==
                                              'Jemput'
                                          ? 'Dijemput oleh kurir'
                                          : 'Diantar ke service center',
                                    ),
                                    if (widget.service.latitude != null &&
                                        widget.service.longitude != null)
                                      _buildInfoRow(
                                        label: "Lokasi Penjemputan",
                                        value:
                                            "Lat: ${widget.service.latitude}, Long: ${widget.service.longitude}",
                                      ),
                                  ],
                                ),
                                if (widget.service.devicePasswordType !=
                                    null) ...[
                                  SizedBox(height: 24.0),
                                  _buildSection(
                                    title: "Password Perangkat",
                                    content: [
                                      _buildInfoRow(
                                        label: "Jenis Password",
                                        value:
                                            widget.service.devicePasswordType!,
                                      ),
                                      _buildInfoRow(
                                        label: "Password",
                                        value: widget.service.devicePassword ??
                                            '-',
                                      ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: 24.0),
                                _buildSection(
                                  title: "Dokumentasi",
                                  content: [
                                    if (widget.service.pictureDamage != null)
                                      _buildImagePreview(
                                        label: "Foto Kerusakan",
                                        imagePath:
                                            widget.service.pictureDamage!,
                                      ),
                                    if (widget.service.pictureFront != null)
                                      _buildImagePreview(
                                        label: "Foto Tampak Depan",
                                        imagePath: widget.service.pictureFront!,
                                      ),
                                    if (widget.service.pictureBack != null)
                                      _buildImagePreview(
                                        label: "Foto Tampak Belakang",
                                        imagePath: widget.service.pictureBack!,
                                      ),
                                    if (widget.service.video != null)
                                      _buildVideoPreview(
                                        label: "Video",
                                        videoPath: widget.service.video!,
                                      ),
                                  ],
                                ),
                                SizedBox(height: 32.0),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed:
                                      _isLoading ? null : widget.prevPage,
                                  style: TextButton.styleFrom(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      side: BorderSide(
                                          color: _isLoading
                                              ? Colors.grey[200]!
                                              : Colors.grey[300]!),
                                    ),
                                  ),
                                  child: Text(
                                    "KEMBALI",
                                    style: GoogleFonts.poppins(
                                      color: _isLoading
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.0),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submitService,
                                  style: ElevatedButton.styleFrom(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.0),
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          "KONFIRMASI",
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading || _isSubmitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Mengirim permintaan service...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Mohon tunggu sebentar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> content,
  }) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.0),
          ...content,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14.0,
            ),
          ),
          SizedBox(height: 4.0),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 15.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview({
    required String label,
    required String imagePath,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14.0,
          ),
        ),
        SizedBox(height: 8.0),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(File(imagePath)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildVideoPreview({
    required String label,
    required String videoPath,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 14.0,
          ),
        ),
        SizedBox(height: 8.0),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        SizedBox(height: 16.0),
      ],
    );
  }
}
