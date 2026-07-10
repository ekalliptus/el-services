import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/core/theme/app_colors.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({Key? key}) : super(key: key);

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _adminList = [];
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isShowingPassword = false;
  bool _isSuperAdmin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdminList();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SupabaseConfig.client.from('admins').select('*');

      if (!mounted) return;
      setState(() {
        _adminList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat daftar admin: $e'),
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

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Buat user baru di Supabase Auth
      // ponytail: auth.admin.* butuh service_role key — TIDAK boleh dipanggil
      // dari client. Pindahkan pembuatan/penghapusan user ke Edge Function
      // server-side yang memegang service_role & mengotorisasi pemanggil.
      // Lihat SECURITY-PAYMENT.md.
      final response = await SupabaseConfig.client.auth.admin.createUser(
        AdminUserAttributes(
          email: _emailController.text,
          password: _passwordController.text,
          emailConfirm: true,
        ),
      );

      if (response.user == null) {
        throw Exception('Gagal membuat akun admin');
      }

      final userId = response.user!.id;

      // 2. Tambahkan ke tabel admins
      await SupabaseConfig.client.from('admins').insert({
        'id': userId,
        'user_id': userId,
        'email': _emailController.text,
        'role': _isSuperAdmin ? 'super_admin' : 'admin',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin baru berhasil ditambahkan'),
          backgroundColor: AppColors.success,
        ),
      );

      // Reset form dan reload data
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _isSuperAdmin = false;
      });

      _loadAdminList();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan admin: $e'),
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

  Future<void> _deleteAdmin(String id, String email) async {
    // Konfirmasi penghapusan
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Admin'),
        content: Text('Yakin ingin menghapus admin dengan email $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // Cegah lockout: jangan hapus akun sendiri.
    final currentUid = SupabaseConfig.client.auth.currentUser?.id;
    if (currentUid != null && currentUid == id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anda tidak dapat menghapus akun Anda sendiri'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Cegah lockout: jangan hapus super_admin terakhir.
      final target = await SupabaseConfig.client
          .from('admins')
          .select('role')
          .eq('id', id)
          .maybeSingle();
      if (target != null && target['role'] == 'super_admin') {
        final superAdmins = await SupabaseConfig.client
            .from('admins')
            .select('id')
            .eq('role', 'super_admin');
        if ((superAdmins as List).length <= 1) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat menghapus super admin terakhir'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Hapus dari tabel admins
      await SupabaseConfig.client.from('admins').delete().eq('id', id);

      // Hapus user dari Auth (opsional, tergantung kebutuhan)
      // ponytail: auth.admin.deleteUser butuh service_role — pindahkan ke
      // Edge Function server-side. Lihat SECURITY-PAYMENT.md.
      await SupabaseConfig.client.auth.admin.deleteUser(id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin berhasil dihapus'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadAdminList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus admin: $e'),
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

  Future<void> _toggleSuperAdminStatus(String id, bool currentStatus) async {
    // Cegah lockout: menurunkan super_admin terakhir / diri sendiri.
    if (currentStatus) {
      final currentUid = SupabaseConfig.client.auth.currentUser?.id;
      if (currentUid != null && currentUid == id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Anda tidak dapat menurunkan status Anda sendiri'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (currentStatus) {
        final superAdmins = await SupabaseConfig.client
            .from('admins')
            .select('id')
            .eq('role', 'super_admin');
        if ((superAdmins as List).length <= 1) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Harus ada minimal satu super admin'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      await SupabaseConfig.client.from('admins').update({
        'role': currentStatus ? 'admin' : 'super_admin',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status Super Admin berhasil diubah'),
          backgroundColor: AppColors.success,
        ),
      );

      _loadAdminList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status: $e'),
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

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tambah Admin Baru'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Email tidak valid';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isShowingPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isShowingPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _isShowingPassword = !_isShowingPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _isSuperAdmin,
                      onChanged: (value) {
                        setState(() {
                          _isSuperAdmin = value ?? false;
                        });
                      },
                    ),
                    Text('Jadikan Super Admin'),
                  ],
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _emailController.clear();
              _passwordController.clear();
              setState(() {
                _isSuperAdmin = false;
                _errorMessage = null;
              });
            },
            child: Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context);
                _addAdmin();
              }
            },
            child: Text('TAMBAH'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Admin'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAdminList,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Admin',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: _adminList.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada admin terdaftar',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _adminList.length,
                              itemBuilder: (context, index) {
                                final admin = _adminList[index];
                                final isSuperAdmin =
                                    admin['role'] == 'super_admin';

                                return Card(
                                  elevation: 2,
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSuperAdmin
                                          ? Colors.purple.withAlpha(50)
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                      child: Icon(
                                        Icons.person,
                                        color: isSuperAdmin
                                            ? Colors.purple
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                    ),
                                    title:
                                        Text(admin['email'] ?? 'Unknown Email'),
                                    subtitle: Text(
                                      isSuperAdmin ? 'Super Admin' : 'Admin',
                                      style: TextStyle(
                                        color: isSuperAdmin
                                            ? Colors.purple
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: isSuperAdmin,
                                          onChanged: (value) {
                                            _toggleSuperAdminStatus(
                                                admin['id'], isSuperAdmin);
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error),
                                          onPressed: () {
                                            _deleteAdmin(
                                                admin['id'], admin['email']);
                                          },
                                          tooltip: 'Hapus Admin',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAdminDialog,
        tooltip: 'Tambah Admin',
        child: Icon(Icons.add),
      ),
    );
  }
}
