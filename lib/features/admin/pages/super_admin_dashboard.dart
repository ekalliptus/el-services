import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:servicehponline/features/admin/pages/app_version_manager_page.dart';
import 'package:servicehponline/features/admin/pages/admin_management_page.dart';
import 'package:servicehponline/features/admin/pages/system_settings_page.dart';
import 'package:servicehponline/features/admin/pages/database_backup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servicehponline/features/auth/pages/login_page.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/core/widgets/widgets.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  bool _isLoading = false;
  String _adminEmail = '';
  String _adminId = '';

  @override
  void initState() {
    super.initState();
    _getCurrentAdmin();
  }

  Future<void> _getCurrentAdmin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _adminEmail = user.email ?? 'Unknown Email';
          _adminId = user.id;
        });

        // Cek apakah user memiliki akses
        final adminCheck = await SupabaseConfig.client
            .from('admins')
            .select()
            .eq('id', user.id)
            .eq('role', 'super_admin')
            .maybeSingle();

        if (adminCheck == null) {
          print('Bukan super admin, arahkan kembali ke login');
          _handleLogout();
        }
      } else {
        print('Tidak ada user yang login, arahkan kembali ke login');
        _handleLogout();
      }
    } catch (e) {
      print('Error mendapatkan data admin: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan saat memuat data: $e'),
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

  Future<void> _handleLogout() async {
    try {
      await SupabaseConfig.client.auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_logged_in');
      await prefs.remove('admin_session');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Home()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error saat logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnrWordmark(fontSize: 22),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Info Panel
                    AnrCard(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Super Admin Area',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('Email: $_adminEmail'),
                          Text('ID: $_adminId'),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Main Menu Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      children: [
                        // App Version Manager Card
                        _buildMenuCard(
                          icon: Icons.system_update,
                          title: 'Kelola Versi Aplikasi',
                          color: AppColors.success,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AppVersionManagerPage(),
                              ),
                            );
                          },
                        ),

                        // Admin Management Card
                        _buildMenuCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Kelola Admin',
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminManagementPage(),
                              ),
                            );
                          },
                        ),

                        // System Settings Card
                        _buildMenuCard(
                          icon: Icons.settings,
                          title: 'Pengaturan Sistem',
                          color: AppColors.warning,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SystemSettingsPage(),
                              ),
                            );
                          },
                        ),

                        // Database Backup Card
                        _buildMenuCard(
                          icon: Icons.backup,
                          title: 'Backup Database',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DatabaseBackupPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // System Status Panel
                    AnrCard(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Sistem',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: AppColors.success),
                              SizedBox(width: 8),
                              Text('Database: Terhubung'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: AppColors.success),
                              SizedBox(width: 8),
                              Text('Storage: Terhubung'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnrCard(
      onTap: onTap,
      color: color.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: color,
          ),
          SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
