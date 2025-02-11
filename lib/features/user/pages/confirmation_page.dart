// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/data/models/service_model.dart';
import 'dart:io';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:servicehponline/features/user/pages/service_history_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;

class ConfirmationPage extends StatefulWidget {
  final ServiceModel service;

  const ConfirmationPage({
    Key? key,
    required this.service,
  }) : super(key: key);

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final _supabase = Supabase.instance.client;
  final _firebaseAuth = firebase.FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _submitService() async {
    setState(() => _isLoading = true);

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

      final response =
          await _supabase.from('services').insert(serviceData).select();
      if (response.isEmpty) {
        throw Exception('Failed to insert service data');
      }
      final serviceId = response[0]['id'];

      // Upload gambar ke storage jika ada
      if (widget.service.picture != null) {
        try {
          final file = File(widget.service.picture!);
          final fileExt = file.path.split('.').last;
          final fileName =
              'service_${serviceId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final filePath = fileName;

          await _supabase.storage.from('services').upload(filePath, file);

          final pictureUrl =
              _supabase.storage.from('services').getPublicUrl(filePath);

          // Update service dengan URL gambar
          await _supabase
              .from('services')
              .update({'picture_url': pictureUrl}).eq('id', serviceId);
        } catch (e) {
          print('Error uploading picture: $e');
          // Lanjutkan eksekusi meskipun upload gambar gagal
        }
      }

      // Upload video ke storage jika ada
      if (widget.service.video != null) {
        try {
          final file = File(widget.service.video!);
          final fileExt = file.path.split('.').last;
          final fileName =
              'service_${serviceId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final filePath = fileName;

          await _supabase.storage.from('services').upload(filePath, file);

          final videoUrl =
              _supabase.storage.from('services').getPublicUrl(filePath);

          // Update service dengan URL video
          await _supabase
              .from('services')
              .update({'video_url': videoUrl}).eq('id', serviceId);
        } catch (e) {
          print('Error uploading video: $e');
          // Lanjutkan eksekusi meskipun upload video gagal
        }
      }

      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.bottomSlide,
        title: 'Berhasil!',
        desc:
            'Permintaan service berhasil dikirim. Admin akan segera menentukan biaya service.',
        btnOkOnPress: () {
          // Navigasi ke halaman riwayat service dengan WillPopScope
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
      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'Gagal!',
        desc: 'Gagal mengirim permintaan service: $e',
        btnOkOnPress: () {},
        btnOkColor: Colors.red,
        btnOkText: 'OK',
      ).show();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, FontWeight? valueWeight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14.0,
              ),
            ),
          ),
          SizedBox(width: 16.0),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 14.0,
                fontWeight: valueWeight ?? FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          return false;
        }

        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Batalkan Service?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'TIDAK',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context, true); // Close dialog
                  Navigator.pop(context); // Back to previous page
                },
                child: Text(
                  'YA',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              if (_isLoading) return;

              final shouldPop = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Batalkan Service?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'TIDAK',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, true); // Close dialog
                        Navigator.pop(context); // Back to previous page
                      },
                      child: Text(
                        'YA',
                        style: TextStyle(
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
            },
          ),
          title: Text(
            'Konfirmasi Service',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Diri',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16.0),
                        _buildDetailRow(
                            'Nama Lengkap', widget.service.fullname),
                        _buildDetailRow('WhatsApp', widget.service.whatsapp),
                        _buildDetailRow('Alamat', widget.service.address),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Perangkat',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 16.0),
                        _buildDetailRow(
                          'Perangkat',
                          widget.service.device == 'iphone'
                              ? 'iPhone'
                              : widget.service.device == 'huawei'
                                  ? 'Huawei'
                                  : 'Android',
                        ),
                        _buildDetailRow('Model', widget.service.model),
                        _buildDetailRow(
                          'Masalah',
                          DeviceProblems.getProblemName(widget.service.problem),
                        ),
                        _buildDetailRow(
                            'Deskripsi', widget.service.description),
                        _buildDetailRow(
                          'Metode Pengiriman',
                          widget.service.shippingMethod == 'Jemput'
                              ? 'Dijemput'
                              : 'Diantar',
                        ),
                      ],
                    ),
                  ),
                  if (widget.service.picture != null ||
                      widget.service.video != null) ...[
                    SizedBox(height: 16.0),
                    Container(
                      padding: EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dokumentasi',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 16.0),
                          if (widget.service.picture != null)
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                image: DecorationImage(
                                  image:
                                      FileImage(File(widget.service.picture!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          if (widget.service.video != null) ...[
                            SizedBox(height: 16.0),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 48.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            'Kirim Service',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  SizedBox(height: 32.0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
