// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:servicehponline/features/user/widgets/mobile_map_picker_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _filteredServices = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  VideoPlayerController? _videoController;

  // Koordinat Service Center
  final serviceCenterPosition = Position(
    latitude: -6.151882179907883,
    longitude: 106.92619538817382,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _filterServices() {
    setState(() {
      _filteredServices = _services.where((service) {
        bool matchesSearch = true;
        bool matchesDate = true;

        // Filter berdasarkan pencarian nama
        if (_searchQuery.isNotEmpty) {
          final fullname = service['fullname']?.toString().toLowerCase() ?? '';
          matchesSearch = fullname.contains(_searchQuery.toLowerCase());
        }

        // Filter berdasarkan tanggal
        if (_startDate != null && _endDate != null) {
          final serviceDate = DateTime.parse(service['created_at']);
          matchesDate = serviceDate.isAfter(_startDate!) &&
              serviceDate.isBefore(_endDate!.add(Duration(days: 1)));
        }

        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Colors.blue,
            colorScheme: ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filterServices();
      });
    }
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final query = _supabase.from('services').select('''
        *,
        complaints(
          id,
          description,
          created_at,
          photo_url,
          video_url
        )
      ''');

      List<Map<String, dynamic>> data;
      if (_selectedFilter == 'pending') {
        // Menunggu Admin: status PENDING dan belum ada biaya service
        data = await query
            .eq('status', 'PENDING')
            .filter('service_cost', 'is', null)
            .order('created_at', ascending: false);
      } else if (_selectedFilter == 'waiting_payment') {
        // Belum Dibayar: status PENDING dan sudah ada biaya service
        data = await query
            .eq('status', 'PENDING')
            .not('service_cost', 'is', null)
            .order('created_at', ascending: false);
      } else if (_selectedFilter != 'all') {
        data = await query
            .eq('status', _selectedFilter.toUpperCase())
            .order('created_at', ascending: false);
      } else {
        data = await query.order('created_at', ascending: false);
      }

      setState(() {
        _services = List<Map<String, dynamic>>.from(data);
        _filteredServices = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      print('Error loading services: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data service'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar dari aplikasi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateServiceStatus(String serviceId, String newStatus) async {
    try {
      await _supabase.from('services').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', serviceId);

      _loadServices();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showUpdateCostDialog(Map<String, dynamic> service) async {
    final _costController = TextEditingController();
    bool _isSubmitting = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        title: Text(
          'Update Biaya Service',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _costController,
          keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
          decoration: InputDecoration(
            labelText: 'Biaya Service',
            prefixText: 'Rp ',
            border: OutlineInputBorder(),
                  hintText: '100000',
                ),
                onChanged: (value) {
                  // Optional: Format angka dengan pemisah ribuan
                  if (value.isNotEmpty) {
                    final number =
                        int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));
                    _costController.text = number.toString();
                    _costController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _costController.text.length),
                    );
                  }
                },
              ),
            ],
        ),
        actions: [
          TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: Text(
              'BATAL',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
            ),
          ),
          TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (_costController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Biaya service harus diisi'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);

                      try {
                        final cost = int.parse(_costController.text);
                await _supabase.from('services').update({
                  'service_cost': cost,
                  'updated_at': DateTime.now().toIso8601String(),
                        }).eq('id', service['id']);

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                            content: Text('Biaya service berhasil diupdate'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                        print('Error updating service cost: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                            content: Text('Gagal update biaya service'),
                    backgroundColor: Colors.red,
                  ),
                );
                      } finally {
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
              child: _isSubmitting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : Text(
              'SIMPAN',
                      style: GoogleFonts.poppins(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _showDocumentationPreview(String url, bool isVideo) async {
    if (isVideo) {
      showDialog(
      context: context,
        barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                Text(
                  'Mengunduh Video',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 16),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 16),
                Text(
                  'Mohon tunggu...',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        _videoController = VideoPlayerController.network(
          url,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

        await _videoController!.initialize();
        if (!mounted) return;
        Navigator.pop(context); // Tutup dialog loading

        setState(() {});

        // Tampilkan video setelah berhasil diinisialisasi
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                    color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_videoController!),
                          StatefulBuilder(
                            builder: (context, setState) => IconButton(
                                  icon: Icon(
                                    _videoController!.value.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                size: 64,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                    });
                                  },
                                ),
                                    ),
                                  ],
                                ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                      _videoController?.pause();
                      _videoController?.dispose();
                    Navigator.pop(context);
                  },
                  ),
                ),
              ],
            ),
          ),
        ).then((_) {
          _videoController?.pause();
          _videoController?.dispose();
          _videoController = null;
        });
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Tutup dialog loading jika terjadi error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat video'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error initializing video: $e');
        return;
      }
    } else {
      // Tampilkan gambar seperti biasa
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
          children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
            ),
          ],
        ),
      ),
    );
    }
  }

  Widget _buildDocumentationSection(Map<String, dynamic> service) {
    // Dokumentasi biasa dari service
    Map<String, List<Map<String, dynamic>>> serviceDocs = {
      'damage': [], // Foto Kerusakan
      'front': [], // Foto Tampak Depan
      'back': [], // Foto Tampak Belakang
      'video': [], // Video
    };

    // Kategorikan foto berdasarkan jenisnya
    if (service['picture_damage_url'] != null) {
      serviceDocs['damage']!.add(
          {'file_type': 'image', 'file_url': service['picture_damage_url']});
    }
    if (service['picture_front_url'] != null) {
      serviceDocs['front']!.add(
          {'file_type': 'image', 'file_url': service['picture_front_url']});
    }
    if (service['picture_back_url'] != null) {
      serviceDocs['back']!
          .add({'file_type': 'image', 'file_url': service['picture_back_url']});
    }
    if (service['video_url'] != null) {
      serviceDocs['video']!
          .add({'file_type': 'video', 'file_url': service['video_url']});
    }

    // Dokumentasi dari komplain
    List<Map<String, dynamic>> complaintDocs = [];
    final complaints = service['complaints'];
    if (complaints != null && complaints is List) {
      for (var complaint in complaints) {
        if (complaint['photo_url'] != null) {
          complaintDocs.add({
            'file_type': 'image',
            'file_url': complaint['photo_url'],
            'created_at': complaint['created_at']
          });
        }
        if (complaint['video_url'] != null) {
          complaintDocs.add({
            'file_type': 'video',
            'file_url': complaint['video_url'],
            'created_at': complaint['created_at']
          });
        }
      }
    }

    bool hasServiceDocs = serviceDocs.values.any((list) => list.isNotEmpty);
    if (!hasServiceDocs && complaintDocs.isEmpty) {
          return Text(
            'Belum ada dokumentasi',
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          );
        }

        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasServiceDocs) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                  'Dokumentasi Service',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
                if (serviceDocs['damage']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Kerusakan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
                  _buildDocumentationGrid(serviceDocs['damage']!),
                ],
                if (serviceDocs['front']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Tampak Depan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(serviceDocs['front']!),
                ],
                if (serviceDocs['back']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Tampak Belakang',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(serviceDocs['back']!),
                ],
                if (serviceDocs['video']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Video',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(serviceDocs['video']!),
                ],
              ],
            ),
          ),
        ],
        if (service['complain'] == true) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Komplain',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                if (complaints.isNotEmpty &&
                    complaints[0]['created_at'] != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatDate(complaints[0]['created_at']),
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                Text(
                  complaints.isNotEmpty && complaints[0]['description'] != null
                      ? complaints[0]['description']
                      : 'Tidak ada deskripsi komplain',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (complaintDocs.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Dokumentasi Komplain',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(complaintDocs),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentationGrid(List<Map<String, dynamic>> docs) {
    return GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isVideo = doc['file_type'] == 'video';
        final url = doc['file_url'];
        final createdAt = doc['created_at'];

                return InkWell(
          onTap: () => _showDocumentationPreview(url, isVideo),
                  child: Container(
                    decoration: BoxDecoration(
              color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
              image: !isVideo && url != null
                          ? DecorationImage(
                      image: NetworkImage(url),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isVideo)
                          Center(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black87,
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 48,
                              color: Colors.white,
                      ),
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isVideo ? 'Video' : 'Foto',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (createdAt != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> service) {
    if (service['shipping_method'] == 'antar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Service Center',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.0),
          MapPicker(
            initialPosition: serviceCenterPosition,
            onPositionChanged: (_) {},
            isInteractive: false,
          ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jl. Raya Kalimalang No.46, RT.7/RW.1, Duren Sawit, Kec. Duren Sawit, Kota Jakarta Timur, DKI Jakarta 13440',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
            ),
          ],
        );
    } else if (service['latitude'] != null && service['longitude'] != null) {
      final pickupPosition = Position(
        latitude: service['latitude'],
        longitude: service['longitude'],
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Penjemputan',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.0),
          MapPicker(
            initialPosition: pickupPosition,
            onPositionChanged: (_) {},
            isInteractive: false,
          ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Koordinat: ${service['latitude']}, ${service['longitude']}',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 12.0,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${service['latitude']},${service['longitude']}';
                  launchUrl(Uri.parse(url));
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Buka Maps',
                        style: GoogleFonts.poppins(
                          color: Colors.blue,
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
        ],
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    var status = service['status']?.toString().toUpperCase() ?? 'PENDING';
    final hasPayment = service['service_cost'] != null;
    final hasComplaint = (service['complaints'] ?? []).isNotEmpty;

    // Jika status PENDING dan sudah ada biaya service, tampilkan sebagai "Belum Dibayar"
    final displayStatus =
        (status == 'PENDING' && hasPayment) ? 'WAITING_PAYMENT' : status;

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
                    color: _getStatusColor(displayStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(displayStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        _getStatusText(displayStatus),
                style: GoogleFonts.poppins(
                          color: _getStatusColor(displayStatus),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
                    ],
            ),
                ),
                if (hasComplaint) ...[
            SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                ],
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
                  _formatDate(service['created_at']),
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
                _currencyFormat.format(service['service_cost']),
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
              _buildInfoSection(service),
              SizedBox(height: 24),
              _buildLocationSection(service),
              SizedBox(height: 24),
              _buildDocumentationSection(service),
              SizedBox(height: 24),
              _buildActionButtons(service),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> service) {
    return Container(
            padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            'Informasi Service',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
                _buildInfoRow('Nama', service['fullname']),
                _buildInfoRow('WhatsApp', service['whatsapp']),
                _buildInfoRow('Alamat', service['address']),
          _buildInfoRow('Masalah',
              DeviceProblems.getProblemName(service['problem'] ?? '')),
                _buildInfoRow('Deskripsi', service['description']),
                _buildInfoRow('Metode Pengiriman', service['shipping_method']),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> service) {
    return IntrinsicHeight(
      child: Row(
                  children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showUpdateCostDialog(service),
                icon: Icon(Icons.attach_money, color: Colors.white),
                      label: Text(
                        'Update Biaya',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _updateServiceStatus(service['id'].toString(), value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'PENDING',
                    child: _buildStatusMenuItem(
                      'Menunggu Admin',
                      Colors.orange,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'WAITING_PAYMENT',
                    child: _buildStatusMenuItem(
                      'Belum Dibayar',
                      Colors.orange,
                    ),
                        ),
                        PopupMenuItem(
                          value: 'PROCESSED',
                    child: _buildStatusMenuItem(
                      'Diproses',
                      Colors.blue,
                    ),
                        ),
                        PopupMenuItem(
                          value: 'COMPLETED',
                    child: _buildStatusMenuItem(
                      'Selesai',
                      Colors.green,
                        ),
                        ),
                        if (service['complain'] == true)
                          PopupMenuItem(
                            value: 'COMPLAINED',
                      child: _buildStatusMenuItem(
                              'Komplain',
                        Colors.red,
                            ),
                          ),
                      ],
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.update, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                          'Update Status',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMenuItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (label == 'WhatsApp') {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Flexible(
              child: Wrap(
                spacing: 8,
                children: [
                  Text(
                    value ?? '-',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                    ),
                  ),
                  if (value != null && value.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          final whatsappUrl =
                              'https://wa.me/${value.startsWith('0') ? '62${value.substring(1)}' : value}';
                          launchUrl(Uri.parse(whatsappUrl));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Chat',
                              style: GoogleFonts.poppins(
                                color: Colors.green,
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
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: GoogleFonts.poppins(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Admin';
      case 'WAITING_PAYMENT':
        return 'Belum Dibayar';
      case 'PROCESSED':
        return 'Diproses';
      case 'COMPLETED':
        return 'Selesai';
      case 'COMPLAINED':
        return 'Komplain';
      case 'EXPIRED':
        return 'Kadaluarsa';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'WAITING_PAYMENT':
        return Colors.orange;
      case 'PROCESSED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'COMPLAINED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Dashboard Admin',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.blue),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Konfirmasi',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'Apakah Anda yakin ingin keluar?',
                    style: GoogleFonts.poppins(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'BATAL',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                      child: Text(
                        'KELUAR',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan nama...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterServices();
                });
              },
            ),
          ),

          // Filter Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_startDate != null && _endDate != null)
                    Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Chip(
                        label: Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _filterServices();
                          });
                        },
                      ),
                    ),
                  Text(
                    'Filter:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 16),
                  ChoiceChip(
                    label: Text(
                      'Semua',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'all');
                        _loadServices();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Menunggu Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'pending',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'pending');
                        _loadServices();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Belum Dibayar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'waiting_payment',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'waiting_payment');
                        _loadServices();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Diproses',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'processed',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'processed');
                        _loadServices();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Selesai',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'completed',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'completed');
                        _loadServices();
                      }
                    },
                  ),
                  SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(
                      'Komplain',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'complained',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'complained');
                        _loadServices();
                      }
                    },
                    selectedColor: Colors.red[100],
                    labelStyle: GoogleFonts.poppins(
                      color: _selectedFilter == 'complained'
                          ? Colors.red
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Service List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : (_searchQuery.isEmpty && _startDate == null)
                    ? ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) =>
                            _buildServiceCard(_services[index]),
                      )
                    : _filteredServices.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada data yang sesuai',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredServices.length,
                            itemBuilder: (context, index) =>
                                _buildServiceCard(_filteredServices[index]),
                          ),
          ),
        ],
      ),
    );
  }
}
