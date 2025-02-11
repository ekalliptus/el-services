// ignore_for_file: deprecated_member_use

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

  Stream<List<Map<String, dynamic>>> _getServiceHistory() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Stream.value([]);

    return _supabase
        .from('services')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.uid)
        .order('created_at', ascending: false);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.parse(dateStr);
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
    final needsPayment = hasPayment && status == 'PENDING';
    final isExpanded = _expandedCards[service['id'].toString()] ?? false;
    final canGiveFeedback = status == 'COMPLETED';
    final serviceCost = service['service_cost'];

    return FutureBuilder<Map<String, dynamic>?>(
      future: _supabase
          .from('testimonials')
          .select()
          .eq('service_id', service['id'])
          .maybeSingle(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blue
                  .withValues(red: 33, green: 150, blue: 243, alpha: 26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.build_circle_outlined,
              size: 100,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 24.0),
          Text(
            'Belum Ada Riwayat Service',
            style: GoogleFonts.poppins(
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.0),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Anda belum memiliki riwayat service. Silakan lakukan service untuk melihat riwayat di sini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.0,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 24.0),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.add_circle_outline),
            label: Text('Buat Service Baru'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          title: Text(
            'Riwayat Service',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getServiceHistory(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }

            final services = snapshot.data!;
            if (services.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) =>
                  _buildServiceCard(services[index]),
            );
          },
        ),
      ),
    );
  }
}
