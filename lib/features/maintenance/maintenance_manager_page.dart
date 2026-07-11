import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/core/widgets/widgets.dart';
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
                                borderRadius: BorderRadius.circular(16),

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Mode Maintenance'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : !_isTableExists
              ? AnrEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Tabel System Settings Belum Ada',
                  message:
                      'Buat tabel system_settings di Supabase untuk menggunakan fitur maintenance.',
                  action: AnrButton(
                    label: 'Lihat SQL',
                    onPressed: _showCreateTableDialog,
                    icon: Icons.code_rounded,
                    fullWidth: false,
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 720),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status Panel
                            AnrCard(
                              color: (_isInMaintenanceMode
                                      ? AppColors.warning
                                      : AppColors.success)
                                  .withValues(alpha: 0.1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status Saat Ini:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
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
                                      Expanded(
                                        child: Text(
                                          _isInMaintenanceMode
                                              ? 'Aplikasi dalam Mode Maintenance'
                                              : 'Aplikasi Berjalan Normal',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: _isInMaintenanceMode
                                                ? AppColors.warning
                                                : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  AnrButton(
                                    label: _isInMaintenanceMode
                                        ? 'Nonaktifkan Mode Maintenance'
                                        : 'Aktifkan Mode Maintenance',
                                    onPressed: _isUpdating
                                        ? null
                                        : _toggleMaintenanceMode,
                                    icon: _isInMaintenanceMode
                                        ? Icons.toggle_off_rounded
                                        : Icons.toggle_on_rounded,
                                    loading: _isUpdating,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            // Settings Form
                            AnrSectionHeader(
                              title: 'Pengaturan Maintenance',
                              subtitle:
                                  'Pesan ini ditampilkan saat mode maintenance aktif.',
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
                                      ? DateFormat(
                                              'dd MMMM yyyy, HH:mm', 'id_ID')
                                          .format(_estimatedCompletion!)
                                      : 'Pilih tanggal dan waktu',
                                ),
                              ),
                            ),
                            SizedBox(height: 24),

                            // Update button
                            if (_isInMaintenanceMode)
                              AnrButton(
                                label: 'Perbarui Detail Maintenance',
                                onPressed: _isUpdating
                                    ? null
                                    : _updateMaintenanceDetails,
                                icon: Icons.save_rounded,
                                loading: _isUpdating,
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
                  ),
                ),
    );
  }
}
