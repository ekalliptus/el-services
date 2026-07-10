import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/features/maintenance/maintenance_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MaintenanceManagerPage extends StatefulWidget {
  const MaintenanceManagerPage({Key? key}) : super(key: key);

  @override
  State<MaintenanceManagerPage> createState() => _MaintenanceManagerPageState();
}

class _MaintenanceManagerPageState extends State<MaintenanceManagerPage> {
  bool _isLoading = true;
  bool _isInMaintenanceMode = false;
  bool _isTableExists = true;
  bool _isUpdating = false;

  // Form controllers
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _estimatedCompletion;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Inisialisasi data locale untuk bahasa Indonesia
    initializeDateFormatting('id_ID', null).then((_) {
      if (!mounted) return;
      _checkMaintenanceStatus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkMaintenanceStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Periksa apakah tabel settings ada
      try {
        await MaintenanceService.ensureSettingsTableExists();
        if (!mounted) return;
        setState(() {
          _isTableExists = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isTableExists = false;
        });
        return;
      }

      // Periksa status maintenance
      final isInMaintenance =
          await MaintenanceService.isInMaintenanceMode(forceCheck: true);

      // Jika mode maintenance aktif, ambil detail
      if (isInMaintenance) {
        final details = await MaintenanceService.getMaintenanceDetails();

        _titleController.text = details['title'] ?? '';
        _messageController.text = details['message'] ?? '';
        _estimatedCompletion = details['estimatedCompletion'];
      } else {
        // Set nilai default untuk form
        _titleController.text = 'Aplikasi Sedang Maintenance';
        _messageController.text =
            'Kami sedang melakukan perbaikan sistem untuk meningkatkan layanan. Silakan kembali lagi nanti.';
        _estimatedCompletion = DateTime.now().add(Duration(hours: 1));
      }

      if (!mounted) return;
      setState(() {
        _isInMaintenanceMode = isInMaintenance;
      });
    } catch (e) {
      print('Error memeriksa status maintenance: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleMaintenanceMode() async {
    // Validasi form jika akan mengaktifkan mode
    if (!_isInMaintenanceMode && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      bool success;

      if (_isInMaintenanceMode) {
        // Nonaktifkan mode maintenance
        success = await MaintenanceService.disableMaintenanceMode();

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mode maintenance dinonaktifkan'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Aktifkan mode maintenance
        success = await MaintenanceService.enableMaintenanceMode(
          title: _titleController.text,
          message: _messageController.text,
          estimatedCompletion: _estimatedCompletion,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mode maintenance diaktifkan'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }

      if (success) {
        await _checkMaintenanceStatus();
      }
    } catch (e) {
      print('Error mengubah status maintenance: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateMaintenanceDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await MaintenanceService.enableMaintenanceMode(
        title: _titleController.text,
        message: _messageController.text,
        estimatedCompletion: _estimatedCompletion,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detail maintenance berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );

        await _checkMaintenanceStatus();
      }
    } catch (e) {
      print('Error memperbarui detail maintenance: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final currentDate =
        _estimatedCompletion ?? DateTime.now().add(Duration(hours: 1));

    // Pilih tanggal
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 30)),
      locale: Locale('id', 'ID'),
    );

    if (selectedDate == null || !mounted) return;

    // Pilih waktu
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentDate),
    );

    if (selectedTime == null || !mounted) return;

    setState(() {
      _estimatedCompletion = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _showCreateTableDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tabel System Settings Belum Ada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tabel "system_settings" belum ada di database. Tabel ini diperlukan untuk fitur maintenance mode.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('SQL untuk membuat tabel system_settings:'),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: SelectableText(
                  MaintenanceService.getCreateTableSQL(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('Jalankan SQL ini di SQL Editor di dashboard Supabase.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('TUTUP'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _checkMaintenanceStatus();
            },
            child: Text('COBA LAGI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Mode Maintenance'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : !_isTableExists
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 64, color: AppColors.warning),
                        SizedBox(height: 16),
                        Text(
                          'Tabel System Settings Belum Ada',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Anda perlu membuat tabel system_settings di database Supabase untuk menggunakan fitur ini.',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showCreateTableDialog,
                          icon: Icon(Icons.code),
                          label: Text('Lihat SQL untuk Membuat Tabel'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Panel
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (_isInMaintenanceMode
                                    ? AppColors.warning
                                    : AppColors.success)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_isInMaintenanceMode
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Saat Ini:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _isInMaintenanceMode
                                        ? Icons.engineering
                                        : Icons.check_circle,
                                    color: _isInMaintenanceMode
                                        ? AppColors.warning
                                        : AppColors.success,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _isInMaintenanceMode
                                        ? 'Aplikasi dalam Mode Maintenance'
                                        : 'Aplikasi Berjalan Normal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _isInMaintenanceMode
                                          ? AppColors.warning
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed:
                                    _isUpdating ? null : _toggleMaintenanceMode,
                                icon: Icon(_isInMaintenanceMode
                                    ? Icons.toggle_off
                                    : Icons.toggle_on),
                                label: Text(_isInMaintenanceMode
                                    ? 'Nonaktifkan Mode Maintenance'
                                    : 'Aktifkan Mode Maintenance'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isInMaintenanceMode
                                      ? AppColors.success
                                      : AppColors.warning,
                                  foregroundColor: colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Settings Form
                        Text(
                          'Pengaturan Maintenance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),

                        // Title field
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Judul',
                            hintText: 'Judul pesan maintenance',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Judul tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Message field
                        TextFormField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            labelText: 'Pesan',
                            hintText:
                                'Pesan yang akan ditampilkan kepada pengguna',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Pesan tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Estimated completion time
                        InkWell(
                          onTap: () => _selectDateTime(context),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Estimasi Waktu Selesai',
                              hintText: 'Pilih tanggal dan waktu',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _estimatedCompletion != null
                                  ? DateFormat('dd MMMM yyyy, HH:mm', 'id_ID')
                                      .format(_estimatedCompletion!)
                                  : 'Pilih tanggal dan waktu',
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Update button
                        if (_isInMaintenanceMode)
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _isUpdating
                                  ? null
                                  : _updateMaintenanceDetails,
                              icon: Icon(Icons.save),
                              label: Text('Perbarui Detail Maintenance'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ),

                        // Loading indicator
                        if (_isUpdating)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
