// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/models/service_model.dart';
import 'package:servicehponline/models/device_problems.dart';
import 'package:servicehponline/services/service_api.dart';
import 'package:servicehponline/widgets/mobile_map_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({Key? key}) : super(key: key);

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final _serviceApi = ServiceApi();
  bool _isLoading = true;
  List<ServiceModel> _services = [];
  Map<int, bool> _expandedCards = {};

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
    _loadServiceHistory();
  }

  Future<void> _loadServiceHistory() async {
    setState(() => _isLoading = true);

    try {
      final services = await _serviceApi.getServiceHistory();
      setState(() {
        _services = services;
        _isLoading = false;
        // Initialize all cards as expanded
        for (int i = 0; i < services.length; i++) {
          _expandedCards[i] = true;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat service: $e')),
      );
    }
  }

  String _getDeviceDisplay(ServiceModel service) {
    final deviceName = DeviceProblems.getDeviceName(service.device);
    return '${deviceName} - ${service.brand}';
  }

  Widget _buildLocationSection(ServiceModel service) {
    if (service.shippingMethod == 'Antar') {
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
    } else if (service.latitude != null && service.longitude != null) {
      final pickupPosition = Position(
        latitude: service.latitude!,
        longitude: service.longitude!,
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
                  'Koordinat: ${service.latitude}, ${service.longitude}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Riwayat Service',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 48.0,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 16.0),
                      Text(
                        'Belum ada riwayat service',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadServiceHistory,
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.0),
                    itemCount: _services.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 16.0),
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      final isExpanded = _expandedCards[index] ?? true;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _expandedCards[index] = !isExpanded;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _getDeviceDisplay(service),
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: 20,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                      vertical: 6.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (service.price != null &&
                                              service.price != '-')
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      (service.price != null &&
                                              service.price != '-')
                                          ? 'Sudah Dikonfirmasi'
                                          : 'Menunggu Konfirmasi',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w500,
                                        color: (service.price != null &&
                                                service.price != '-')
                                            ? Colors.green
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isExpanded) ...[
                                Divider(height: 24.0),
                                Text(
                                  'Informasi Kontak',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                _buildDetailRow('Nama', service.fullname),
                                SizedBox(height: 8.0),
                                _buildDetailRow('WhatsApp', service.whatsapp),
                                SizedBox(height: 8.0),
                                _buildDetailRow('Alamat', service.address),
                                Divider(height: 24.0),
                                Text(
                                  'Informasi Service',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                _buildDetailRow(
                                    'Masalah',
                                    DeviceProblems.getProblemName(
                                        service.problem)),
                                SizedBox(height: 8.0),
                                _buildDetailRow(
                                    'Keterangan', service.description),
                                SizedBox(height: 8.0),
                                _buildDetailRow('Metode Pengiriman',
                                    service.shippingMethod),
                                if (service.price != null &&
                                    service.price != '-') ...[
                                  SizedBox(height: 8.0),
                                  _buildDetailRow(
                                    'Harga',
                                    'Rp ${NumberFormat.decimalPattern('id').format(int.parse(service.price!))}',
                                    valueColor: Colors.green,
                                    valueWeight: FontWeight.w600,
                                  ),
                                ],
                                Divider(height: 24.0),
                                _buildLocationSection(service),
                                if (service.picture != null ||
                                    service.video != null) ...[
                                  Divider(height: 24.0),
                                  Text(
                                    'Dokumentasi',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  if (service.picture != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.file(
                                        File(service.picture!),
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  if (service.video != null) ...[
                                    if (service.picture != null)
                                      SizedBox(height: 12.0),
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.play_circle_outline,
                                            size: 64,
                                            color: Colors.blue,
                                          ),
                                          Positioned(
                                            bottom: 12,
                                            child: Text(
                                              'Tekan untuk memutar video',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontSize: 14.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14.0,
          ),
        ),
        SizedBox(width: 8.0),
        Text(
          ':',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14.0,
          ),
        ),
        SizedBox(width: 8.0),
        Expanded(
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
    );
  }
}
