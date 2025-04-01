import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/admin/widgets/service_card_widget.dart';
import 'package:servicehponline/features/admin/widgets/search_bar_widget.dart';
import 'package:servicehponline/features/admin/widgets/filter_widget.dart';
import 'package:servicehponline/features/admin/dialogs/update_cost_dialog.dart';
import 'dart:async';

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
  RealtimeChannel? _additionalCostsChannel;

  // Cache untuk data service
  Map<String, Map<String, dynamic>> _serviceCache = {};
  // Timer untuk polling background
  Timer? _pollingTimer;
  // Debounce timer untuk operasi yang sering dipanggil
  Timer? _debounceTimer;

  // Variable pagination
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Sorting
  String _sortField = 'created_at';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
    _loadServices();
    _loadFilterDates();
    _loadSortPreference();
    _subscribeToServiceChanges();
    _setupPollingUpdates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Batalkan semua subscription
    _servicesChannel.unsubscribe();
    _docsChannel?.unsubscribe();
    _complaintsChannel?.unsubscribe();
    _additionalCostsChannel?.unsubscribe();
    _pollingTimer?.cancel();
    _debounceTimer?.cancel();
    _supabase.removeAllChannels();
    super.dispose();
  }

  // Metode untuk setup polling update secara berkala
  void _setupPollingUpdates() {
    // Set interval polling (30 detik)
    _pollingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        print('Polling for dashboard updates');
        _refreshServicesInBackground();
      } else {
        // Batalkan timer jika widget tidak lagi mounted
        timer.cancel();
      }
    });
  }

  // Refresh service dalam background tanpa menampilkan loading indicator
  Future<void> _refreshServicesInBackground() async {
    if (!mounted) return;

    try {
      // Query dasar yang sama dengan _loadServices() tapi tanpa setState loading
      final query = _supabase.from('services').select('''
        id, 
        fullname, 
        phoneNumber, 
        status, 
        service_cost, 
        created_at, 
        updated_at, 
        device, 
        brand, 
        model, 
        problem,
        shipping_method,
        address,
        complain,
        user_id,
        complaints(
          id,
          description,
          created_at
        )
      ''');

      List<Map<String, dynamic>> data;
      // Gunakan filter yang sama dengan yang sedang aktif
      if (_selectedFilter == 'pending') {
        data = await query
            .eq('status', 'PENDING')
            .filter('service_cost', 'is', null)
            .order('created_at', ascending: false)
            .range(0, _pageSize - 1);
      } else if (_selectedFilter == 'unpaid') {
        final unpaidStatus = await query
            .eq('status', 'UNPAID')
            .order('created_at', ascending: false)
            .range(0, _pageSize - 1);

        int itemsLeft = _pageSize - unpaidStatus.length;
        List<Map<String, dynamic>> waitingPaymentStatus = [];
        List<Map<String, dynamic>> pendingWithCost = [];

        if (itemsLeft > 0) {
          waitingPaymentStatus = await query
              .eq('status', 'WAITING_PAYMENT')
              .order('created_at', ascending: false)
              .limit(itemsLeft);

          itemsLeft -= waitingPaymentStatus.length;
        }

        if (itemsLeft > 0) {
          pendingWithCost = await query
              .eq('status', 'PENDING')
              .not('service_cost', 'is', null)
              .order('created_at', ascending: false)
              .limit(itemsLeft);
        }

        data = [...unpaidStatus, ...waitingPaymentStatus, ...pendingWithCost];
      } else if (_selectedFilter != 'all') {
        data = await query
            .eq('status', _selectedFilter.toUpperCase())
            .order('created_at', ascending: false)
            .range(0, _pageSize - 1);
      } else {
        data = await query
            .order('created_at', ascending: false)
            .range(0, _pageSize - 1);
      }

      if (!mounted) return;

      final newServices = List<Map<String, dynamic>>.from(data);

      // Periksa apakah ada perubahan pada data
      bool hasChanges = false;

      if (newServices.length != _services.length) {
        hasChanges = true;
      } else {
        // Periksa perubahan pada data yang ada
        for (var i = 0; i < newServices.length; i++) {
          if (i >= _services.length ||
              newServices[i]['updated_at'] != _services[i]['updated_at'] ||
              newServices[i]['status'] != _services[i]['status'] ||
              newServices[i]['service_cost'] != _services[i]['service_cost']) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        print('Detected changes in dashboard services, updating UI silently');

        // Update cache
        for (var service in newServices) {
          _serviceCache[service['id'].toString()] = service;
        }

        setState(() {
          _services = newServices;
          // Terapkan filter pencarian jika ada
          if (_searchQuery.isNotEmpty) {
            _filterServices();
          } else {
            _filteredServices = List<Map<String, dynamic>>.from(newServices);
            _applySorting(); // Terapkan pengurutan
          }
        });
      }
    } catch (e) {
      print('Error refreshing services in background: $e');
    }
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

        // Jika ada ID service yang berubah, update spesifik service tersebut
        if (payload.newRecord['id'] != null) {
          final serviceId = payload.newRecord['id'].toString();
          _updateSpecificService(serviceId);
        } else {
          // Jika tidak ada ID spesifik, refresh semua data
          _loadServices();
        }
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
        // Cek apakah ada service_id yang dipengaruhi
        if (payload.newRecord['service_id'] != null) {
          final serviceId = payload.newRecord['service_id'].toString();
          _updateSpecificService(serviceId);
        } else {
          _loadServices();
        }
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
        // Cek apakah ada service_id yang dipengaruhi
        if (payload.newRecord['service_id'] != null) {
          final serviceId = payload.newRecord['service_id'].toString();
          _updateSpecificService(serviceId);
        } else {
          _loadServices();
        }
      },
    );
    _complaintsChannel?.subscribe();

    // Subscription untuk additional_costs
    _additionalCostsChannel = _supabase.channel('additional-costs-channel');
    _additionalCostsChannel = _additionalCostsChannel?.onPostgresChanges(
      schema: 'public',
      table: 'additional_costs',
      event: PostgresChangeEvent.all,
      callback: (payload) {
        print('Perubahan pada tabel additional_costs: ${payload.eventType}');
        // Cek apakah ada service_id yang dipengaruhi
        if (payload.newRecord['service_id'] != null) {
          final serviceId = payload.newRecord['service_id'].toString();
          _updateSpecificService(serviceId);
        } else {
          _loadServices();
        }
      },
    );
    _additionalCostsChannel?.subscribe();
  }

  // Metode untuk update specific service
  Future<void> _updateSpecificService(String serviceId) async {
    print('Updating specific service in admin dashboard with ID: $serviceId');

    try {
      // Cek apakah service ada dalam daftar yang ditampilkan
      final index = _services
          .indexWhere((service) => service['id'].toString() == serviceId);

      if (index == -1) {
        // Service tidak ada dalam daftar saat ini, perlu reload semua data
        // untuk memeriksa apakah sekarang seharusnya masuk dalam filter
        _loadServices();
        return;
      }

      // Fetch data service terbaru
      final updatedService = await _supabase.from('services').select('''
        id, 
        fullname, 
        phoneNumber, 
        status, 
        service_cost, 
        created_at, 
        updated_at, 
        device, 
        brand, 
        model, 
        problem,
        shipping_method,
        address,
        complain,
        user_id,
        complaints(
          id,
          description,
          created_at
        )
      ''').eq('id', serviceId).single();

      if (!mounted) return;

      // Update cache
      _serviceCache[serviceId] = updatedService;

      // Check jika service masih memenuhi filter saat ini
      bool meetsFilterCriteria = true;

      // Filter berdasarkan status
      if (_selectedFilter == 'pending') {
        meetsFilterCriteria = updatedService['status'] == 'PENDING' &&
            updatedService['service_cost'] == null;
      } else if (_selectedFilter == 'unpaid') {
        meetsFilterCriteria = updatedService['status'] == 'UNPAID' ||
            updatedService['status'] == 'WAITING_PAYMENT' ||
            (updatedService['status'] == 'PENDING' &&
                updatedService['service_cost'] != null);
      } else if (_selectedFilter != 'all') {
        meetsFilterCriteria =
            updatedService['status'] == _selectedFilter.toUpperCase();
      }

      setState(() {
        if (meetsFilterCriteria) {
          // Update service dalam daftar
          _services[index] = updatedService;

          // Update juga filteredServices jika perlu
          final filteredIndex = _filteredServices
              .indexWhere((service) => service['id'].toString() == serviceId);
          if (filteredIndex >= 0) {
            _filteredServices[filteredIndex] = updatedService;
          } else if (_searchQuery.isNotEmpty) {
            // Perlu memfilter ulang jika ada query pencarian
            _filterServices();
          } else {
            _filteredServices = List<Map<String, dynamic>>.from(_services);
          }

          // Terapkan sorting
          _applySorting();
        } else {
          // Service tidak lagi memenuhi filter, hapus dari daftar
          _services.removeAt(index);

          // Hapus juga dari filteredServices
          final filteredIndex = _filteredServices
              .indexWhere((service) => service['id'].toString() == serviceId);
          if (filteredIndex >= 0) {
            _filteredServices.removeAt(filteredIndex);
          }

          // Load service baru untuk mengisi slot yang kosong
          _loadServices();
        }
      });

      print(
          'Service with ID $serviceId updated successfully in admin dashboard');
    } catch (e) {
      print('Error updating specific service in admin dashboard: $e');
      // Jika gagal, reload semua data
      _loadServices();
    }
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
              service['phoneNumber']?.toString().toLowerCase().trim() ?? '';
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
            matchesSearch = searchKeywords.every(
              (keyword) =>
                  fullname.contains(keyword) ||
                  phone.contains(keyword) ||
                  model.contains(keyword) ||
                  brand.contains(keyword) ||
                  problem.contains(keyword) ||
                  serviceId.contains(keyword),
            );
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

      // Terapkan pengurutan setelah memfilter
      _applySorting();
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
    // Reset pagination
    _currentPage = 0;
    _hasMoreData = true;

    try {
      // Hanya ambil kolom yang diperlukan
      final query = _supabase.from('services').select('''
        id, 
        fullname, 
        phoneNumber, 
        status, 
        service_cost, 
        created_at, 
        updated_at, 
        device, 
        brand, 
        model, 
        problem,
        shipping_method,
        address,
        complain,
        user_id,
        complaints(
          id,
          description,
          created_at
        )
      ''');

      // Terapkan pagination
      List<Map<String, dynamic>> data;
      if (_selectedFilter == 'pending') {
        // Menunggu Admin: status PENDING dan belum ada biaya service
        data = await query
            .eq('status', 'PENDING')
            .filter('service_cost', 'is', null)
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      } else if (_selectedFilter == 'unpaid') {
        // Belum Dibayar: status UNPAID atau WAITING_PAYMENT
        final unpaidStatus = await query
            .eq('status', 'UNPAID')
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );

        // Hitung sisa items untuk pagination
        int itemsLeft = _pageSize - unpaidStatus.length;
        List<Map<String, dynamic>> waitingPaymentStatus = [];
        List<Map<String, dynamic>> pendingWithCost = [];

        if (itemsLeft > 0) {
          waitingPaymentStatus = await query
              .eq('status', 'WAITING_PAYMENT')
              .order('created_at', ascending: false)
              .limit(itemsLeft);

          // Update sisa items
          itemsLeft -= waitingPaymentStatus.length;
        }

        if (itemsLeft > 0) {
          pendingWithCost = await query
              .eq('status', 'PENDING')
              .not('service_cost', 'is', null)
              .order('created_at', ascending: false)
              .limit(itemsLeft);
        }

        // Gabungkan hasil
        data = [...unpaidStatus, ...waitingPaymentStatus, ...pendingWithCost];
      } else if (_selectedFilter != 'all') {
        data = await query
            .eq('status', _selectedFilter.toUpperCase())
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      } else {
        data = await query.order('created_at', ascending: false).range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      }

      // Cek apakah masih ada data selanjutnya
      _hasMoreData = data.length == _pageSize;
      _currentPage++;

      setState(() {
        _services = List<Map<String, dynamic>>.from(data);
        // Terapkan filter pencarian jika ada
        if (_searchQuery.isNotEmpty) {
          _filterServices();
        } else {
          _filteredServices = List<Map<String, dynamic>>.from(data);
          _applySorting(); // Terapkan pengurutan
        }
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

  // Fungsi untuk load more data (pagination)
  Future<void> _loadMoreServices() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      // Hanya ambil kolom yang diperlukan
      final query = _supabase.from('services').select('''
        id, 
        fullname, 
        phoneNumber, 
        status, 
        service_cost, 
        created_at, 
        updated_at, 
        device, 
        brand, 
        model, 
        problem,
        shipping_method,
        address,
        complain,
        user_id,
        complaints(
          id,
          description,
          created_at
        )
      ''');

      // Terapkan pagination
      List<Map<String, dynamic>> data;
      if (_selectedFilter == 'pending') {
        // Menunggu Admin: status PENDING dan belum ada biaya service
        data = await query
            .eq('status', 'PENDING')
            .filter('service_cost', 'is', null)
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      } else if (_selectedFilter == 'unpaid') {
        // Query pagination untuk unpaid serupa dengan _loadServices
        // Tapi kita mulai dari page yang berbeda
        final unpaidStatus = await query
            .eq('status', 'UNPAID')
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );

        int itemsLeft = _pageSize - unpaidStatus.length;
        List<Map<String, dynamic>> waitingPaymentStatus = [];
        List<Map<String, dynamic>> pendingWithCost = [];

        if (itemsLeft > 0) {
          waitingPaymentStatus = await query
              .eq('status', 'WAITING_PAYMENT')
              .order('created_at', ascending: false)
              .limit(itemsLeft);

          itemsLeft -= waitingPaymentStatus.length;
        }

        if (itemsLeft > 0) {
          pendingWithCost = await query
              .eq('status', 'PENDING')
              .not('service_cost', 'is', null)
              .order('created_at', ascending: false)
              .limit(itemsLeft);
        }

        data = [...unpaidStatus, ...waitingPaymentStatus, ...pendingWithCost];
      } else if (_selectedFilter != 'all') {
        data = await query
            .eq('status', _selectedFilter.toUpperCase())
            .order('created_at', ascending: false)
            .range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      } else {
        data = await query.order('created_at', ascending: false).range(
              _currentPage * _pageSize,
              (_currentPage + 1) * _pageSize - 1,
            );
      }

      // Cek apakah masih ada data selanjutnya
      _hasMoreData = data.length == _pageSize;
      _currentPage++;

      if (data.isNotEmpty) {
        setState(() {
          _services.addAll(data);
          // Terapkan filter pencarian jika ada
          if (_searchQuery.isNotEmpty) {
            _filterServices();
          } else {
            _filteredServices = List<Map<String, dynamic>>.from(_services);
          }
        });
      }
    } catch (e) {
      print('Error loading more services: $e');
    } finally {
      setState(() => _isLoadingMore = false);
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
                Text('Sedang keluar dari aplikasi...'),
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

      // Tentukan filter yang sesuai berdasarkan status baru
      String targetFilter;
      switch (newStatus.toUpperCase()) {
        case 'PENDING':
          targetFilter = 'pending';
          break;
        case 'PROCESSED':
          targetFilter = 'processed';
          break;
        case 'COMPLETED':
          targetFilter = 'completed';
          break;
        case 'UNPAID':
        case 'WAITING_PAYMENT':
          targetFilter = 'unpaid';
          break;
        case 'COMPLAINED':
          targetFilter = 'complained';
          break;
        default:
          targetFilter = 'all';
      }

      // Ubah filter saat ini ke filter yang sesuai dengan status baru
      setState(() {
        _selectedFilter = targetFilter;
      });

      // Muat ulang data dengan filter baru
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
    final status = service['status']?.toString().toUpperCase() ?? 'PENDING';
    final hasServiceCost = service['service_cost'] != null;

    String dialogTitle = 'Update Biaya Service';
    if (status == 'PENDING' && !hasServiceCost) {
      dialogTitle = 'Tetapkan Biaya';
    } else if (status == 'PROCESSED') {
      dialogTitle = 'Biaya Service Tambahan';
    }

    await showUpdateCostDialog(context, service, title: dialogTitle);

    // Selalu muat ulang daftar layanan setelah update
    _loadServices();

    // Setelah update biaya, pindahkan ke filter 'Belum dibayar'
    setState(() {
      _selectedFilter = 'unpaid';
    });
  }

  // Fungsi untuk menambahkan biaya tambahan
  Future<void> _showAdditionalCostDialog(Map<String, dynamic> service) async {
    TextEditingController additionalCostController = TextEditingController();
    TextEditingController noteController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Biaya Service Tambahan',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service #${service['id']}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${service['brand']} - ${service['model']}',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Biaya Service Sebelumnya:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(service['service_cost'] ?? 0),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Biaya Tambahan:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: additionalCostController,
                      decoration: InputDecoration(
                        labelText: 'Masukkan Biaya Tambahan',
                        prefixText: 'Rp ',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Catatan:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Alasan Biaya Tambahan',
                        hintText:
                            'Misalnya: kerusakan tambahan pada motherboard',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'BATAL',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          // Validasi input
                          if (additionalCostController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Biaya tambahan harus diisi'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (noteController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Catatan harus diisi'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            // Parse biaya tambahan
                            int additionalCost = int.tryParse(
                                  additionalCostController.text
                                      .replaceAll(RegExp(r'[^0-9]'), ''),
                                ) ??
                                0;

                            if (additionalCost <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Biaya tambahan harus lebih dari 0'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => isLoading = false);
                              return;
                            }

                            // Simpan biaya tambahan ke database
                            await _supabase.from('additional_costs').insert({
                              'service_id': service['id'],
                              'amount': additionalCost,
                              'note': noteController.text,
                              'created_at': DateTime.now().toIso8601String(),
                              'status': 'PENDING', // Belum dibayar
                            });

                            // Update status service ke UNPAID agar user harus membayar lagi
                            await _supabase.from('services').update({
                              'status': 'UNPAID',
                              'updated_at': DateTime.now().toIso8601String(),
                            }).eq('id', service['id']);

                            if (!context.mounted) return;

                            // Tutup dialog dan refresh data
                            Navigator.of(context).pop();
                            _loadServices();

                            // Pindahkan ke filter 'Belum dibayar'
                            setState(() {
                              _selectedFilter = 'unpaid';
                            });

                            // Tampilkan notifikasi sukses
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Biaya tambahan berhasil ditambahkan'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;

                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Gagal menambahkan biaya tambahan: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SIMPAN',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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

  // Handler untuk perubahan filter
  void _handleFilterChange(String value) {
    setState(() {
      _selectedFilter = value;
    });
    _loadServices();
  }

  // Handler untuk pencarian
  void _handleSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterServices();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

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

        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadServices,
              tooltip: 'Refresh Data',
            ),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.white, size: 22),
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
                        onChanged: _handleSearch,
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilterWidget(
                              selectedFilter: _selectedFilter,
                              onFilterChanged: _handleFilterChange,
                              startDate: _startDate,
                              endDate: _endDate,
                              onShowDateRangePicker: _showDateRangePicker,
                              onClearDateRange: _clearDateRange,
                            ),
                          ),
                          SizedBox(width: 8),
                          _buildSortButton(),
                        ],
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
                              child: NotificationListener<ScrollNotification>(
                                onNotification:
                                    (ScrollNotification scrollInfo) {
                                  if (scrollInfo.metrics.pixels ==
                                          scrollInfo.metrics.maxScrollExtent &&
                                      _hasMoreData) {
                                    _loadMoreServices();
                                  }
                                  return true;
                                },
                                child: ListView.builder(
                                  padding: EdgeInsets.all(16),
                                  itemCount: _filteredServices.length +
                                      (_hasMoreData ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _filteredServices.length) {
                                      return _isLoadingMore
                                          ? Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            )
                                          : SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: _buildServiceItem(
                                        _filteredServices[index],
                                        context,
                                      ),
                                    );
                                  },
                                ),
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
      onAdditionalCost: _showAdditionalCostDialog,
      currencyFormat: _currencyFormat,
      onUploadingDoc: (isLoading, {String action = 'upload'}) {
        _setDocumentationLoading(isLoading, action: action);
      },
    );
  }

  // Fungsi untuk membuat tombol sorting
  Widget _buildSortButton() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.sort, color: Colors.blue),
      tooltip: 'Urutkan Data',
      onSelected: (value) {
        // Jika field yang sama dipilih, balik arah sorting
        if (_sortField == value) {
          setState(() {
            _sortAscending = !_sortAscending;
          });
        } else {
          // Jika field berbeda, atur field baru dan reset arah sort
          setState(() {
            _sortField = value;
            _sortAscending = false; // Default descending (terbaru)
          });
        }
        _saveSortPreference(); // Simpan preferensi
        _applySorting(); // Terapkan urutan baru
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(
            'created_at', 'Tanggal Dibuat', _sortField == 'created_at'),
        _buildSortMenuItem(
            'updated_at', 'Terakhir Diupdate', _sortField == 'updated_at'),
        _buildSortMenuItem(
            'fullname', 'Nama Pelanggan', _sortField == 'fullname'),
        _buildSortMenuItem(
            'service_cost', 'Biaya Service', _sortField == 'service_cost'),
        _buildSortMenuItem(
            'brand_model', 'Brand & Model', _sortField == 'brand_model'),
      ],
    );
  }

  // Fungsi untuk membuat menu item sorting
  PopupMenuItem<String> _buildSortMenuItem(
      String value, String text, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(text),
          if (isSelected) ...[
            Spacer(),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  // Metode untuk menyimpan preferensi sorting
  Future<void> _saveSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_sort_field', _sortField);
    await prefs.setBool('admin_sort_ascending', _sortAscending);
  }

  // Metode untuk memuat preferensi sorting
  Future<void> _loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortField = prefs.getString('admin_sort_field');
      final sortAscending = prefs.getBool('admin_sort_ascending');

      if (sortField != null) {
        setState(() {
          _sortField = sortField;
        });
      }

      if (sortAscending != null) {
        setState(() {
          _sortAscending = sortAscending;
        });
      }
    } catch (e) {
      print('Error loading sort preference: $e');
    }
  }

  // Metode untuk menerapkan sort pada daftar service
  void _applySorting() {
    setState(() {
      _filteredServices.sort((a, b) {
        if (_sortField == 'fullname') {
          String nameA = a['fullname']?.toString().toLowerCase() ?? '';
          String nameB = b['fullname']?.toString().toLowerCase() ?? '';
          return _sortAscending
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);
        } else if (_sortField == 'updated_at') {
          String dateA = a['updated_at'] ?? '';
          String dateB = b['updated_at'] ?? '';
          return _sortAscending
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
        } else if (_sortField == 'service_cost') {
          int costA = a['service_cost'] ?? 0;
          int costB = b['service_cost'] ?? 0;
          return _sortAscending
              ? costA.compareTo(costB)
              : costB.compareTo(costA);
        } else if (_sortField == 'brand_model') {
          String brandModelA = '${a['brand']} ${a['model']}'.toLowerCase();
          String brandModelB = '${b['brand']} ${b['model']}'.toLowerCase();
          return _sortAscending
              ? brandModelA.compareTo(brandModelB)
              : brandModelB.compareTo(brandModelA);
        } else {
          // Default: sort by created_at
          String dateA = a['created_at'] ?? '';
          String dateB = b['created_at'] ?? '';
          return _sortAscending
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
        }
      });
    });
  }
}
