// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:servicehponline/features/user/widgets/mobile_map_picker_widget.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:servicehponline/core/services/payment_service.dart';
import 'package:servicehponline/features/user/pages/payment_webview_page.dart';
import 'package:servicehponline/features/testimonial/widgets/testimonial_history_widget.dart';
import 'package:servicehponline/features/complaint/pages/complaint_page.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:provider/provider.dart';
import 'package:servicehponline/core/services/realtime_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({Key? key}) : super(key: key);

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final _supabase = Supabase.instance.client;
  final _firebaseAuth = firebase.FirebaseAuth.instance;
  final _paymentService = PaymentService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  Map<String, bool> _expandedCards = {};
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  StreamSubscription? _realtimeSubscription;

  // Cache untuk data service
  Map<String, Map<String, dynamic>> _serviceCache = {};
  // Tambahkan timer untuk debounce
  Timer? _debounceTimer;
  // Timer polling & channel realtime — disimpan agar bisa dibatalkan di dispose
  Timer? _pollTimer;
  RealtimeChannel? _serviceChannel;

  // Cache future per-service agar FutureBuilder tidak membuat query baru
  // (dan reset ke loading) setiap kali build dipanggil.
  final Map<String, Future<Map<String, dynamic>?>> _testimonialFutures = {};
  final Map<String, Future<Map<String, dynamic>?>> _additionalCostFutures = {};
  final Map<String, Future<List<Map<String, dynamic>>>> _additionalCostsFutures =
      {};

  Future<Map<String, dynamic>?> _testimonialFutureFor(String serviceId) {
    return _testimonialFutures.putIfAbsent(
      serviceId,
      () => _supabase
          .from('testimonials')
          .select()
          .eq('service_id', serviceId)
          .maybeSingle(),
    );
  }

  Future<Map<String, dynamic>?> _additionalCostFutureFor(String serviceId) {
    return _additionalCostFutures.putIfAbsent(
      serviceId,
      () => _getAdditionalCost(serviceId),
    );
  }

  Future<List<Map<String, dynamic>>> _additionalCostsFutureFor(
      String serviceId) {
    return _additionalCostsFutures.putIfAbsent(
      serviceId,
      () => _getAdditionalCosts(serviceId),
    );
  }

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

  // Variabel pagination
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Kolom yang akan diambil dalam query
  final List<String> _requiredColumns = [
    'id',
    'service_cost',
    'status',
    'device',
    'brand',
    'model',
    'problem',
    'created_at',
    'updated_at',
    'complain',
    'device_password',
    'device_password_type',
    'shipping_method',
    'latitude',
    'longitude',
    'address_note'
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return;

    // Subscribe ke perubahan services
    _realtimeSubscription =
        context.read<RealtimeService>().stream.listen((event) {
      if (event['type'] == 'service_update') {
        print('Received service update: ${event['data']}');

        // Jika ada ID layanan yang diperbarui, update hanya item tersebut
        if (event['data'] != null && event['data']['id'] != null) {
          _updateSpecificService(event['data']['id'].toString());
        } else {
          // Jika tidak ada ID spesifik, refresh semua data
          _loadServices();
        }
      } else if (event['type'] == 'additional_cost_update') {
        // Khusus untuk update biaya tambahan
        if (event['data'] != null && event['data']['service_id'] != null) {
          _updateSpecificService(event['data']['service_id'].toString());
        }
      }
    });

    // Setup direct Supabase channel subscription
    final serviceChannel = _supabase.channel('service_changes');
    _serviceChannel = serviceChannel;

    // Subscribe ke perubahan tabel services
    serviceChannel.subscribe((status, error) {
      if (status == 'SUBSCRIBED') {
        print('Successfully subscribed to service changes channel');
      } else {
        print('Failed to subscribe to service changes: $status, $error');
      }
    });

    // Set up timer untuk polling updates dalam interval tertentu
    // (solusi alternatif yang lebih andal daripada mengandalkan realtime saja).
    // Disimpan ke _pollTimer agar dibatalkan tepat waktu di dispose.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        print('Polling for service updates');
        _refreshServicesInBackground();
      } else {
        // Batalkan timer jika widget sudah tidak mounted
        timer.cancel();
      }
    });

    print('Realtime subscription setup completed for user: ${currentUser.uid}');
  }

  // Refresh service dalam background tanpa menampilkan loading indicator
  Future<void> _refreshServicesInBackground() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('services')
          .select(_getRequiredColumns())
          .eq('user_id', user.uid)
          .order('created_at', ascending: false)
          .limit(_services.length > 0 ? _services.length : _pageSize);

      if (!mounted) return;

      final newServices = List<Map<String, dynamic>>.from(response);

      // Perbarui cache dan update daftar jika ada perubahan
      bool hasChanges = false;

      if (newServices.length != _services.length) {
        hasChanges = true;
      } else {
        // Periksa apakah ada perubahan data
        for (var i = 0; i < newServices.length; i++) {
          if (i >= _services.length ||
              newServices[i]['updated_at'] != _services[i]['updated_at'] ||
              newServices[i]['status'] != _services[i]['status']) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        print('Detected changes in services, updating UI');
        // Update cache
        for (var service in newServices) {
          _serviceCache[service['id'].toString()] = service;
        }

        setState(() {
          _services = newServices;
        });
      }
    } catch (e) {
      print('Error refreshing services in background: $e');
    }
  }

  // Periksa apakah service dengan ID tertentu ada dalam daftar
  bool _isServiceInList(String serviceId) {
    return _services.any((service) => service['id'].toString() == serviceId);
  }

  // Metode untuk mendapatkan kolom yang diperlukan
  String _getRequiredColumns() {
    return _requiredColumns.join(', ');
  }

  // Update layanan spesifik tanpa memperbarui seluruh daftar
  Future<void> _updateSpecificService(String serviceId) async {
    print('Updating specific service with ID: $serviceId');

    // Cek apakah service dalam daftar
    if (!_isServiceInList(serviceId)) {
      print('Service not in current list, reloading all data');
      _loadServices();
      return;
    }

    try {
      // Fetch data terbaru untuk service tersebut
      final updatedService = await _supabase
          .from('services')
          .select(_getRequiredColumns())
          .eq('id', serviceId)
          .single();

      if (!mounted) return;

      setState(() {
        // Perbarui layanan dalam daftar
        final index = _services
            .indexWhere((service) => service['id'].toString() == serviceId);
        if (index >= 0) {
          _services[index] = updatedService;

          // Update juga cache
          _serviceCache[serviceId] = updatedService;
        }
      });

      print('Service with ID $serviceId updated successfully');
    } catch (e) {
      print('Error updating specific service: $e');
    }
  }

  Future<void> _loadServices() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    // Reset pagination
    _currentPage = 0;
    _hasMoreData = true;
    // Reset cache future per-service agar refresh menampilkan data terbaru
    _testimonialFutures.clear();
    _additionalCostFutures.clear();
    _additionalCostsFutures.clear();

    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Hanya ambil kolom yang diperlukan
      final response = await _supabase
          .from('services')
          .select(_getRequiredColumns())
          .eq('user_id', user.uid)
          .order('created_at', ascending: false)
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1)
          .limit(_pageSize);

      // Cek apakah masih ada data selanjutnya
      _hasMoreData = response.length == _pageSize;
      _currentPage++;

      if (!mounted) return;

      final services = List<Map<String, dynamic>>.from(response);

      // Update cache
      for (var service in services) {
        _serviceCache[service['id'].toString()] = service;
      }

      setState(() {
        _services = services;
        _isLoading = false;
      });

      print('Loaded services: ${_services.length}'); // Debug print
    } catch (e) {
      print('Error loading services: $e');
      if (!mounted) return;

      setState(() {
        _services = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat riwayat service: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi untuk load more data (pagination) dengan debounce
  Future<void> _loadMoreServices() async {
    if (!_hasMoreData || _isLoadingMore || !mounted) return;

    // Batalkan timer debounce sebelumnya
    _debounceTimer?.cancel();

    // Atur timer debounce baru
    _debounceTimer = Timer(Duration(milliseconds: 300), () async {
      setState(() => _isLoadingMore = true);

      try {
        final user = _firebaseAuth.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        final response = await _supabase
            .from('services')
            .select(_getRequiredColumns())
            .eq('user_id', user.uid)
            .order('created_at', ascending: false)
            .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1)
            .limit(_pageSize);

        // Cek apakah masih ada data selanjutnya
        _hasMoreData = response.length == _pageSize;
        _currentPage++;

        if (!mounted) return;

        if (response.isNotEmpty) {
          final newServices = List<Map<String, dynamic>>.from(response);

          // Update cache
          for (var service in newServices) {
            _serviceCache[service['id'].toString()] = service;
          }

          setState(() {
            _services.addAll(newServices);
          });
        }
      } catch (e) {
        print('Error loading more services: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }
    });
  }

  // Fungsi untuk mendapatkan data biaya tambahan dengan cache
  Future<Map<String, dynamic>?> _getAdditionalCost(String serviceId) async {
    try {
      final additionalCost = await _supabase
          .from('additional_costs')
          .select()
          .eq('service_id', serviceId)
          .eq('status', 'PENDING')
          .order('created_at', ascending: false)
          .maybeSingle();

      return additionalCost;
    } catch (e) {
      print('Error getting additional cost: $e');
      return null;
    }
  }

  // Fungsi untuk mendapatkan semua data biaya tambahan terkait dengan layanan
  Future<List<Map<String, dynamic>>> _getAdditionalCosts(
      String serviceId) async {
    try {
      final additionalCosts = await _supabase
          .from('additional_costs')
          .select()
          .eq('service_id', serviceId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(additionalCosts);
    } catch (e) {
      print('Error getting all additional costs: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    // Hapus HANYA channel milik halaman ini, jangan removeAllChannels() yang
    // akan memutus realtime fitur lain di seluruh aplikasi.
    if (_serviceChannel != null) {
      _supabase.removeChannel(_serviceChannel!);
    }
    super.dispose();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _getStatusText(String status, {dynamic serviceCost}) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return serviceCost != null ? 'Menunggu Pembayaran' : 'Menunggu Admin';
      case 'PROCESSED':
        return 'Diproses';
      case 'COMPLETED':
        return 'Selesai';
      case 'PAID':
        return 'Sudah Dibayar';
      case 'EXPIRED':
        return 'Kadaluarsa';
      case 'COMPLAINED':
        return 'Dikomplain';
      case 'ADDITIONAL_PAYMENT':
        return 'Biaya Tambahan';
      case 'UNPAID':
        return 'Belum Dibayar';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, {dynamic serviceCost}) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return serviceCost != null ? Colors.orange : Colors.blue;
      case 'PROCESSED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'PAID':
        return Colors.green;
      case 'EXPIRED':
        return Colors.red;
      case 'COMPLAINED':
        return Colors.red;
      case 'ADDITIONAL_PAYMENT':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  String _getDeviceDisplay(Map<String, dynamic> service) {
    final deviceType = service['device']?.toString().toLowerCase() ?? '';
    final brand = service['brand'] ?? '';
    final model = service['model'] ?? '';

    if (deviceType == 'iphone') {
      return 'iPhone - $model';
    } else if (deviceType == 'huawei') {
      return 'Huawei - $model';
    } else {
      // Untuk Android, tampilkan brand dan model
      return '$brand - $model';
    }
  }

  Future<void> _createPayment(String serviceId) async {
    try {
      final result = await _paymentService.createPayment(serviceId);
      if (!mounted) return;

      if (result['paymentUrl'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewPage(
              paymentUrl: result['paymentUrl'],
              serviceId: serviceId,
            ),
          ),
        );
      } else {
        throw Exception('URL pembayaran tidak valid');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLocationSection(Map<String, dynamic> service) {
    if (service['shipping_method'] == 'antar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Service Center',
            style: TextStyle(
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
                  style: TextStyle(
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
            style: TextStyle(
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
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12.0,
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
    final hasPayment = service['service_cost'] != null;
    final status = service['status']?.toString().toUpperCase() ?? '';
    final needsPayment =
        hasPayment && (status == 'PENDING' || status == 'UNPAID');
    final isExpanded = _expandedCards[service['id'].toString()] ?? false;
    final canGiveFeedback = status == 'COMPLETED';
    final serviceCost = service['service_cost'];
    final hasAdditionalPayment = status == 'ADDITIONAL_PAYMENT';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _testimonialFutureFor(service['id'].toString()),
      builder: (context, snapshot) {
        final hasTestimonial = snapshot.data != null;

        return InkWell(
          onTap: () {
            setState(() {
              _expandedCards[service['id'].toString()] = !isExpanded;
            });
          },
          child: Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Service #${service['id']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(status, serviceCost: serviceCost)
                                  .withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusText(status, serviceCost: serviceCost),
                          style: TextStyle(
                            color: _getStatusColor(status,
                                serviceCost: serviceCost),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    _getDeviceDisplay(service),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DeviceProblems.getProblemName(service['problem'] ?? ''),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isExpanded) ...[
                    SizedBox(height: 16),
                    _buildLocationSection(service),

                    // Tambahkan section biaya tambahan jika status ADDITIONAL_PAYMENT
                    if (hasAdditionalPayment)
                      _buildAdditionalCostSection(service),

                    // Tambahkan section dokumentasi kondisi awal jika ada
                    if (service['pre_service_docs'] != null &&
                        (service['pre_service_docs'] as List).isNotEmpty) ...[
                      SizedBox(height: 16),
                      Divider(color: Colors.grey[300]),
                      SizedBox(height: 16),
                      _buildPreServiceDocumentationSection(service),
                    ],

                    // Tambahkan section kata sandi dan catatan alamat jika ada
                    if (service['device_password'] != null ||
                        service['address_note'] != null) ...[
                      SizedBox(height: 16),
                      Divider(color: Colors.grey[300]),
                      SizedBox(height: 16),
                      _buildAdditionalInfoSection(service),
                    ],
                  ],
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Biaya Service',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          Text(
                            hasPayment
                                ? _currencyFormat
                                    .format(service['service_cost'])
                                : 'Menunggu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  hasPayment ? Colors.green : Colors.grey[400],
                            ),
                          ),

                          // Tambahkan FutureBuilder untuk mengecek dan menampilkan biaya tambahan
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _additionalCostFutureFor(
                                service['id'].toString()),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null) {
                                return SizedBox.shrink();
                              }

                              final additionalCost = snapshot.data!;
                              if (additionalCost['amount'] == null ||
                                  additionalCost['amount'] <= 0) {
                                return SizedBox.shrink();
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Biaya Service Tambahan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                    Text(
                                      _currencyFormat
                                          .format(additionalCost['amount']),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (hasPayment)
                        status == 'PAID'
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(
                                      red: 76, green: 175, blue: 80, alpha: 26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Lunas',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : needsPayment
                                ? ElevatedButton(
                                    onPressed: () => _createPayment(
                                        service['id'].toString()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      'Bayar Sekarang',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : SizedBox(),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dibuat: ${_formatDate(service['created_at'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                  if (canGiveFeedback) ...[
                    SizedBox(height: 16),
                    Divider(color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showRatingDialog(service),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: hasTestimonial
                                    ? Colors.green.withValues(
                                        red: 76,
                                        green: 175,
                                        blue: 80,
                                        alpha: 26)
                                    : Colors.amber.withValues(
                                        red: 255,
                                        green: 193,
                                        blue: 7,
                                        alpha: 26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasTestimonial
                                      ? Colors.green
                                      : Colors.amber,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    hasTestimonial
                                        ? Icons.edit
                                        : Icons.star_rounded,
                                    color: hasTestimonial
                                        ? Colors.green
                                        : Colors.amber,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    hasTestimonial
                                        ? 'Update Testimoni'
                                        : 'Beri Testimoni',
                                    style: GoogleFonts.poppins(
                                      color: hasTestimonial
                                          ? Colors.green[700]
                                          : Colors.amber[700],
                                      fontWeight: FontWeight.w500,
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
                            onTap: service['complain'] == true
                                ? null
                                : () => _showComplaintDialog(service),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: service['complain'] == true
                                    ? Colors.grey.withValues(
                                        red: 158,
                                        green: 158,
                                        blue: 158,
                                        alpha: 26)
                                    : Colors.red.withValues(
                                        red: 244,
                                        green: 67,
                                        blue: 54,
                                        alpha: 26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: service['complain'] == true
                                        ? Colors.grey
                                        : Colors.red,
                                    width: 1),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: service['complain'] == true
                                        ? Colors.grey
                                        : Colors.red,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    service['complain'] == true
                                        ? 'Sudah Dikomplain'
                                        : 'Ajukan Komplain',
                                    style: GoogleFonts.poppins(
                                      color: service['complain'] == true
                                          ? Colors.grey[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w500,
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
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRatingDialog(Map<String, dynamic> service) async {
    // Cek apakah sudah ada testimoni
    final testimonial = await _supabase
        .from('testimonials')
        .select()
        .eq('service_id', service['id'])
        .maybeSingle();

    if (testimonial != null) {
      // Jika sudah ada testimoni, tampilkan dialog untuk update
      if (!mounted) return;

      AwesomeDialog(
        context: context,
        dialogType: DialogType.info,
        animType: AnimType.scale,
        title: 'Update Testimoni',
        desc:
            'Anda sudah memberikan testimoni sebelumnya. Apakah Anda ingin mengupdate testimoni Anda?',
        btnOkText: 'Update',
        btnOkColor: Colors.blue,
        btnCancelText: 'Batal',
        btnCancelColor: Colors.grey,
        btnOkOnPress: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TestimonialPage(
                service: service,
                rating: testimonial['rating'] ?? 5,
                isUpdate: true,
              ),
            ),
          );
        },
        btnCancelOnPress: () {},
      ).show();
      return;
    }

    int rating = 0;
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          insetPadding: EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Beri Rating',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Seberapa puas Anda dengan pelayanan kami?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      constraints: BoxConstraints(
                        minWidth: 40,
                        maxWidth: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() => rating = index + 1);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'BATAL',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: rating > 0
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TestimonialPage(
                                service: service,
                                rating: rating,
                              ),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    'LANJUT',
                    style: GoogleFonts.poppins(
                      color: rating > 0 ? Colors.blue : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showComplaintDialog(Map<String, dynamic> service) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintPage(service: service),
      ),
    );
  }

  Widget _buildPreServiceDocumentationSection(Map<String, dynamic> service) {
    final preServiceDocs = service['pre_service_docs'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dokumentasi Kondisi Awal',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: preServiceDocs.length,
            itemBuilder: (context, index) {
              final doc = preServiceDocs[index];
              final isVideo = doc['type'] == 'video';

              return GestureDetector(
                onTap: () =>
                    _showMediaPreview(context, doc, preServiceDocs, index),
                child: Container(
                  width: 120,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isVideo
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: doc['thumbnail_url'] ??
                                    'https://via.placeholder.com/120',
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                placeholder: (context, url) => Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(Icons.error),
                                ),
                              ),
                              Icon(
                                Icons.play_circle_fill,
                                color: Colors.white.withOpacity(0.8),
                                size: 36,
                              ),
                            ],
                          )
                        : CachedNetworkImage(
                            imageUrl: doc['url'],
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(Icons.error),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection(Map<String, dynamic> service) {
    final devicePassword = service['device_password'];
    final passwordType = service['device_password_type'] ?? 'Tidak Ada';
    final hasPassword = devicePassword != null && passwordType != 'Tidak Ada';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Tambahan',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        if (hasPassword) ...[
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
                      '$passwordType: $devicePassword',
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
      ],
    );
  }

  void _showMediaPreview(BuildContext context, Map<String, dynamic> currentDoc,
      List docs, int initialIndex) {
    final isVideo = currentDoc['type'] == 'video';

    if (isVideo) {
      _showVideoPreview(context, currentDoc);
    } else {
      _showPhotoGallery(context, docs, initialIndex);
    }
  }

  void _showPhotoGallery(BuildContext context, List docs, int initialIndex) {
    // Filter hanya foto
    final imageList = docs.where((doc) => doc['type'] == 'image').toList();
    // Recalculate index jika perlu
    int mappedIndex = 0;
    for (int i = 0; i < initialIndex; i++) {
      if (docs[i]['type'] == 'image') mappedIndex++;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(8),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            PhotoViewGallery.builder(
              itemCount: imageList.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(imageList[index]['url']),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              },
              scrollPhysics: BouncingScrollPhysics(),
              backgroundDecoration: BoxDecoration(
                color: Colors.black,
              ),
              pageController: PageController(initialPage: mappedIndex),
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPreview(BuildContext context, Map<String, dynamic> doc) {
    VideoPlayerController videoController =
        VideoPlayerController.network(doc['url']);

    videoController.initialize().then((_) {
      ChewieController chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: true,
        controlsSafeAreaMinimum: EdgeInsets.all(8),
        placeholder: Center(child: CircularProgressIndicator()),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey[300]!,
          bufferedColor: Colors.grey,
        ),
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: OrientationBuilder(builder: (context, orientation) {
            return Stack(
              children: [
                Container(
                  height: orientation == Orientation.portrait
                      ? MediaQuery.of(context).size.height * 0.4
                      : MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Chewie(controller: chewieController),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {
                      videoController.pause();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            );
          }),
        ),
      ).then((_) {
        videoController.dispose();
        chewieController.dispose();
      });
    }).catchError((error) {
      print('Error initializing video: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat video')),
      );
    });
  }

  // Widget untuk menampilkan biaya tambahan
  Widget _buildAdditionalCostSection(Map<String, dynamic> service) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _additionalCostsFutureFor(service['id'].toString()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return SizedBox.shrink();
        }

        final additionalCosts = snapshot.data!;

        // Filter untuk biaya tambahan yang perlu dibayar
        final pendingCosts = additionalCosts
            .where((cost) => cost['status'] == 'PENDING')
            .toList();

        // Filter untuk biaya tambahan yang sudah dibayar
        final paidCosts =
            additionalCosts.where((cost) => cost['status'] == 'PAID').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 16),

            // Judul bagian
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Riwayat Biaya Tambahan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),

            // Tampilkan biaya tambahan yang perlu dibayar terlebih dahulu
            if (pendingCosts.isNotEmpty) ...[
              for (var additionalCost in pendingCosts)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_outlined,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Biaya Tambahan (Perlu Dibayar)',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ditambahkan: ${_formatDate(additionalCost['created_at'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        additionalCost['note'] ??
                            'Biaya tambahan untuk perbaikan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jumlah:',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                _currencyFormat
                                    .format(additionalCost['amount'] ?? 0),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => _createAdditionalPayment(
                              service['id'].toString(),
                              additionalCost['id'].toString(),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Bayar Sekarang',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],

            // Tampilkan biaya tambahan yang sudah dibayar
            if (paidCosts.isNotEmpty) ...[
              for (var additionalCost in paidCosts)
                Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Biaya Tambahan (Sudah Dibayar)',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ditambahkan: ${_formatDate(additionalCost['created_at'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (additionalCost['updated_at'] != null) ...[
                        Text(
                          'Dibayar: ${_formatDate(additionalCost['updated_at'])}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      Text(
                        additionalCost['note'] ??
                            'Biaya tambahan untuk perbaikan',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Jumlah:',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _currencyFormat
                                .format(additionalCost['amount'] ?? 0),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  // Fungsi untuk membayar biaya tambahan
  Future<void> _createAdditionalPayment(
      String serviceId, String additionalCostId) async {
    try {
      final result = await _paymentService.createAdditionalPayment(
          serviceId, additionalCostId);
      if (!mounted) return;

      if (result['paymentUrl'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebViewPage(
              paymentUrl: result['paymentUrl'],
              serviceId: serviceId,
              isAdditionalPayment: true,
              additionalCostId: additionalCostId,
            ),
          ),
        );
      } else {
        throw Exception('URL pembayaran tidak valid');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Service'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              // Clear cache dan muat ulang data
              _serviceCache.clear();
              _loadServices();

              // Tampilkan indikator refresh
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Memperbarui data...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada riwayat service',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Clear cache saat pull-to-refresh
                    _serviceCache.clear();
                    await _loadServices();
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification scrollInfo) {
                      if (!_isLoadingMore &&
                          scrollInfo.metrics.pixels >=
                              scrollInfo.metrics.maxScrollExtent - 200 &&
                          _hasMoreData) {
                        _loadMoreServices();
                      }
                      return true;
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _services.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _services.length) {
                          return _isLoadingMore
                              ? Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : SizedBox.shrink();
                        }
                        final service = _services[index];
                        return _buildServiceCard(service);
                      },
                    ),
                  ),
                ),
    );
  }
}
