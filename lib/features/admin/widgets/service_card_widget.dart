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
import 'package:path/path.dart' as path;

class ServiceCardWidget extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(String, String) onUpdateStatus;
  final Function(Map<String, dynamic>) onUpdateCost;
  final NumberFormat currencyFormat;

  const ServiceCardWidget({
    Key? key,
    required this.service,
    required this.onUpdateStatus,
    required this.onUpdateCost,
    required this.currencyFormat,
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

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasComplaint ? Colors.red.withOpacity(0.3) : Colors.grey[200]!,
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
                    color: StatusUtils.getStatusColor(displayStatus)
                        .withOpacity(0.1),
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
                        color: Colors.red.withOpacity(0.1),
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
              Text(
                currencyFormat.format(service['service_cost']),
                style: GoogleFonts.poppins(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
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

              // Bagian dokumentasi foto dan video sebelum service
              _buildPreServiceDocSection(context, service),
              SizedBox(height: 24),

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
    final address = service['address_note'] ?? '-';
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

        // Alamat
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan Alamat',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    address,
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
      BuildContext context, Map<String, dynamic> service) {
    final serviceId = service['id'].toString();
    final hasPreServiceDocs = service['pre_service_docs'] != null &&
        (service['pre_service_docs'] as List).isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dokumentasi Kondisi Awal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showDocumentationOptions(context, serviceId),
              icon: Icon(Icons.add_a_photo, size: 16),
              label: Text('Tambah'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (!hasPreServiceDocs)
          Center(
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
          )
        else
          _buildPreServiceDocList(context, service),
      ],
    );
  }

  // Widget untuk menampilkan daftar dokumentasi sebelum service
  Widget _buildPreServiceDocList(
      BuildContext context, Map<String, dynamic> service) {
    final preServiceDocs = service['pre_service_docs'] as List;

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: preServiceDocs.length,
        itemBuilder: (context, index) {
          final doc = preServiceDocs[index];
          final isVideo = doc['type'] == 'video';

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
                  child: isVideo
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              doc['thumbnail_url'] ??
                                  'https://via.placeholder.com/120',
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                            ),
                            Icon(
                              Icons.play_circle_fill,
                              color: Colors.white.withOpacity(0.8),
                              size: 36,
                            ),
                          ],
                        )
                      : Image.network(
                          doc['url'],
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () => _confirmDeleteDoc(
                        context, service['id'].toString(), doc['id']),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
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

    try {
      // Hapus file dari storage
      await supabase.storage
          .from('pre_service_docs')
          .remove(['$serviceId/$docId']);

      // Update data service
      final service =
          await supabase.from('services').select().eq('id', serviceId).single();
      final docs = (service['pre_service_docs'] as List?)
              ?.where((doc) => doc['id'] != docId)
              .toList() ??
          [];

      await supabase.from('services').update({
        'pre_service_docs': docs,
      }).eq('id', serviceId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dokumentasi berhasil dihapus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus dokumentasi: $e')),
      );
    }
  }

  // Tampilkan opsi untuk menambah foto atau video
  void _showDocumentationOptions(BuildContext context, String serviceId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
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

  // Ambil foto dari kamera
  Future<void> _takePicture(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      _uploadMedia(context, File(pickedFile.path), serviceId, 'image');
    }
  }

  // Pilih foto dari galeri
  Future<void> _pickImage(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _uploadMedia(context, File(pickedFile.path), serviceId, 'image');
    }
  }

  // Rekam video
  Future<void> _recordVideo(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.camera);

    if (pickedFile != null) {
      _uploadMedia(context, File(pickedFile.path), serviceId, 'video');
    }
  }

  // Pilih video dari galeri
  Future<void> _pickVideo(BuildContext context, String serviceId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      _uploadMedia(context, File(pickedFile.path), serviceId, 'video');
    }
  }

  // Upload media (foto/video) ke storage
  Future<void> _uploadMedia(
      BuildContext context, File file, String serviceId, String type) async {
    final supabase = Supabase.instance.client;
    final docId = DateTime.now().millisecondsSinceEpoch.toString();
    final fileExt = path.extension(file.path);
    final fileName = '$docId$fileExt';
    final filePath = '$serviceId/$fileName';

    try {
      // Upload file ke storage
      await supabase.storage.from('pre_service_docs').upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // Dapatkan URL public
      final fileUrl =
          supabase.storage.from('pre_service_docs').getPublicUrl(filePath);

      // Buat data dokumen
      final docData = {
        'id': docId,
        'url': fileUrl,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Jika video, tambahkan thumbnail
      if (type == 'video') {
        // Di sini bisa ditambahkan logika untuk membuat thumbnail dari video
        // Untuk sekarang, gunakan placeholder
        docData['thumbnail_url'] = 'https://img.youtube.com/vi/default/0.jpg';
      }

      // Update data service
      final service =
          await supabase.from('services').select().eq('id', serviceId).single();
      final docs = (service['pre_service_docs'] as List?) ?? [];
      docs.add(docData);

      await supabase.from('services').update({
        'pre_service_docs': docs,
      }).eq('id', serviceId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dokumentasi berhasil ditambahkan')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menambahkan dokumentasi: $e')),
      );
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }
}
