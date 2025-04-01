import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:servicehponline/features/admin/widgets/info_section_widget.dart';
import 'package:servicehponline/features/admin/widgets/location_section_widget.dart';
import 'package:servicehponline/features/admin/widgets/documentation_section_widget.dart';
import 'package:servicehponline/features/admin/utils/status_utils.dart';
import 'package:servicehponline/features/admin/widgets/action_buttons_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servicehponline/features/admin/dialogs/documentation_preview_dialog.dart'
    as docPreview;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ServiceCardWidget extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(String, String) onUpdateStatus;
  final Function(Map<String, dynamic>) onUpdateCost;
  final Function(Map<String, dynamic>) onAdditionalCost;
  final NumberFormat currencyFormat;
  final Function(bool, {String action})? onUploadingDoc;

  // Konstanta untuk batasan ukuran file
  static const int MAX_PHOTO_SIZE = 10 * 1024 * 1024; // 10 MB
  static const int MAX_VIDEO_SIZE = 50 * 1024 * 1024; // 50 MB
  static const Duration MAX_VIDEO_DURATION = Duration(minutes: 1);

  const ServiceCardWidget({
    Key? key,
    required this.service,
    required this.onUpdateStatus,
    required this.onUpdateCost,
    required this.onAdditionalCost,
    required this.currencyFormat,
    this.onUploadingDoc,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var status = service['status']?.toString().toUpperCase() ?? 'PENDING';
    final hasPayment = service['service_cost'] != null;
    final hasComplaint = (service['complaints'] ?? []).isNotEmpty;

    // Jika status PENDING dan sudah ada biaya service, tampilkan sebagai "Belum Dibayar"
    final displayStatus =
        (status == 'PENDING' && hasPayment) ? 'WAITING_PAYMENT' : status;

    // Jika ada komplain, status ditampilkan sebagai "COMPLAINED", jadi tidak perlu label terpisah
    final isComplainedStatus = displayStatus == 'COMPLAINED';

    // Status processed dan completed untuk menentukan tampilan dokumentasi awal
    final isCompletedStatus = displayStatus == 'COMPLETED';
    final isProcessedStatus = displayStatus == 'PROCESSED';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasComplaint ? Colors.red.withAlpha(77) : Colors.grey[200]!,
        ),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: EdgeInsets.all(20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        StatusUtils.getStatusColor(displayStatus).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: StatusUtils.getStatusColor(displayStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        StatusUtils.getStatusText(displayStatus),
                        style: GoogleFonts.poppins(
                          color: StatusUtils.getStatusColor(displayStatus),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tampilkan indikator komplain hanya jika ada komplain DAN status bukan "COMPLAINED"
                if (hasComplaint && !isComplainedStatus)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Komplain',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Service #${service['id']}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4),
                Text(
                  formatDate(service['created_at']),
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              '${service['brand']} - ${service['model']}',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            if (hasPayment) ...[
              SizedBox(height: 4),
              // Selalu tampilkan biaya service sebagai "Biaya Awal:"
              Row(
                children: [
                  Text(
                    'Biaya Awal: ',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    currencyFormat.format(service['service_cost']),
                    style: GoogleFonts.poppins(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Selalu cek additional cost dari database dengan FutureBuilder
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _getAllAdditionalCosts(service['id'].toString()),
                builder: (context, snapshot) {
                  // Tampilkan loading indicator selama cek data
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  // Jika tidak ada data tambahan, jangan tampilkan apapun
                  if (!snapshot.hasData ||
                      snapshot.data == null ||
                      snapshot.data!.isEmpty) {
                    return SizedBox.shrink();
                  }

                  final additionalCosts = snapshot.data!;

                  // Hitung total biaya tambahan
                  int totalAdditionalCost = 0;
                  for (var cost in additionalCosts) {
                    totalAdditionalCost += (cost['amount'] ?? 0) as int;
                  }

                  // Jika total biaya tambahan 0, jangan tampilkan
                  if (totalAdditionalCost <= 0) {
                    return SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tampilkan total biaya tambahan
                      Row(
                        children: [
                          Text(
                            'Biaya Tambahan: ',
                            style: GoogleFonts.poppins(
                              color: Colors.orange[700],
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            currencyFormat.format(totalAdditionalCost),
                            style: GoogleFonts.poppins(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          // Tambahkan ikon untuk menampilkan detail
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: InkWell(
                              child: Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                              onTap: () => _showAdditionalCostsDetail(
                                  context, additionalCosts),
                            ),
                          ),
                        ],
                      ),

                      // Tampilkan catatan dari biaya tambahan terakhir
                      if (additionalCosts.first['note'] != null &&
                          additionalCosts.first['note'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'Catatan terbaru: ${additionalCosts.first['note']}',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoSectionWidget(service: service),
              SizedBox(height: 24),

              // Tambahan Bagian catatan alamat dan kata sandi
              _buildAdditionalInfoSection(service),
              SizedBox(height: 24),

              LocationSectionWidget(service: service),
              SizedBox(height: 24),

              // Bagian dokumentasi foto dan video sebelum service - hanya tampilkan jika status PROCESSED atau COMPLETED
              if (isProcessedStatus || isCompletedStatus) ...[
                _buildPreServiceDocSection(context, service,
                    isReadOnly: isCompletedStatus),
                SizedBox(height: 24),
              ],

              DocumentationSectionWidget(service: service),
              SizedBox(height: 24),
              ActionButtonsWidget(
                service: service,
                onUpdateStatus: onUpdateStatus,
                onUpdateCost: onUpdateCost,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection(Map<String, dynamic> service) {
    final devicePassword = service['device_password'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Tambahan',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),

        // Kata Sandi Perangkat
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.password, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kata Sandi Perangkat',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    devicePassword,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget untuk menampilkan dokumentasi sebelum service dan opsi untuk menambahkan
  Widget _buildPreServiceDocSection(
      BuildContext context, Map<String, dynamic> service,
      {bool isReadOnly = false}) {
    final serviceId = service['id'].toString();

    // Gunakan StatefulBuilder untuk memungkinkan rebuild lokal tanpa rebuild seluruh widget
    return StatefulBuilder(builder: (context, setState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul
          Text(
            'Dokumentasi Kondisi Awal',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          // Tampilkan tombol hanya jika tidak dalam mode read-only (COMPLETED)
          SizedBox(height: 12),
          if (!isReadOnly)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showDocumentationOptions(context, serviceId),
                      icon: Icon(Icons.add_a_photo, size: 16),
                      label: Text('Tambah'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Tombol refresh dengan StatefulBuilder
                    ElevatedButton.icon(
                      onPressed: () => _refreshServiceDataWithState(
                          context, serviceId, setState),
                      icon: Icon(Icons.refresh, size: 16),
                      label: Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Informasi refresh
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    'Note: Jika gambar/video tidak hilang/muncul otomatis, silahkan tekan tombol refresh setelah proses upload/hapus telah selesai',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          // Selalu gunakan _buildPreServiceDocList yang akan menghandle list kosong
          _buildPreServiceDocList(context, service, isReadOnly: isReadOnly),
        ],
      );
    });
  }

  // Metode yang lebih efektif untuk refresh data dengan StateSetter
  Future<void> _refreshServiceDataWithState(
      BuildContext context, String serviceId, StateSetter setState) async {
    final supabase = Supabase.instance.client;

    try {
      // Tampilkan SnackBar loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Memuat ulang data...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Hapus cache Supabase terlebih dahulu
      await supabase.auth.refreshSession();

      // Ambil data terbaru dari Supabase
      final updatedService = await supabase
          .from('services')
          .select('*, pre_service_docs')
          .eq('id', serviceId)
          .single();

      print(
          'Refresh berhasil: ${updatedService['pre_service_docs']?.length ?? 0} dokumen');

      // Update service dengan data terbaru dan rebuild UI
      setState(() {
        // Update data service secara lokal
        service.clear();
        service.addAll(updatedService);
      });

      // Tampilkan SnackBar sukses
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Data berhasil diperbarui'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error refreshing service data: $e');

      // Tampilkan SnackBar error
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Gagal memperbarui data: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Widget untuk menampilkan daftar dokumentasi sebelum service
  Widget _buildPreServiceDocList(
      BuildContext context, Map<String, dynamic> service,
      {bool isReadOnly = false}) {
    // Periksa jika pre_service_docs adalah null
    final preServiceDocs = service['pre_service_docs'] as List? ?? [];

    // Check jika list kosong
    if (preServiceDocs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Belum ada dokumentasi kondisi awal',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Gunakan key unik untuk memaksa ListView memperbarui konten
    final refreshKey =
        ValueKey('doc_list_${DateTime.now().millisecondsSinceEpoch}');

    return Container(
      height: 120,
      key: refreshKey,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: preServiceDocs.length,
        itemBuilder: (context, index) {
          final doc = preServiceDocs[index];
          return _buildDocItem(context, doc, isReadOnly: isReadOnly);
        },
      ),
    );
  }

  // Konfirmasi hapus dokumen
  void _confirmDeleteDoc(BuildContext context, String serviceId, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Dokumentasi'),
        content: Text('Anda yakin ingin menghapus dokumen ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('BATAL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocumentation(context, serviceId, docId);
            },
            child: Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  // Proses hapus dokumentasi
  Future<void> _deleteDocumentation(
      BuildContext context, String serviceId, String docId) async {
    final supabase = Supabase.instance.client;

    // Aktifkan indikator loading global dengan parameter delete
    if (onUploadingDoc != null) {
      onUploadingDoc!(true, action: 'delete');
    }

    try {
      // Ambil data service untuk mendapatkan informasi file
      final serviceData =
          await supabase.from('services').select().eq('id', serviceId).single();
      final preServiceDocs = List<Map<String, dynamic>>.from(
          serviceData['pre_service_docs'] ?? []);

      // Cari dokumen dengan id yang sesuai
      final docToDelete = preServiceDocs.firstWhere(
        (doc) => doc['id'] == docId,
        orElse: () => <String, dynamic>{},
      );

      // Hapus file dari storage jika path tersedia
      if (docToDelete.isNotEmpty && docToDelete.containsKey('path')) {
        final filePath = docToDelete['path'];
        try {
          await supabase.storage.from('pre_service_docs').remove([filePath]);
          print('Berhasil menghapus file dari storage: $filePath');

          // Jika ada thumbnail, hapus juga
          if (docToDelete['type'] == 'video' &&
              docToDelete.containsKey('thumbnail_url')) {
            final thumbnailPath = '${filePath}_thumbnail.jpg';
            try {
              await supabase.storage
                  .from('pre_service_docs')
                  .remove([thumbnailPath]);
              print('Berhasil menghapus thumbnail: $thumbnailPath');
            } catch (e) {
              print('Gagal menghapus thumbnail: $e');
              // Lanjutkan proses meskipun thumbnail gagal dihapus
            }
          }
        } catch (e) {
          print('Error menghapus file: $e');
          // Lanjutkan meskipun file tidak dapat dihapus dari storage
        }
      }

      // Update data service dengan menghapus dokumen dari array
      final updatedDocs =
          preServiceDocs.where((doc) => doc['id'] != docId).toList();
      await supabase.from('services').update({
        'pre_service_docs': updatedDocs,
      }).eq('id', serviceId);

      // Tampilkan notifikasi sukses
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Dokumentasi berhasil dihapus'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Trigger reload data service terbaru
      if (context.mounted) {
        await _refreshServiceData(context, serviceId);
      }
    } catch (e) {
      // Tampilkan notifikasi error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Gagal menghapus dokumentasi: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      print('Error menghapus dokumentasi: $e');
    } finally {
      // Nonaktifkan indikator loading global
      if (onUploadingDoc != null) {
        onUploadingDoc!(false);
      }
    }
  }

  // Tampilkan opsi untuk menambah foto atau video
  void _showDocumentationOptions(BuildContext context, String serviceId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            // Header dengan informasi batasan
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Colors.blue.withAlpha(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tambah Dokumentasi Kondisi Awal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Foto: maksimal 10 MB',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Video: maksimal 50 MB dengan durasi 1 menit',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera),
              title: Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _takePicture(context, serviceId);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, serviceId);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Rekam Video'),
              onTap: () {
                Navigator.pop(context);
                _recordVideo(context, serviceId);
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library),
              title: Text('Pilih Video dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(context, serviceId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Metode untuk menangani validasi dan upload foto
  Future<void> _handleImageUpload(
      BuildContext context, File imageFile, String serviceId) async {
    // Aktifkan indikator loading
    if (onUploadingDoc != null) {
      onUploadingDoc!(true, action: 'upload');
    }

    try {
      // Periksa ukuran file
      final fileSize = await imageFile.length();
      print('Image size: ${fileSize / 1024 / 1024}MB');

      // Validasi ukuran file
      if (fileSize > MAX_PHOTO_SIZE) {
        // Tampilkan AlertDialog untuk ukuran file yang melebihi batas
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Ukuran File Terlalu Besar'),
              content: Text(
                  'Ukuran foto melebihi 10 MB. Silakan gunakan foto yang lebih kecil.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
        throw Exception('Ukuran foto melebihi batas maksimum 10 MB');
      }

      // Upload media tanpa kompresi
      await _uploadMedia(context, imageFile, serviceId, 'image');
    } catch (e) {
      print('Error handling image: $e');
      // Pesan error akan ditampilkan di _uploadMedia jika gagal
    } finally {
      // Nonaktifkan indikator loading
      if (onUploadingDoc != null) {
        onUploadingDoc!(false);
      }
    }
  }

  // Metode untuk menangani validasi dan upload video
  Future<void> _handleVideoUpload(
      BuildContext context, File videoFile, String serviceId) async {
    // Aktifkan indikator loading
    if (onUploadingDoc != null) {
      onUploadingDoc!(true, action: 'upload');
    }

    try {
      // Periksa durasi video
      final isDurationValid = await isVideoDurationValid(videoFile);
      if (!isDurationValid) {
        // Tampilkan AlertDialog untuk durasi yang melebihi batas
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Durasi Video Terlalu Panjang'),
              content: Text('Durasi video melebihi batas maksimal 1 menit'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
        throw Exception('Durasi video melebihi batas maksimal 1 menit');
      }

      // Periksa ukuran file
      final fileSize = await videoFile.length();
      print('Video size: ${fileSize / 1024 / 1024}MB');

      // Validasi ukuran file
      if (fileSize > MAX_VIDEO_SIZE) {
        // Tampilkan AlertDialog untuk ukuran file yang melebihi batas
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Ukuran File Terlalu Besar'),
              content: Text(
                  'Ukuran video melebihi 50 MB. Silakan gunakan video yang lebih kecil.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
        throw Exception('Ukuran video melebihi batas maksimum 50 MB');
      }

      // Upload media tanpa kompresi
      await _uploadMedia(context, videoFile, serviceId, 'video');
    } catch (e) {
      print('Error handling video: $e');
      // Pesan error akan ditampilkan di _uploadMedia jika gagal
    } finally {
      // Nonaktifkan indikator loading
      if (onUploadingDoc != null) {
        onUploadingDoc!(false);
      }
    }
  }

  // Upload media (foto/video) ke storage
  Future<void> _uploadMedia(
      BuildContext context, File file, String serviceId, String type) async {
    final supabase = Supabase.instance.client;

    // Aktifkan indikator loading global dengan parameter upload (default)
    if (onUploadingDoc != null) {
      onUploadingDoc!(true, action: 'upload');
    }

    // Tampilkan loading indicator di SnackBar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Memproses ${type == 'image' ? 'foto' : 'video'}...'),
            ],
          ),
          duration: Duration(seconds: 60), // Durasi lebih pendek
          backgroundColor: Colors.blue,
        ),
      );
    }

    try {
      // Generate nama file yang unik dengan timestamp dan UUID
      final fileExt = file.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final randomId = supabase.auth.currentUser?.id ?? timestamp;
      final fileName =
          'service_${serviceId}_${type}_${timestamp}_${randomId.substring(0, 8)}.$fileExt';

      // Variabel untuk menyimpan file yang akan diproses
      File processedFile;

      // Kompresi file berdasarkan jenisnya
      if (type == 'image') {
        // Kompresi gambar dengan flutter_image_compress
        final appDir = await getTemporaryDirectory();
        final targetPath = '${appDir.path}/${fileName}_compressed.jpg';

        final result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: 85, // Kualitas kompresi 85% (lebih tinggi)
          minWidth: 1200, // Batasi lebar maksimal
          minHeight: 1200, // Batasi tinggi maksimal
        );

        if (result == null) {
          throw Exception('Gagal mengompresi gambar');
        }

        processedFile = File(result.path);
        print(
            'Image compressed: ${await file.length() / 1024 / 1024}MB -> ${await processedFile.length() / 1024 / 1024}MB');
      } else {
        // Untuk video, gunakan video_compress dengan kualitas lebih tinggi
        final info = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (info?.file == null) {
          throw Exception('Gagal mengompresi video');
        }

        processedFile = File(info!.file!.path);
        print(
            'Video compressed: ${await file.length() / 1024 / 1024}MB -> ${await processedFile.length() / 1024 / 1024}MB');
      }

      // Selalu upload ke Supabase terlebih dahulu, tidak perlu cek ukuran base64
      try {
        // Upload langsung ke root bucket
        final filePath = fileName; // Tidak menggunakan subfolder

        print('Uploading to Supabase: $filePath');
        await supabase.storage.from('pre_service_docs').upload(
              filePath,
              processedFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
                contentType: null, // Biarkan Supabase deteksi otomatis
              ),
            );

        // Dapatkan URL publik
        final fileUrl =
            supabase.storage.from('pre_service_docs').getPublicUrl(filePath);
        print('Uploaded successfully, URL: $fileUrl');

        // Buat ID unik untuk dokumen ini
        final docId = DateTime.now().millisecondsSinceEpoch.toString();

        // Ambil data service saat ini
        final serviceData = await supabase
            .from('services')
            .select()
            .eq('id', serviceId)
            .single();

        // Siapkan array pre_service_docs
        List<Map<String, dynamic>> preServiceDocs = [];
        if (serviceData['pre_service_docs'] != null) {
          preServiceDocs =
              List<Map<String, dynamic>>.from(serviceData['pre_service_docs']);
        }

        // Buat dokumen baru dengan URL cloud
        Map<String, dynamic> newDoc = {
          'id': docId,
          'url': fileUrl,
          'type': type,
          'created_at': DateTime.now().toIso8601String(),
          'path': filePath,
          'is_cloud': true, // Tandai sebagai file cloud
        };

        // Jika video, buat thumbnail
        if (type == 'video') {
          try {
            // Gunakan thumbnail yang lebih bagus, bukan placeholder
            final thumbnailFile =
                await VideoCompress.getFileThumbnail(processedFile.path);
            // Video compress selalu mengembalikan File yang tidak null
            final thumbnailPath = '${filePath}_thumbnail.jpg';
            await supabase.storage.from('pre_service_docs').upload(
                  thumbnailPath,
                  thumbnailFile,
                  fileOptions: const FileOptions(
                    cacheControl: '3600',
                    upsert: true,
                  ),
                );
            newDoc['thumbnail_url'] = supabase.storage
                .from('pre_service_docs')
                .getPublicUrl(thumbnailPath);
          } catch (e) {
            print('Error generating thumbnail: $e');
            // Hapus placeholder, gunakan null untuk memicu fallback di UI
            newDoc['thumbnail_url'] = null;
          }
        }

        // Tambahkan dokumen baru ke array
        preServiceDocs.add(newDoc);

        // Update data service dengan array yang baru
        await supabase
            .from('services')
            .update({'pre_service_docs': preServiceDocs}).eq('id', serviceId);

        // Tampilkan notifikasi sukses
        _showSuccessMessage(context, type);

        // Trigger reload data service terbaru
        if (context.mounted) {
          await _refreshServiceData(context, serviceId);
        }

        return;
      } catch (uploadError) {
        print('Error uploading to storage: $uploadError');
        // Fallback ke base64 jika upload ke storage gagal

        // Baca file yang sudah dikompresi sebagai base64
        final bytes = await processedFile.readAsBytes();
        final base64File = base64Encode(bytes);

        // Buat ID unik untuk dokumen ini
        final docId = DateTime.now().millisecondsSinceEpoch.toString();

        // Generate URL dummy untuk preview
        final dummyUrl =
            'data:${type == 'image' ? 'image/jpeg' : 'video/mp4'};base64,$base64File';

        // Ambil data service saat ini
        final serviceData = await supabase
            .from('services')
            .select()
            .eq('id', serviceId)
            .single();

        // Siapkan array pre_service_docs
        List<Map<String, dynamic>> preServiceDocs = [];
        if (serviceData['pre_service_docs'] != null) {
          preServiceDocs =
              List<Map<String, dynamic>>.from(serviceData['pre_service_docs']);
        }

        // Buat dokumen baru dengan data base64
        Map<String, dynamic> newDoc = {
          'id': docId,
          'url': dummyUrl,
          'type': type,
          'created_at': DateTime.now().toIso8601String(),
          'file_data': base64File,
          'file_name': fileName,
          'is_local': true,
        };

        // Jika video, buat thumbnail dummy
        if (type == 'video') {
          // Hapus placeholder, gunakan null untuk memicu fallback di UI
          newDoc['thumbnail_url'] = null;
        }

        // Tambahkan dokumen baru ke array
        preServiceDocs.add(newDoc);

        // Update data service dengan array yang baru
        await supabase
            .from('services')
            .update({'pre_service_docs': preServiceDocs}).eq('id', serviceId);

        // Tampilkan notifikasi sukses
        _showSuccessMessage(context, type);

        // Trigger reload data service terbaru
        if (context.mounted) {
          await _refreshServiceData(context, serviceId);
        }
      }
    } catch (e) {
      print('Error saving media: $e');

      // Sembunyikan loading snackbar dan tampilkan error
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Gagal menyimpan: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // Nonaktifkan indikator loading global
      if (onUploadingDoc != null) {
        onUploadingDoc!(false);
      }

      // Sembunyikan loading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  // Helper untuk menampilkan pesan sukses
  void _showSuccessMessage(BuildContext context, String type) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('${type == 'image' ? 'Foto' : 'Video'} berhasil disimpan'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Metode untuk menampilkan dokumentasi lokal atau dari URL
  Widget _buildDocItem(BuildContext context, Map<String, dynamic> doc,
      {bool isReadOnly = false}) {
    final isVideo = doc['type'] == 'video';
    final isLocal = doc['is_local'] == true;

    Widget content;

    if (isLocal) {
      // Untuk file lokal, gunakan data base64
      if (isVideo) {
        content = GestureDetector(
          onTap: () => _showVideoPreviewDialog(context, doc['url']),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ganti placeholder dengan Container untuk video thumbnail
              doc['thumbnail_url'] != null &&
                      !doc['thumbnail_url']
                          .toString()
                          .contains('placeholder.com')
                  ? Image.network(
                      doc['thumbnail_url'],
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.movie,
                              size: 32,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.movie,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
              Icon(
                Icons.play_circle_fill,
                color: Colors.white.withAlpha(204),
                size: 36,
              ),
            ],
          ),
        );
      } else {
        // Untuk image, parse data base64
        final fileData = doc['file_data'];
        if (fileData != null) {
          content = GestureDetector(
            onTap: () => _showImagePreviewDialog(context, doc['url']),
            child: Image.memory(
              base64Decode(fileData),
              fit: BoxFit.cover,
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          content = Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 32,
                color: Colors.grey[600],
              ),
            ),
          );
        }
      }
    } else {
      // Untuk file online, gunakan URL
      if (isVideo) {
        content = GestureDetector(
          onTap: () => _showVideoPreviewDialog(context, doc['url']),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ganti placeholder dengan Container untuk video thumbnail
              doc['thumbnail_url'] != null &&
                      !doc['thumbnail_url']
                          .toString()
                          .contains('placeholder.com')
                  ? Image.network(
                      doc['thumbnail_url'],
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.movie,
                              size: 32,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.movie,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
              Icon(
                Icons.play_circle_fill,
                color: Colors.white.withAlpha(204),
                size: 36,
              ),
            ],
          ),
        );
      } else {
        content = GestureDetector(
          onTap: () => _showImagePreviewDialog(context, doc['url']),
          child: Image.network(
            doc['url'],
            fit: BoxFit.cover,
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 32,
                    color: Colors.grey[600],
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: content,
          ),
          // Tampilkan tombol hapus hanya jika tidak dalam mode read-only (COMPLETED)
          if (!isReadOnly)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => _confirmDeleteDoc(
                    context, service['id'].toString(), doc['id']),
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  // Metode untuk memeriksa ukuran file
  bool isFileSizeValid(File file, int maxSizeInBytes) {
    final fileSize = file.lengthSync();
    return fileSize <= maxSizeInBytes;
  }

  // Metode untuk memeriksa durasi video
  Future<bool> isVideoDurationValid(File videoFile) async {
    try {
      final videoInfo = await VideoCompress.getMediaInfo(videoFile.path);
      final duration = Duration(milliseconds: videoInfo.duration?.toInt() ?? 0);

      return duration <= MAX_VIDEO_DURATION;
    } catch (e) {
      print('Error memeriksa durasi video: $e');
      return false;
    }
  }

  void _showVideoPreviewDialog(BuildContext context, String videoUrl) {
    // Tampilkan dialog preview video
    docPreview.showDocumentationPreview(context, videoUrl, true);
  }

  void _showImagePreviewDialog(BuildContext context, String imageUrl) {
    // Tampilkan dialog preview gambar
    docPreview.showDocumentationPreview(context, imageUrl, false);
  }

  // Ambil foto dari kamera
  Future<void> _takePicture(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _handleImageUpload(context, imageFile, serviceId);
    }
  }

  // Pilih foto dari galeri
  Future<void> _pickImage(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      await _handleImageUpload(context, imageFile, serviceId);
    }
  }

  // Rekam video
  Future<void> _recordVideo(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: MAX_VIDEO_DURATION,
    );

    if (pickedFile != null) {
      final videoFile = File(pickedFile.path);
      await _handleVideoUpload(context, videoFile, serviceId);
    }
  }

  // Pilih video dari galeri
  Future<void> _pickVideo(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: MAX_VIDEO_DURATION,
    );

    if (pickedFile != null) {
      final videoFile = File(pickedFile.path);
      await _handleVideoUpload(context, videoFile, serviceId);
    }
  }

  // Metode yang diperbarui untuk reload data service dari Supabase
  Future<void> _refreshServiceData(
      BuildContext context, String serviceId) async {
    final supabase = Supabase.instance.client;
    // PENTING: Kita tidak akan menggunakan onUploadingDoc untuk refresh

    try {
      // Tampilkan SnackBar loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Memuat ulang data...'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Hapus cache Supabase terlebih dahulu
      await supabase.auth.refreshSession();

      // Mencoba mendapatkan data dengan query yang berbeda
      // dan parameter yang memaksa server memperbarui data
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      final serviceData = await supabase
          .from('services')
          .select('*, pre_service_docs')
          .eq('id', serviceId)
          .eq('cacheBuster', cacheBuster) // Parameter tambahan untuk bust cache
          .single();

      print(
          'Refresh berhasil: ${serviceData['pre_service_docs']?.length ?? 0} dokumen');

      // Sekarang kita perlu secara manual memaksa browser memuat ulang semua gambar
      // dengan menambahkan parameter cache buster ke URL gambar

      // Lakukan reload halaman (cara paling efektif)
      if (context.mounted) {
        // Call memanggil refresh global
        // Tapi pastikan refresh tidak menampilkan "Mengunggah dokumentasi"
        // Gunakan metode ini sebagai workaround
        Navigator.of(context).pop(); // Tutup dialog saat ini jika ada
        Future.delayed(Duration(milliseconds: 300), () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Data berhasil dimuat ulang. Silakan buka menu lagi.'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error refreshing service data: $e');

      // Tampilkan SnackBar error
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Gagal memperbarui data: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Metode untuk mendapatkan biaya tambahan dari database
  Future<List<Map<String, dynamic>>> _getAllAdditionalCosts(
      String serviceId) async {
    try {
      final supabase = Supabase.instance.client;
      final additionalCosts = await supabase
          .from('additional_costs')
          .select()
          .eq('service_id', serviceId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(additionalCosts);
    } catch (e) {
      print('Error fetching all additional costs: $e');
      return [];
    }
  }

  void _showAdditionalCostsDetail(
      BuildContext context, List<Map<String, dynamic>> additionalCosts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Detail Biaya Tambahan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var cost in additionalCosts)
                  Card(
                    margin: EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: cost['status'] == 'PAID'
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${cost['status'] == 'PAID' ? 'Dibayar' : 'Belum Dibayar'}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: cost['status'] == 'PAID'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                              Text(
                                currencyFormat.format(cost['amount'] ?? 0),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: cost['status'] == 'PAID'
                                      ? Colors.green[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          if (cost['created_at'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                'Tanggal: ${_formatDate(cost['created_at'])}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          if (cost['updated_at'] != null &&
                              cost['status'] == 'PAID')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                'Dibayar: ${_formatDate(cost['updated_at'])}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          SizedBox(height: 4),
                          Text(
                            'Catatan:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            cost['note'] ?? 'Tidak ada catatan',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method untuk format tanggal
  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('dd MMM yyyy, HH:mm');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }
}
