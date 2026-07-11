// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/core/widgets/widgets.dart';
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
  late TextEditingController _addressNoteController;
  bool _isEditing = false;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '');
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _addressNoteController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addressNoteController.dispose();
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

      // Persiapkan data untuk disimpan dengan explicit trim
      String fullname = _nameController.text.trim();
      String address = _addressController.text.trim();
      String addressNote = _addressNoteController.text.trim();

      // Log data yang akan disimpan untuk debugging
      print('------------ SAVING PROFILE DATA ------------');
      print('UID: ${widget.user.uid}');
      print('Fullname: $fullname');
      print('WhatsApp: $whatsappNumber');
      print('Address: $address');
      print('Address Note: $addressNote');
      print('--------------------------------------------');

      // Check if profile exists
      try {
        final existingProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', widget.user.uid)
            .maybeSingle();

        // Map data profile untuk update/insert
        final profileData = {
          'fullname': fullname,
          'phoneNumber': whatsappNumber,
          'address': address,
          'address_note': addressNote,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (existingProfile != null) {
          // Update existing profile
          final response = await _supabase
              .from('profiles')
              .update(profileData)
              .eq('id', widget.user.uid);
          print('Profile updated successfully: $response');
        } else {
          // Create new profile dengan explicit ID
          final insertData = {
            ...profileData,
            'id': widget.user.uid,
            'created_at': DateTime.now().toIso8601String(),
          };
          final response = await _supabase.from('profiles').insert(insertData);
          print('New profile created successfully: $response');
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

          // Reload data untuk verifikasi bahwa semua berhasil disimpan
          Future.delayed(Duration(milliseconds: 500), () {
            if (!mounted) return;
            _loadProfileData();
          });

          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.bottomSlide,
            title: 'Berhasil',
            desc: 'Profil berhasil diperbarui',
            btnOkColor: Theme.of(context).colorScheme.primary,
            btnOkOnPress: () {},
          ).show();
        }
      } catch (e) {
        print('Error updating Supabase profile: $e');
        // Tampilkan error yang lebih detail
        String errorMessage = 'Gagal memperbarui data profil';
        if (e is PostgrestException) {
          errorMessage += ': ${e.message}';
        }
        throw Exception(errorMessage);
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
          btnOkColor: Theme.of(context).colorScheme.primary,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.user.uid)
          .maybeSingle();

      if (!mounted) return;

      // Log data yang diambil untuk debugging
      print('------------ LOADED PROFILE DATA ------------');
      print('Profile data: $profileData');
      if (profileData != null) {
        print('Fullname: ${profileData['fullname']}');
        print('WhatsApp: ${profileData['phoneNumber']}');
        print('Address: ${profileData['address']}');
        print('Address Note: ${profileData['address_note']}');
      } else {
        print('Profile not found in database');
      }
      print('--------------------------------------------');

      if (profileData != null) {
        // Ambil fullname dari Supabase jika ada
        String fullname = profileData['fullname'] ?? '';
        String whatsappNumber = profileData['phoneNumber'] ?? '';
        String address = profileData['address'] ?? '';
        String addressNote = profileData['address_note'] ?? '';

        if (whatsappNumber.startsWith('62')) {
          whatsappNumber = whatsappNumber.replaceAllMapped(
              RegExp(r'(\d{2})(\d{3})(\d{4})(\d+)'),
              (Match m) => "${m[1]}-${m[2]}-${m[3]}-${m[4]}");
        }

        if (mounted) {
          setState(() {
            // Gunakan fullname dari Supabase jika ada, jika tidak ada gunakan dari Firebase
            _nameController.text = fullname.isNotEmpty
                ? fullname
                : (widget.user.displayName ?? '');
            _phoneController.text = whatsappNumber;
            _addressController.text = address;
            _addressNoteController.text = addressNote;
          });
        }
      } else {
        // Jika profil belum ada, gunakan data dari Firebase
        if (mounted) {
          setState(() {
            _nameController.text = widget.user.displayName ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading profile data: $e');
      // Jika gagal, gunakan data dari Firebase
      if (mounted) {
        setState(() {
          _nameController.text = widget.user.displayName ?? '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            btnOkColor: Theme.of(context).colorScheme.primary,
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
            btnOkColor: Theme.of(context).colorScheme.primary,
            btnOkOnPress: () {
              shouldPop = true;
            },
            btnCancelText: 'Tidak',
            btnCancelOnPress: () {
              shouldPop = false;
            },
          ).show();

          if (shouldPop) {
            _loadProfileData(); // Kembalikan data ke kondisi sebelumnya
          }
          return shouldPop;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          title: Text(
            'Profil Saya',
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface,
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
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
                  btnOkColor: colorScheme.primary,
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
                  btnOkColor: colorScheme.primary,
                  btnOkOnPress: () {
                    _loadProfileData(); // Kembalikan data ke kondisi sebelumnya
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
                icon: Icon(Icons.edit, color: colorScheme.onSurface),
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
            if (_isEditing)
              IconButton(
                icon: Icon(Icons.check, color: colorScheme.primary),
                onPressed: _isLoading ? null : _updateProfile,
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AnrCard(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.surfaceContainerHighest,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: 60,
                                          color: colorScheme.onSurfaceVariant,
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 60,
                                      color: colorScheme.onSurfaceVariant,
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
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.user.email ?? 'Email tidak tersedia',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
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
                      AnrSectionHeader(title: 'Informasi Pribadi'),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama lengkap tidak boleh kosong';
                          }
                          return null;
                        },
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
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressNoteController,
                        label: 'Catatan Alamat',
                        icon: Icons.note_outlined,
                        enabled: _isEditing,
                        maxLines: 2,
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
                                          _loadProfileData();
                                        });
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side:
                                        BorderSide(color: colorScheme.outline),
                                  ),
                                ),
                                child: Text(
                                  'BATAL',
                                  style: GoogleFonts.poppins(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: AnrButton(
                                label: 'SIMPAN',
                                onPressed: _updateProfile,
                                loading: _isLoading,
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 24),
                      // Account Info Section
                      AnrCard(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnrSectionHeader(title: 'Informasi Akun'),
                            SizedBox(height: 16),
                            _buildInfoItem(
                              icon: Icons.verified_user,
                              title: 'Status Email',
                              value: widget.user.emailVerified
                                  ? 'Terverifikasi'
                                  : 'Belum Terverifikasi',
                              valueColor: widget.user.emailVerified
                                  ? AppColors.success
                                  : AppColors.warning,
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
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: colorScheme.onSurfaceVariant,
        ),
        prefixIcon: Icon(icon,
            color:
                enabled ? colorScheme.primary : colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        filled: true,
        fillColor:
            enabled ? colorScheme.surface : colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
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
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? colorScheme.onSurface,
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
