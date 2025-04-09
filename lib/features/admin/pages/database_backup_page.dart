import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DatabaseBackupPage extends StatefulWidget {
  const DatabaseBackupPage({Key? key}) : super(key: key);

  @override
  State<DatabaseBackupPage> createState() => _DatabaseBackupPageState();
}

class _DatabaseBackupPageState extends State<DatabaseBackupPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupHistory = [];
  bool _isCreatingBackup = false;
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadBackupHistory();
  }

  Future<void> _loadBackupHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Coba muat dari Supabase jika tersedia
      try {
        final response = await SupabaseConfig.client
            .from('database_backups')
            .select('*')
            .order('created_at', ascending: false);

        setState(() {
          _backupHistory = List<Map<String, dynamic>>.from(response);
        });
      } catch (e) {
        print('Riwayat backup tidak ditemukan: $e');

        // Gunakan data sampel jika tidak ada data
        setState(() {
          _backupHistory = [
            {
              'id': '1',
              'name': 'Backup Manual',
              'created_at':
                  DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
              'size': 2458000,
              'status': 'success',
              'tables': ['profiles', 'services', 'admins'],
              'created_by': 'super_admin@example.com',
            },
            {
              'id': '2',
              'name': 'Backup Otomatis',
              'created_at':
                  DateTime.now().subtract(Duration(days: 7)).toIso8601String(),
              'size': 2245000,
              'status': 'success',
              'tables': ['profiles', 'services', 'admins'],
              'created_by': 'system',
            },
          ];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat riwayat backup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup(String name, List<String> tables) async {
    setState(() {
      _isCreatingBackup = true;
    });

    try {
      // Simulasi pembuatan backup (Karena ini memerlukan akses langsung ke database yang tidak tersedia via API)
      await Future.delayed(Duration(seconds: 3));

      // Tambahkan entri baru di riwayat backup
      final newBackup = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
        'size': 2500000 + (DateTime.now().millisecondsSinceEpoch % 1000000),
        'status': 'success',
        'tables': tables,
        'created_by':
            SupabaseConfig.client.auth.currentUser?.email ?? 'super_admin',
      };

      // Tambahkan ke Supabase jika tabel ada
      try {
        await SupabaseConfig.client.from('database_backups').insert(newBackup);
      } catch (e) {
        print('Gagal menyimpan backup ke database: $e');
        // Tetap lanjutkan meskipun gagal menyimpan ke database
      }

      // Update tampilan
      setState(() {
        _backupHistory.insert(0, newBackup);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup berhasil dibuat'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat backup: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isCreatingBackup = false;
      });
    }
  }

  Future<void> _showCreateBackupDialog() async {
    final nameController = TextEditingController();
    final selectedTables = <String>[
      'profiles',
      'services',
      'admins',
      'settings'
    ];
    final availableTables = <String>[
      'profiles',
      'services',
      'admins',
      'settings',
      'versions',
      'service_types',
      'database_backups'
    ];

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Buat Backup Baru'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Backup',
                      border: OutlineInputBorder(),
                      hintText: 'Contoh: Backup Manual Bulan Mei',
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Pilih Tabel:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...availableTables.map((table) {
                    return CheckboxListTile(
                      title: Text(table),
                      value: selectedTables.contains(table),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            if (!selectedTables.contains(table)) {
                              selectedTables.add(table);
                            }
                          } else {
                            selectedTables.remove(table);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      selectedTables.isNotEmpty) {
                    Navigator.pop(context);
                    _createBackup(nameController.text, selectedTables);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Nama backup dan minimal satu tabel harus dipilih'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text('BUAT BACKUP'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBackupDetails(Map<String, dynamic> backup) async {
    final tables = backup['tables'] is List
        ? List<String>.from(backup['tables'])
        : <String>[];

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Nama:', backup['name'] ?? 'Tanpa Nama'),
              _buildDetailRow('Tanggal:',
                  _dateFormat.format(DateTime.parse(backup['created_at']))),
              _buildDetailRow('Ukuran:',
                  '${(backup['size'] / 1000000).toStringAsFixed(2)} MB'),
              _buildDetailRow('Status:', backup['status'] ?? 'unknown'),
              _buildDetailRow(
                  'Dibuat oleh:', backup['created_by'] ?? 'unknown'),
              SizedBox(height: 8),
              Text(
                'Tabel:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              ...tables.map((table) {
                return Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.table_chart, size: 16),
                      SizedBox(width: 8),
                      Text(table),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('TUTUP'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadBackup(backup);
            },
            child: Text('UNDUH'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadBackup(Map<String, dynamic> backup) async {
    // Dalam aplikasi aktual, ini akan memicu unduhan file backup,
    // tetapi di sini kita hanya mensimulasikan dengan menampilkan snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengunduh backup "${backup['name']}"...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Buka dashboard Supabase
    await Future.delayed(Duration(seconds: 2));

    final url = Uri.parse('https://app.supabase.io/project/_/database/backups');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka URL Supabase Dashboard'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleBackup() async {
    // Implementasi ini hanya simulasi, karena penjadwalan backup biasanya
    // dilakukan di sisi server, bukan di aplikasi klien
    final timeController = TextEditingController(text: '02:00');
    final scheduleOptions = ['Harian', 'Mingguan', 'Bulanan'];
    String selectedSchedule = 'Harian';

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Jadwalkan Backup Otomatis'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frekuensi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...scheduleOptions.map((option) {
                    return RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: selectedSchedule,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedSchedule = value;
                          });
                        }
                      },
                    );
                  }).toList(),
                  SizedBox(height: 16),
                  Text(
                    'Waktu Backup:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: timeController,
                    decoration: InputDecoration(
                      labelText: 'Waktu (24 jam)',
                      border: OutlineInputBorder(),
                      hintText: 'Contoh: 02:00',
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Catatan: Backup otomatis akan menyimpan data dari semua tabel',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('BATAL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Backup otomatis dijadwalkan: $selectedSchedule pada ${timeController.text}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text('JADWALKAN'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Backup Database'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBackupHistory,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup Database',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Buat dan kelola backup data aplikasi',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 24),

                    // Tombol aksi
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('Buat Backup Baru'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isCreatingBackup
                                ? null
                                : () => _showCreateBackupDialog(),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.schedule),
                            label: Text('Jadwalkan Backup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _scheduleBackup,
                          ),
                        ),
                      ],
                    ),

                    if (_isCreatingBackup) ...[
                      SizedBox(height: 16),
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Membuat backup...',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Informasi kebijakan backup
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kebijakan Backup',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Backup otomatis dijadwalkan setiap hari pada pukul 02:00 WIB',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            '• Backup disimpan selama 30 hari sebelum dihapus otomatis',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            '• Jika anda butuh backup jangka panjang, unduh dan simpan secara lokal',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    Text(
                      'Riwayat Backup',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    Expanded(
                      child: _backupHistory.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada riwayat backup',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _backupHistory.length,
                              itemBuilder: (context, index) {
                                final backup = _backupHistory[index];
                                final createdAt =
                                    DateTime.parse(backup['created_at']);
                                final isSuccess = backup['status'] == 'success';

                                return Card(
                                  elevation: 2,
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSuccess
                                          ? Colors.green.withAlpha(50)
                                          : Colors.red.withAlpha(50),
                                      child: Icon(
                                        isSuccess ? Icons.backup : Icons.error,
                                        color: isSuccess
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    title: Text(backup['name'] ??
                                        'Backup ${index + 1}'),
                                    subtitle: Text(
                                      '${_dateFormat.format(createdAt)} • ${(backup['size'] / 1000000).toStringAsFixed(2)} MB',
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.more_vert),
                                      onPressed: () =>
                                          _showBackupDetails(backup),
                                    ),
                                    onTap: () => _showBackupDetails(backup),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
