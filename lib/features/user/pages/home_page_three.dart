// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:servicehponline/data/models/service_model.dart';
import 'package:servicehponline/data/models/devices/m_android.dart';
import 'package:servicehponline/data/models/devices/m_iphone.dart';
import 'package:servicehponline/data/models/devices/m_huawei.dart';
import 'package:servicehponline/data/models/devices/m_brands.dart';
import 'package:servicehponline/features/user/widgets/page_indicator_widget.dart';
import 'package:servicehponline/features/user/pages/confirmation_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servicehponline/features/user/widgets/mobile_map_picker_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePageThree extends StatefulWidget {
  final String selectedDevice;
  final String selectedProblem;
  final VoidCallback prevPage;

  const HomePageThree({
    Key? key,
    required this.selectedDevice,
    required this.selectedProblem,
    required this.prevPage,
  }) : super(key: key);

  @override
  State<HomePageThree> createState() => _HomePageThreeState();
}

class _HomePageThreeState extends State<HomePageThree> {
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<String> _damageImages = [];
  final List<String> _frontImages = [];
  final List<String> _backImages = [];
  String? _videoPath;
  bool _isLoading = false;
  String _selectedShipping = 'Jemput';
  Position? _currentPosition;
  String? _selectedBrand;

  List<String> get _availableBrands {
    switch (widget.selectedDevice) {
      case 'iphone':
        return BrandModels.iphoneBrands;
      case 'huawei':
        return BrandModels.huaweiBrands;
      default:
        return BrandModels.androidBrands;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedBrand = widget.selectedDevice == 'iphone'
        ? 'iPhone'
        : widget.selectedDevice == 'huawei'
            ? 'Huawei'
            : null;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Layanan lokasi tidak aktif';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan.';
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String category) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          switch (category) {
            case 'damage':
              _damageImages.add(image.path);
              break;
            case 'front':
              _frontImages.add(image.path);
              break;
            case 'back':
              _backImages.add(image.path);
              break;
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final video = await _imagePicker.pickVideo(
        source: source,
        maxDuration: Duration(minutes: 1),
      );
      if (video != null) {
        setState(() {
          _videoPath = video.path;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  Future<void> _showMediaSourceDialog(String category) async {
    String title = '';
    switch (category) {
      case 'damage':
        title = 'Foto Kerusakan';
        break;
      case 'front':
        title = 'Foto Tampak Depan';
        break;
      case 'back':
        title = 'Foto Tampak Belakang';
        break;
      case 'video':
        title = 'Video';
        break;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tambah $title',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              if (category != 'video')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera, category);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery, category);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.photo_library,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              if (category == 'video')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo(ImageSource.camera);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.videocam,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Kamera',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _pickVideo(ImageSource.gallery);
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.video_library,
                                color: Colors.green,
                                size: 32,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Galeri',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _createService() {
    if (_nameController.text.isEmpty ||
        _whatsappController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _modelController.text.isEmpty ||
        (widget.selectedDevice == 'android' && _selectedBrand == null) ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mohon lengkapi semua data'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi format nomor WhatsApp
    String whatsappNumber = _whatsappController.text;
    if (!whatsappNumber.startsWith('62')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nomor WhatsApp harus diawali dengan 62'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validasi lokasi untuk metode penjemputan
    if (_selectedShipping == 'Jemput' && _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mohon pilih lokasi penjemputan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final service = ServiceModel(
      userId: '',
      fullname: _nameController.text,
      whatsapp: _whatsappController.text,
      address: _addressController.text,
      device: widget.selectedDevice,
      problem: widget.selectedProblem,
      brand: widget.selectedDevice == 'iphone'
          ? 'iPhone'
          : widget.selectedDevice == 'huawei'
              ? 'Huawei'
              : _selectedBrand!,
      model: _modelController.text,
      pictureDamage: _damageImages.isNotEmpty ? _damageImages.first : null,
      pictureFront: _frontImages.isNotEmpty ? _frontImages.first : null,
      pictureBack: _backImages.isNotEmpty ? _backImages.first : null,
      video: _videoPath,
      description: _descriptionController.text,
      shippingMethod: _selectedShipping,
      latitude:
          _selectedShipping == 'Jemput' ? _currentPosition?.latitude : null,
      longitude:
          _selectedShipping == 'Jemput' ? _currentPosition?.longitude : null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmationPage(service: service),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    // Koordinat Service Center
    const lat = -6.151882179907883;
    const lng = 106.92619538817382;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
        );
      }
    }
  }

  Widget _buildShippingSection() {
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
          Text(
            'Pilih Jasa Pengiriman',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _selectedShipping = 'Jemput');
                    if (_currentPosition == null) {
                      await _getCurrentLocation();
                    }
                  },
                  icon: Icon(Icons.directions_car),
                  label: Text('Jemput'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedShipping == 'Jemput'
                        ? Colors.blue
                        : Colors.grey[300],
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedShipping = 'Antar';
                      _currentPosition = null;
                    });
                  },
                  icon: Icon(Icons.local_shipping),
                  label: Text('Antar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedShipping == 'Antar'
                        ? Colors.blue
                        : Colors.grey[300],
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedShipping == 'Jemput') ...[
            SizedBox(height: 16.0),
            Text(
              'Pilih Lokasi Penjemputan',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8.0),
            MapPicker(
              initialPosition: _currentPosition,
              onPositionChanged: (Position position) {
                setState(() => _currentPosition = position);
              },
            ),
            if (_currentPosition != null) ...[
              SizedBox(height: 8.0),
              Text(
                'Koordinat: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12.0,
                ),
              ),
            ],
          ],
          if (_selectedShipping == 'Antar') ...[
            SizedBox(height: 16.0),
            Container(
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 24.0,
                  ),
                  SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Silakan antar perangkat Anda ke alamat service center kami',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              'Lokasi Service Center',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
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
                    'Jl. Manunggal Juang II No.40, RT./rw/RW.06, Sukapura, Kec. Cilincing, Jkt Utara, Daerah Khusus Ibukota Jakarta 14140',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            ElevatedButton.icon(
              onPressed: _openGoogleMaps,
              icon: Icon(Icons.directions),
              label: Text('Buka di Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageIndicator(currentPage: 2, darkMode: false),
                    SizedBox(height: 20.0),
                    Text(
                      "Data Service",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12.0),
                    Text(
                      "Lengkapi data berikut dengan benar\nsupaya cepat kami setujui proses perbaikan",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16.0,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data Diri',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16.0),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.0),
                            TextFormField(
                              controller: _whatsappController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Nomor WhatsApp',
                                hintText: 'Contoh: 628123456789',
                                helperText: 'Nomor harus diawali dengan 62',
                                helperStyle: TextStyle(color: Colors.grey[600]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.0),
                            TextField(
                              controller: _addressController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Alamat Lengkap',
                                prefixIcon: Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.0),
                      Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detail Perangkat',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16.0),
                            _buildDetailItem(
                              'Perangkat',
                              widget.selectedDevice == 'iphone'
                                  ? 'iPhone'
                                  : widget.selectedDevice == 'huawei'
                                      ? 'Huawei'
                                      : 'Android',
                            ),
                            SizedBox(height: 12.0),
                            _buildDetailItem(
                              'Masalah',
                              _deviceName,
                            ),
                            SizedBox(height: 12.0),
                            if (widget.selectedDevice == 'android') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedBrand,
                                decoration: InputDecoration(
                                  labelText: 'Merk Perangkat/Ponsel',
                                  prefixIcon: Icon(Icons.phone_android),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide(color: Colors.blue),
                                  ),
                                ),
                                items: _availableBrands.map((String brand) {
                                  return DropdownMenuItem<String>(
                                    value: brand,
                                    child: Text(brand),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedBrand = newValue;
                                  });
                                },
                              ),
                              SizedBox(height: 12.0),
                            ],
                            TextField(
                              controller: _modelController,
                              decoration: InputDecoration(
                                labelText: 'Model/Tipe HP',
                                prefixIcon: Icon(Icons.phone_iphone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                                hintText: widget.selectedDevice == 'iphone'
                                    ? 'Contoh: iPhone 12 Pro Max'
                                    : widget.selectedDevice == 'huawei'
                                        ? 'Contoh: P40 Pro'
                                        : 'Contoh: Galaxy S21 Ultra',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.0),
                      _buildDocumentationSection(),
                      SizedBox(height: 20.0),
                      Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keterangan Kerusakan',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16.0),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText:
                                    'Jelaskan detail kerusakan perangkat Anda',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.0),
                      _buildShippingSection(),
                      SizedBox(height: 20.0),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createService,
                        child: _isLoading
                            ? SizedBox(
                                width: 24.0,
                                height: 24.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text('Lanjutkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14.0,
          ),
        ),
        SizedBox(height: 4.0),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  String get _deviceName {
    if (widget.selectedDevice == 'iphone') {
      return IPhoneProblems.problems
          .expand((list) => list)
          .firstWhere(
            (problem) => problem.key == widget.selectedProblem,
            orElse: () => IPhoneProblem(
              key: widget.selectedProblem,
              name: 'Unknown',
              info: '',
              icon: Icons.error,
            ),
          )
          .name;
    } else if (widget.selectedDevice == 'huawei') {
      return HuaweiProblems.problems
          .expand((list) => list)
          .firstWhere(
            (problem) => problem.key == widget.selectedProblem,
            orElse: () => HuaweiProblem(
              key: widget.selectedProblem,
              name: 'Unknown',
              info: '',
              icon: Icons.error,
            ),
          )
          .name;
    } else {
      return AndroidProblems.problems
          .expand((list) => list)
          .firstWhere(
            (problem) => problem.key == widget.selectedProblem,
            orElse: () => AndroidProblem(
              key: widget.selectedProblem,
              name: 'Unknown',
              info: '',
              icon: Icons.error,
            ),
          )
          .name;
    }
  }

  Widget _buildDocumentationSection() {
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
          Text(
            'Dokumentasi',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.0),
          // Foto Kerusakan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto Kerusakan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              if (_damageImages.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 48.0,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Belum ada foto kerusakan',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _damageImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(_damageImages[index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _damageImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showMediaSourceDialog('damage'),
                icon: Icon(Icons.add_a_photo),
                label: Text('Tambah Foto Kerusakan'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Foto Tampak Depan
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto Tampak Depan',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              if (_frontImages.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 48.0,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Belum ada foto tampak depan',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _frontImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(_frontImages[index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _frontImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showMediaSourceDialog('front'),
                icon: Icon(Icons.add_a_photo),
                label: Text('Tambah Foto Tampak Depan'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Foto Tampak Belakang
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto Tampak Belakang',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              if (_backImages.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 48.0,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Belum ada foto tampak belakang',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _backImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(_backImages[index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _backImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showMediaSourceDialog('back'),
                icon: Icon(Icons.add_a_photo),
                label: Text('Tambah Foto Tampak Belakang'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Video
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              if (_videoPath == null)
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 48.0,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Belum ada video',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Stack(
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _videoPath = null;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 8),
              if (_videoPath == null)
                ElevatedButton.icon(
                  onPressed: () => _showMediaSourceDialog('video'),
                  icon: Icon(Icons.videocam),
                  label: Text('Tambah Video'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
