import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:servicehponline/core/services/authentication.dart';
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

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filterServices();
    });
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

      // Gunakan service Authentication untuk logout
      final authService = Authentication();
      await authService.signOut();

      // Pastikan juga logout dari Supabase, karena admin menggunakan Supabase
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

  Future<void> _handleUpdateCost(Map<String, dynamic> service) async {
    await showUpdateCostDialog(context, service);
    _loadServices();
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
          SearchBarWidget(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterServices();
              });
            },
          ),

          // Filter Section
          FilterWidget(
            selectedFilter: _selectedFilter,
            startDate: _startDate,
            endDate: _endDate,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
              _loadServices();
            },
            onShowDateRangePicker: _showDateRangePicker,
            onClearDateRange: _clearDateRange,
          ),

          // Service List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : (_searchQuery.isEmpty && _startDate == null)
                    ? ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _services.length,
                        itemBuilder: (context, index) => ServiceCardWidget(
                          service: _services[index],
                          onUpdateStatus: _updateServiceStatus,
                          onUpdateCost: _handleUpdateCost,
                          currencyFormat: _currencyFormat,
                        ),
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
                            itemBuilder: (context, index) => ServiceCardWidget(
                              service: _filteredServices[index],
                              onUpdateStatus: _updateServiceStatus,
                              onUpdateCost: _handleUpdateCost,
                              currencyFormat: _currencyFormat,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
