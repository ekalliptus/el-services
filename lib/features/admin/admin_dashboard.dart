// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';

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
      final query = _supabase.from('services').select();

      final data = _selectedFilter != 'all'
          ? await query.match({'status': _selectedFilter.toUpperCase()}).order(
              'created_at')
          : await query.order('created_at');

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

  Future<void> _updateServiceCost(String serviceId) async {
    final costController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Update Biaya Service',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: costController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Biaya Service',
            prefixText: 'Rp ',
            border: OutlineInputBorder(),
          ),
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
            onPressed: () async {
              if (costController.text.isEmpty) return;

              try {
                final cost = int.parse(
                    costController.text.replaceAll(RegExp(r'[^0-9]'), ''));
                await _supabase.from('services').update({
                  'service_cost': cost,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', serviceId);

                if (!mounted) return;
                Navigator.pop(context);
                _loadServices();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Biaya service berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal memperbarui biaya service'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'SIMPAN',
              style: GoogleFonts.poppins(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDocumentationPreview(Map<String, dynamic> doc) async {
    final isVideo = doc['file_type'] == 'video';
    final url = doc['file_url'];

    if (isVideo) {
      _videoController = VideoPlayerController.network(url);
      await _videoController!.initialize();
    }

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isVideo
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_videoController!),
                                IconButton(
                                  icon: Icon(
                                    _videoController!.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _videoController!.value.isPlaying
                                          ? _videoController!.pause()
                                          : _videoController!.play();
                                    });
                                  },
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Gagal memuat gambar',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (isVideo) {
                      _videoController?.pause();
                      _videoController?.dispose();
                    }
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMap(Map<String, dynamic> service) {
    if (service['latitude'] == null || service['longitude'] == null)
      return SizedBox();

    final lat = double.parse(service['latitude'].toString());
    final lng = double.parse(service['longitude'].toString());

    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          mapController: MapController(),
          options: MapOptions(
            center: LatLng(lat, lng),
            zoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.servicehponline.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(lat, lng),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentationSection(String serviceId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabase
          .from('service_documentation')
          .select()
          .eq('service_id', serviceId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error memuat dokumentasi');
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
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
            Text(
              'Dokumentasi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isVideo = doc['file_type'] == 'video';

                return InkWell(
                  onTap: () => _showDocumentationPreview(doc),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      image: !isVideo && doc['file_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(doc['file_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isVideo)
                          Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 48,
                              color: Colors.white,
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final status = service['status']?.toString().toUpperCase() ?? 'PENDING';
    final hasPayment = service['service_cost'] != null;

    // Fungsi untuk mendapatkan status text yang sesuai
    String getDisplayStatus() {
      if (hasPayment && status == 'PENDING') {
        return 'Menunggu Pembayaran';
      }
      return _getStatusText(status);
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                getDisplayStatus(),
                style: GoogleFonts.poppins(
                  color: _getStatusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Service #${service['id']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            Text(
              '${service['brand']} - ${service['device']}',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
            if (hasPayment) ...[
              SizedBox(height: 4),
              Text(
                _currencyFormat.format(service['service_cost']),
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Nama', service['fullname']),
                _buildInfoRow('WhatsApp', service['whatsapp']),
                _buildInfoRow('Alamat', service['address']),
                _buildInfoRow('Masalah', service['problem']),
                _buildInfoRow('Deskripsi', service['description']),
                _buildInfoRow('Metode Pengiriman', service['shipping_method']),
                _buildInfoRow('Dibuat', _formatDate(service['created_at'])),

                SizedBox(height: 16),
                _buildLocationMap(service),
                SizedBox(height: 16),
                _buildDocumentationSection(service['id'].toString()),
                SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _updateServiceCost(service['id'].toString()),
                      icon: Icon(Icons.attach_money),
                      label: Text(
                        'Update Biaya',
                        style: GoogleFonts.poppins(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          _updateServiceStatus(service['id'].toString(), value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'PENDING',
                          child: Text('Pending'),
                        ),
                        PopupMenuItem(
                          value: 'PROCESSED',
                          child: Text('Diproses'),
                        ),
                        PopupMenuItem(
                          value: 'COMPLETED',
                          child: Text('Selesai'),
                        ),
                        PopupMenuItem(
                          value: 'PAID',
                          child: Text('Sudah Dibayar'),
                        ),
                        if (service['complain'] == true)
                          PopupMenuItem(
                            value: 'COMPLAINED',
                            child: Text(
                              'Komplain',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.update),
                        label: Text(
                          'Update Status',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'PAID':
        return Colors.green;
      case 'COMPLAINED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Admin';
      case 'PROCESSED':
        return 'Diproses';
      case 'COMPLETED':
        return 'Selesai';
      case 'PAID':
        return 'Sudah Dibayar';
      case 'COMPLAINED':
        return 'Komplain';
      case 'EXPIRED':
        return 'Kadaluarsa';
      default:
        return status;
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
                      'Pending',
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
                      'Sudah Dibayar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedFilter == 'paid',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = 'paid');
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
