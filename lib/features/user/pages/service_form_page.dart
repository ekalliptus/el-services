import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/data/models/service_model.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:servicehponline/features/user/pages/confirmation_page.dart';

class ServiceFormPage extends StatefulWidget {
  final String deviceType;

  const ServiceFormPage({
    Key? key,
    required this.deviceType,
  }) : super(key: key);

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _addressController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  String? _selectedProblem;
  final _descriptionController = TextEditingController();
  String _shippingMethod = 'antar'; // Default ke antar
  double? _latitude;
  double? _longitude;
  String? _picturePath;
  String? _videoPath;

  @override
  void dispose() {
    _fullnameController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final service = ServiceModel(
        userId: '', // Akan diisi di payment_service.dart
        fullname: _fullnameController.text,
        phoneNumber: _whatsappController.text,
        address: _addressController.text,
        device: widget.deviceType,
        problem: _selectedProblem!,
        brand: widget.deviceType == 'iphone'
            ? 'iPhone'
            : widget.deviceType == 'huawei'
                ? 'Huawei'
                : _brandController.text,
        model: _modelController.text,
        description: _descriptionController.text,
        shippingMethod: _shippingMethod,
        pictureDamage: _picturePath,
        pictureFront: _picturePath,
        pictureBack: _picturePath,
        video: _videoPath,
        latitude: _selectedProblem == 'jemput' ? _latitude : null,
        longitude: _selectedProblem == 'jemput' ? _longitude : null,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationPage(
            service: service,
            prevPage: () => Navigator.pop(context),
            onConfirm: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/history',
              (route) => false,
            ),
          ),
        ),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Form Service',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Data Diri',
                style: GoogleFonts.poppins(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _fullnameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama lengkap harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _whatsappController,
                decoration: InputDecoration(
                  labelText: 'Nomor WhatsApp',
                  border: OutlineInputBorder(),
                  prefixText: '+62 ',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor WhatsApp harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alamat harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.0),
              Text(
                'Detail Perangkat',
                style: GoogleFonts.poppins(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16.0),
              if (widget.deviceType == 'android') ...[
                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: 'Merk',
                    border: OutlineInputBorder(),
                    hintText: 'Contoh: Samsung, Xiaomi, Oppo, dll',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Merk harus diisi';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),
              ],
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model/Tipe HP',
                  border: OutlineInputBorder(),
                  hintText: widget.deviceType == 'iphone'
                      ? 'Contoh: iPhone 12 Pro Max'
                      : widget.deviceType == 'huawei'
                          ? 'Contoh: P40 Pro'
                          : 'Contoh: Galaxy S21 Ultra',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Model/Tipe HP harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: _selectedProblem,
                decoration: InputDecoration(
                  labelText: 'Masalah',
                  border: OutlineInputBorder(),
                ),
                items: DeviceProblems.getProblems(widget.deviceType)
                    .map((problem) => DropdownMenuItem(
                          value: problem,
                          child: Text(DeviceProblems.getProblemName(problem)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProblem = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Masalah harus dipilih';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Keterangan Tambahan',
                  border: OutlineInputBorder(),
                  hintText: 'Jelaskan lebih detail masalah yang dialami',
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Keterangan harus diisi';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.0),
              Text(
                'Metode Pengiriman',
                style: GoogleFonts.poppins(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: Text('Antar ke Service Center'),
                      value: 'antar',
                      groupValue: _shippingMethod,
                      onChanged: (value) {
                        setState(() {
                          _shippingMethod = value.toString();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: Text('Jemput di Lokasi'),
                      value: 'jemput',
                      groupValue: _shippingMethod,
                      onChanged: (value) {
                        setState(() {
                          _shippingMethod = value.toString();
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  'Lanjutkan',
                  style: GoogleFonts.poppins(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}
