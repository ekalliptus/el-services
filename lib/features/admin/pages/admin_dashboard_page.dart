import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/admin/widgets/service_card_widget.dart';
import 'package:servicehponline/features/admin/widgets/search_bar_widget.dart';
import 'package:servicehponline/features/admin/widgets/filter_widget.dart';
import 'package:servicehponline/features/admin/dialogs/update_cost_dialog.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isUploadingDoc = false; // Status upload dokumentasi
  String _documentationActionText = 'Mengunggah dokumentasi...';
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
  // Subscription untuk real-time update
  late RealtimeChannel _servicesChannel;
  RealtimeChannel? _docsChannel;
  RealtimeChannel? _complaintsChannel;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _loadServices();
    _loadFilterDates();
    _subscribeToServiceChanges();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Batalkan semua subscription
    _servicesChannel.unsubscribe();
    _docsChannel?.unsubscribe();
    _complaintsChannel?.unsubscribe();
    super.dispose();
  }

  // Metode untuk berlangganan perubahan data service secara real-time
  void _subscribeToServiceChanges() {
    // Buat channel untuk tabel services
    _servicesChannel = _supabase.channel('services-channel');
    _servicesChannel = _servicesChannel.onPostgresChanges(
      schema: 'public',
      table: 'services',
      event: PostgresChangeEvent.all,
      callback: (payload) {
        print('Perubahan pada tabel services: ${payload.eventType}');
        _loadServices();
      },
    );
    _servicesChannel.subscribe();

    // Subscription untuk tabel service_docs
    _docsChannel = _supabase.channel('service-docs-channel');
    _docsChannel = _docsChannel?.onPostgresChanges(
      schema: 'public',
      table: 'service_docs',
      event: PostgresChangeEvent.all,
      callback: (payload) {
        print('Perubahan pada tabel service_docs: ${payload.eventType}');
        _loadServices();
      },
    );
    _docsChannel?.subscribe();

    // Subscription untuk tabel complaints
    _complaintsChannel = _supabase.channel('complaints-channel');
    _complaintsChannel = _complaintsChannel?.onPostgresChanges(
      schema: 'public',
      table: 'complaints',
      event: PostgresChangeEvent.all,
      callback: (payload) {
        print('Perubahan pada tabel complaints: ${payload.eventType}');
        _loadServices();
      },
    );
    _complaintsChannel?.subscribe();
  }

  void _filterServices() {
    setState(() {
      _filteredServices = _services.where((service) {
        bool matchesSearch = true;
        bool matchesDate = true;

        // Filter berdasarkan pencarian yang ditingkatkan
        if (_searchQuery.isNotEmpty) {
          // Normalisasi query pencarian
          final searchLower = _searchQuery.toLowerCase().trim();

          // Split query menjadi kata kunci terpisah untuk pencarian lebih akurat
          final searchKeywords = searchLower
              .split(' ')
              .where((keyword) => keyword.isNotEmpty)
              .toList();

          // Normalisasi field pencarian
          final fullname =
              service['fullname']?.toString().toLowerCase().trim() ?? '';
          final phone =
              service['phone_number']?.toString().toLowerCase().trim() ?? '';
          final model = service['model']?.toString().toLowerCase().trim() ?? '';
          final brand = service['brand']?.toString().toLowerCase().trim() ?? '';
          final problem =
              service['problem']?.toString().toLowerCase().trim() ?? '';
          final serviceId =
              service['id']?.toString().toLowerCase().trim() ?? '';

          // Gabungkan semua field pencarian untuk pencocokan menyeluruh
          final allFields =
              '$fullname $phone $model $brand $problem $serviceId';

          // Pencarian berdasarkan keyword terpisah
          if (searchKeywords.length > 1) {
            // Pencarian multi-keyword - semua keyword harus ada
            matchesSearch = searchKeywords.every((keyword) =>
                fullname.contains(keyword) ||
                phone.contains(keyword) ||
                model.contains(keyword) ||
                brand.contains(keyword) ||
                problem.contains(keyword) ||
                serviceId.contains(keyword));
          } else {
            // Pencarian single-keyword
            matchesSearch = allFields.contains(searchLower);
          }
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
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
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

      // Simpan filter tanggal
      _saveFilterDates(picked.start, picked.end);
    }
  }

  // Fungsi untuk menyimpan filter tanggal
  Future<void> _saveFilterDates(DateTime start, DateTime end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_filter_start_date', start.toIso8601String());
    await prefs.setString('admin_filter_end_date', end.toIso8601String());
  }

  // Fungsi untuk memuat filter tanggal
  Future<void> _loadFilterDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startDateStr = prefs.getString('admin_filter_start_date');
      final endDateStr = prefs.getString('admin_filter_end_date');

      if (startDateStr != null && endDateStr != null) {
        setState(() {
          _startDate = DateTime.parse(startDateStr);
          _endDate = DateTime.parse(endDateStr);
        });
        _filterServices();
      }
    } catch (e) {
      print('Error loading filter dates: $e');
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filterServices();
    });

    // Hapus filter tanggal dari SharedPreferences
    _clearSavedFilterDates();
  }

  // Fungsi untuk menghapus filter tanggal tersimpan
  Future<void> _clearSavedFilterDates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_filter_start_date');
    await prefs.remove('admin_filter_end_date');
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

  Future<void> _checkSession() async {
    try {
      final session = await _supabase.auth.currentSession;
      if (session == null) {
        // Tidak ada sesi aktif, kembali ke halaman login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      // Verifikasi bahwa user masih admin
      final adminCheck = await _supabase
          .from('admins')
          .select('*')
          .eq('id', session.user.id)
          .maybeSingle();

      if (adminCheck == null || adminCheck['role'] != 'admin') {
        // Bukan admin lagi, logout
        await _handleLogout();
      }
    } catch (e) {
      print('Error checking session: $e');
      // Jika ada error, amannya logout
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    try {
      // Tampilkan loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sedang keluar dari aplikasi...')
              ],
            ),
          );
        },
      );

      // Hapus sesi admin dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_logged_in');
      await prefs.remove('admin_session');
      print('Admin session cleared from SharedPreferences');

      // Pastikan juga logout dari Supabase
      await _supabase.auth.signOut();

      if (!mounted) return;

      // Tutup dialog loading
      Navigator.of(context).pop();

      // Kembali ke halaman login
      Navigator.of(context).pushReplacementNamed('/');
    } catch (e) {
      print('Error during admin logout: $e');
      if (!mounted) return;

      // Tutup dialog loading jika masih terbuka
      try {
        Navigator.of(context).pop();
      } catch (e) {
        // Dialog mungkin sudah ditutup
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal keluar dari aplikasi: ${e.toString()}'),
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
    await showUpdateCostDialog(context, service);
    _loadServices();
  }

  // Tambahkan setter untuk status upload dokumentasi
  void setUploadingDoc(bool status) {
    setState(() {
      _isUploadingDoc = status;
    });
  }

  // Update status loading dokumentasi dan teksnya
  void _setDocumentationLoading(bool isLoading, {String action = 'upload'}) {
    setState(() {
      _isUploadingDoc = isLoading;
      if (action == 'delete') {
        _documentationActionText = 'Menghapus dokumentasi...';
      } else {
        _documentationActionText = 'Mengunggah dokumentasi...';
      }
    });
  }

  // Fungsi untuk logout
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi'),
        content: Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            child: Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).userGestureInProgress) {
          return false;
        }
        final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Konfirmasi'),
                content: Text('Yakin ingin keluar dari halaman admin?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Tidak'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Ya'),
                  ),
                ],
              ),
            ) ??
            false;
        return shouldPop;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: Colors.black,
                size: 22,
              ),
              onPressed: _loadServices,
              tooltip: 'Refresh Data',
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: Colors.black,
                size: 22,
              ),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // Search dan Filter
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SearchBarWidget(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                            _filterServices();
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      FilterWidget(
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (value) {
                          setState(() {
                            _selectedFilter = value;
                            _loadServices();
                          });
                        },
                        startDate: _startDate,
                        endDate: _endDate,
                        onShowDateRangePicker: _showDateRangePicker,
                        onClearDateRange: _clearDateRange,
                      ),
                    ],
                  ),
                ),

                // Daftar service
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _filteredServices.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada data service',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadServices,
                              child: ListView.builder(
                                padding: EdgeInsets.all(16),
                                itemCount: _filteredServices.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: _buildServiceItem(
                                        _filteredServices[index], context),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
            // Indikator loading untuk upload dokumentasi
            if (_isUploadingDoc)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        _documentationActionText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(Map<String, dynamic> service, BuildContext context) {
    return ServiceCardWidget(
      service: service,
      onUpdateStatus: _updateServiceStatus,
      onUpdateCost: _showUpdateCostDialog,
      currencyFormat: _currencyFormat,
      onUploadingDoc: (isLoading, {String action = 'upload'}) {
        _setDocumentationLoading(isLoading, action: action);
      },
    );
  }
}
