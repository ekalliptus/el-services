// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/models/service_model.dart';
import 'package:servicehponline/models/device_problems.dart';
import 'package:servicehponline/services/service_api.dart';
import 'package:intl/intl.dart';

class ServiceHistoryPage extends StatefulWidget {
  const ServiceHistoryPage({Key? key}) : super(key: key);

  @override
  State<ServiceHistoryPage> createState() => _ServiceHistoryPageState();
}

class _ServiceHistoryPageState extends State<ServiceHistoryPage> {
  final _serviceApi = ServiceApi();
  bool _isLoading = true;
  List<ServiceModel> _services = [];

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
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat riwayat service: $e')),
      );
    }
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
                      return Container(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  service.fullname,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 6.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (service.price != null &&
                                            service.price != '-')
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Text(
                                    (service.price != null &&
                                            service.price != '-')
                                        ? 'Sudah Dikonfirmasi'
                                        : 'Menunggu Konfirmasi',
                                    style: TextStyle(
                                      color: (service.price != null &&
                                              service.price != '-')
                                          ? Colors.green
                                          : Colors.blue,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            _buildDetailRow(
                              'Perangkat',
                              DeviceProblems.getDeviceName(service.device),
                            ),
                            SizedBox(height: 8.0),
                            _buildDetailRow(
                              'Masalah',
                              DeviceProblems.getProblemName(service.problem),
                            ),
                            SizedBox(height: 8.0),
                            _buildDetailRow('Brand', service.brand),
                            SizedBox(height: 8.0),
                            _buildDetailRow('Model', service.model),
                            SizedBox(height: 8.0),
                            _buildDetailRow('Metode Pengiriman', service.shippingMethod),
                            SizedBox(height: 8.0),
                            if (service.price != null && service.price != '-')
                              _buildDetailRow(
                                'Harga',
                                'Rp ${NumberFormat.decimalPattern('id').format(int.parse(service.price!))}',
                                valueColor: Colors.green,
                                valueWeight: FontWeight.w600,
                              ),
                          ],
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
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontSize: 14.0,
            fontWeight: valueWeight ?? FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
