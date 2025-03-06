// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  final firebase_auth.User user;

  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isEditing = false;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _loadWhatsappNumber();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Format WhatsApp number
      String whatsappNumber =
          _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      if (whatsappNumber.startsWith('0')) {
        whatsappNumber = '62${whatsappNumber.substring(1)}';
      }

      // Check if profile exists
      try {
        final existingProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', widget.user.uid)
            .maybeSingle();

        if (existingProfile != null) {
          // Update existing profile
          await _supabase.from('profiles').update({
            'whatsapp': whatsappNumber,
            'address': _addressController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', widget.user.uid);
          print('Profile updated successfully');
        } else {
          // Create new profile
          await _supabase.from('profiles').insert({
            'id': widget.user.uid,
            'whatsapp': whatsappNumber,
            'address': _addressController.text.trim(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String()
          });
          print('New profile created successfully');
        }

        // Format the WhatsApp number for display
        if (whatsappNumber.startsWith('62')) {
          whatsappNumber = whatsappNumber.replaceAllMapped(
              RegExp(r'(\d{2})(\d{3})(\d{4})(\d+)'),
              (Match m) => "${m[1]}-${m[2]}-${m[3]}-${m[4]}");
        }

        if (mounted) {
          setState(() {
            _phoneController.text = whatsappNumber;
            _isEditing = false;
          });

          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.bottomSlide,
            title: 'Berhasil',
            desc: 'Profil berhasil diperbarui',
            btnOkColor: Colors.blue,
            btnOkOnPress: () {},
          ).show();
        }
      } catch (e) {
        print('Error updating Supabase profile: $e');
        throw Exception('Gagal memperbarui data profil');
      }
    } catch (e) {
      print('Error in _updateProfile: $e');
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.bottomSlide,
          title: 'Gagal',
          desc: e.toString().contains('Exception')
              ? e.toString().replaceAll('Exception: ', '')
              : 'Gagal memperbarui profil. Silakan coba lagi.',
          btnOkColor: Colors.blue,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWhatsappNumber() async {
    try {
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.user.uid)
          .maybeSingle();

      if (profileData != null) {
        String whatsappNumber = profileData['whatsapp'] ?? '';
        String address = profileData['address'] ?? '';

        if (whatsappNumber.startsWith('62')) {
          whatsappNumber = whatsappNumber.replaceAllMapped(
              RegExp(r'(\d{2})(\d{3})(\d{4})(\d+)'),
              (Match m) => "${m[1]}-${m[2]}-${m[3]}-${m[4]}");
        }

        if (mounted) {
          setState(() {
            _phoneController.text = whatsappNumber;
            _addressController.text = address;
          });
        }
      }
    } catch (e) {
      print('Error loading profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          // Jika sedang loading, tampilkan dialog peringatan
          AwesomeDialog(
            context: context,
            dialogType: DialogType.warning,
            animType: AnimType.bottomSlide,
            title: 'Peringatan',
            desc: 'Sedang menyimpan perubahan. Mohon tunggu sebentar.',
            btnOkText: 'OK',
            btnOkColor: Colors.blue,
            btnOkOnPress: () {},
          ).show();
          return false;
        }

        if (_isEditing) {
          // Jika dalam mode edit, tanyakan konfirmasi
          bool shouldPop = false;
          await AwesomeDialog(
            context: context,
            dialogType: DialogType.question,
            animType: AnimType.bottomSlide,
            title: 'Konfirmasi',
            desc:
                'Perubahan yang belum disimpan akan hilang. Yakin ingin keluar?',
            btnOkText: 'Ya',
            btnOkColor: Colors.blue,
            btnOkOnPress: () {
              shouldPop = true;
            },
            btnCancelText: 'Tidak',
            btnCancelOnPress: () {
              shouldPop = false;
            },
          ).show();

          if (shouldPop) {
            _loadWhatsappNumber(); // Kembalikan data ke kondisi sebelumnya
          }
          return shouldPop;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Profil Saya',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () async {
              if (_isLoading) {
                // Jika sedang loading, tampilkan dialog peringatan
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.warning,
                  animType: AnimType.bottomSlide,
                  title: 'Peringatan',
                  desc: 'Sedang menyimpan perubahan. Mohon tunggu sebentar.',
                  btnOkText: 'OK',
                  btnOkColor: Colors.blue,
                  btnOkOnPress: () {},
                ).show();
                return;
              }

              if (_isEditing) {
                // Jika dalam mode edit, tanyakan konfirmasi
                AwesomeDialog(
                  context: context,
                  dialogType: DialogType.question,
                  animType: AnimType.bottomSlide,
                  title: 'Konfirmasi',
                  desc:
                      'Perubahan yang belum disimpan akan hilang. Yakin ingin keluar?',
                  btnOkText: 'Ya',
                  btnOkColor: Colors.blue,
                  btnOkOnPress: () {
                    _loadWhatsappNumber(); // Kembalikan data ke kondisi sebelumnya
                    Navigator.pop(context);
                  },
                  btnCancelText: 'Tidak',
                  btnCancelOnPress: () {},
                ).show();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: Icon(Icons.edit, color: Colors.black87),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
            if (_isEditing)
              IconButton(
                icon: Icon(Icons.check, color: Colors.blue),
                onPressed: _isLoading ? null : _updateProfile,
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: widget.user.photoURL != null
                                ? Image.network(
                                    widget.user.photoURL!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      widget.user.displayName ?? 'Pengguna',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.user.email ?? 'Email tidak tersedia',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Profile Form
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Pribadi',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline,
                        enabled: false,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        enabled: false,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Nomor WhatsApp',
                        icon: Icons.phone_android_outlined,
                        enabled: _isEditing,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nomor WhatsApp tidak boleh kosong';
                          }
                          String cleanNumber =
                              value.replaceAll(RegExp(r'[^\d]'), '');
                          if (cleanNumber.startsWith('0')) {
                            cleanNumber = '62${cleanNumber.substring(1)}';
                          }
                          if (!cleanNumber.startsWith('62')) {
                            return 'Nomor harus dimulai dengan 0 atau 62';
                          }
                          if (cleanNumber.length < 10 ||
                              cleanNumber.length > 13) {
                            return 'Nomor WhatsApp harus 10-13 digit';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Alamat',
                        icon: Icons.location_on_outlined,
                        enabled: _isEditing,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Alamat tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),
                      if (_isEditing)
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _isEditing = false;
                                          // Kembalikan data ke kondisi sebelumnya
                                          _loadWhatsappNumber();
                                        });
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ),
                                child: Text(
                                  'BATAL',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
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
                            ),
                          ],
                        ),
                      SizedBox(height: 24),
                      // Account Info Section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Akun',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildInfoItem(
                              icon: Icons.verified_user,
                              title: 'Status Email',
                              value: widget.user.emailVerified
                                  ? 'Terverifikasi'
                                  : 'Belum Terverifikasi',
                              valueColor: widget.user.emailVerified
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            Divider(height: 24),
                            _buildInfoItem(
                              icon: Icons.access_time,
                              title: 'Bergabung Sejak',
                              value: _formatDate(
                                  widget.user.metadata.creationTime),
                            ),
                            Divider(height: 24),
                            _buildInfoItem(
                              icon: Icons.login,
                              title: 'Login Terakhir',
                              value: _formatDate(
                                  widget.user.metadata.lastSignInTime),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        color: enabled ? Colors.black87 : Colors.grey,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: enabled ? Colors.blue : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tidak tersedia';
    return '${date.day}/${date.month}/${date.year}';
  }
}
