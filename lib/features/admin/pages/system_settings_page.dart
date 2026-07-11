import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:servicehponline/core/theme/theme_provider.dart';
import 'package:servicehponline/core/widgets/widgets.dart';
import 'package:servicehponline/features/maintenance/maintenance_manager_page.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({Key? key}) : super(key: key);

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan Sistem'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul halaman
                    Text(
                      'Pengaturan Sistem',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kelola berbagai pengaturan sistem aplikasi',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 24),

                    // Daftar pengaturan
                    _buildSettingsSection(
                      title: 'Operasional',
                      settings: [
                        _buildSettingItem(
                          icon: Icons.engineering,
                          title: 'Mode Maintenance',
                          description:
                              'Aktifkan mode maintenance saat melakukan perbaikan sistem',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MaintenanceManagerPage(),
                              ),
                            );
                          },
                        ),
                        // Tambahkan pengaturan operasional lainnya di sini
                      ],
                    ),

                    _buildSettingsSection(
                      title: 'Keamanan',
                      settings: [
                        _buildSettingItem(
                          icon: Icons.security,
                          title: 'Kebijakan Kata Sandi',
                          description:
                              'Atur kebijakan kata sandi untuk pengguna',
                          onTap: () {
                            // Fitur belum diimplementasikan
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Fitur ini belum tersedia'),
                              ),
                            );
                          },
                        ),
                        // Tambahkan pengaturan keamanan lainnya di sini
                      ],
                    ),

                    _buildSettingsSection(
                      title: 'Tampilan',
                      settings: [
                        _buildSettingItem(
                          icon: Icons.color_lens,
                          title: 'Tema Aplikasi',
                          description: 'Pilih sistem, terang, atau gelap',
                          onTap: _showThemePicker,
                        ),
                        // Tambahkan pengaturan tampilan lainnya di sini
                      ],
                    ),

                    _buildSettingsSection(
                      title: 'Data',
                      settings: [
                        _buildSettingItem(
                          icon: Icons.backup,
                          title: 'Backup Database',
                          description: 'Buat backup data aplikasi',
                          onTap: () {
                            // Fitur belum diimplementasikan
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Fitur ini belum tersedia'),
                              ),
                            );
                          },
                        ),
                        // Tambahkan pengaturan data lainnya di sini
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showThemePicker() {
    final provider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AnrSectionHeader(
                title: 'Tema Aplikasi',
                subtitle: 'Pilih tampilan yang nyaman untukmu.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('Sistem'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Terang'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Gelap'),
                    ),
                  ],
                  selected: {provider.mode},
                  onSelectionChanged: (modes) async {
                    await provider.setMode(modes.first);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> settings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 12),
        ...settings,
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
