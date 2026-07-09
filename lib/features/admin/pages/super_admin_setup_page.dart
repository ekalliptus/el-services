import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:servicehponline/core/services/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperAdminSetupPage extends StatefulWidget {
  const SuperAdminSetupPage({Key? key}) : super(key: key);

  @override
  State<SuperAdminSetupPage> createState() => _SuperAdminSetupPageState();
}

class _SuperAdminSetupPageState extends State<SuperAdminSetupPage> {
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isShowingPassword = false;
  String? _errorMessage;
  bool _superAdminCreated = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUser() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        // Periksa apakah user sudah terdaftar sebagai super_admin
        try {
          final response = await SupabaseConfig.client
              .from('admins')
              .select()
              .eq('id', user.id)
              .eq('role', 'super_admin')
              .maybeSingle();

          if (!mounted) return;
          setState(() {
            _superAdminCreated = response != null;
          });
          print(
              'User sudah terdaftar sebagai super_admin: $_superAdminCreated');
        } catch (e) {
          print('Error memeriksa status super_admin: $e');
        }
      } else {
        print('Tidak ada user yang login saat ini');
      }
    } catch (e) {
      print('Error memeriksa user saat ini: $e');
    }
  }

  Future<void> _createSuperAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Buat user baru di Supabase Auth
      // ponytail: role 'super_admin' ditulis dari client dengan anon key —
      // rawan privilege escalation. Perlu proteksi server-side/RLS (buat lewat
      // Edge Function service_role + validasi bootstrap secret). Lihat
      // SECURITY-PAYMENT.md. Selain itu signUp() dapat menggantikan sesi login
      // aktif dengan akun baru.
      final response = await SupabaseConfig.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Gagal membuat akun super admin');
      }

      final newUserId = response.user!.id;
      print('User berhasil dibuat dengan ID: $newUserId');

      // 2. Cek apakah tabel admins sudah ada dan tambahkan user sebagai super_admin
      try {
        // Coba tambahkan entri di tabel admins
        await SupabaseConfig.client.from('admins').upsert({
          'id': newUserId,
          'email': _emailController.text,
          'role': 'super_admin',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('Super admin berhasil ditambahkan ke tabel admins');
      } catch (e) {
        if (e.toString().contains('relation "admins" does not exist') ||
            e.toString().contains('column "role" does not exist')) {
          // Jika tabel admins belum ada atau belum memiliki kolom role
          try {
            // Alternatif: Tambahkan kolom role ke tabel admins
            await SupabaseConfig.client.rpc('add_role_column', params: {});
            print('Kolom role berhasil ditambahkan ke tabel admins');

            // Coba insert lagi
            await SupabaseConfig.client.from('admins').insert({
              'id': newUserId,
              'email': _emailController.text,
              'role': 'super_admin',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            if (!mounted) return;
            setState(() {
              _superAdminCreated = true;
            });
            print(
                'Super admin berhasil ditambahkan setelah menambah kolom role');
          } catch (alterError) {
            print('Gagal menambahkan kolom role: $alterError');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Tabel admins tidak memiliki kolom role. Silakan tambahkan kolom secara manual di dashboard Supabase.'),
              backgroundColor: Colors.red,
            ));
          }
        } else {
          throw e;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Akun Super Admin berhasil dibuat!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error membuat super admin: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat akun: ${e.toString()}'),
          backgroundColor: Colors.red,
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

  Future<void> _openSupabaseDashboard() async {
    final url = Uri.parse('https://app.supabase.com/project/_/storage/buckets');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak dapat membuka URL: $url')),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disalin ke clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Super Admin'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Panel
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
                    'Panduan Setup Super Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Halaman ini digunakan untuk setup akun Super Admin yang memiliki akses untuk mengelola update aplikasi (APK) dan fitur-fitur administratif lainnya.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Step 1: Buat Akun Super Admin
            Text(
              'Langkah 1: Buat Akun Super Admin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            if (_superAdminCreated)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Akun Super Admin Sudah Dibuat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                        'Anda sudah membuat akun Super Admin dan dapat melanjutkan ke langkah berikutnya.'),
                  ],
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Super Admin',
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan email untuk akun super admin',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Masukkan email yang valid';
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
                        border: OutlineInputBorder(),
                        hintText: 'Minimal 6 karakter',
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
                    if (_errorMessage != null)
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createSuperAdmin,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            )
                          : Text('Buat Akun Super Admin'),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 32),

            // Step 2: Configure Storage Bucket
            Text(
              'Langkah 2: Konfigurasi Bucket Storage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Buka Dashboard Supabase',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _openSupabaseDashboard,
                    icon: Icon(Icons.open_in_new),
                    label: Text('Buka Dashboard Supabase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '2. Buat Bucket Storage Baru',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('- Buka menu Storage di sidebar'),
                  Text('- Klik tombol "New Bucket"'),
                  Text('- Masukkan nama bucket: "updates"'),
                  Text('- Centang opsi "Public bucket"'),
                  Text('- Klik "Create bucket"'),
                  SizedBox(height: 16),
                  Text(
                    '3. Setup Kebijakan RLS (Row Level Security)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('- Klik tab "Policies" di bucket yang baru dibuat'),
                  Text('- Klik "Add policies" atau "New policy"'),
                  Text('- Gunakan pengaturan berikut untuk setiap kebijakan:'),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'CREATE POLICY "Super Admin dapat mengakses storage" ON storage.objects FOR ALL USING (auth.uid() IN (SELECT id FROM admins WHERE role = \'super_admin\'));',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy, size: 16),
                              onPressed: () => _copyToClipboard(
                                'CREATE POLICY "Super Admin dapat mengakses storage" ON storage.objects FOR ALL USING (auth.uid() IN (SELECT id FROM admins WHERE role = \'super_admin\'));',
                              ),
                              tooltip: 'Salin ke clipboard',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '4. Perbarui Tabel Admins (jika belum ada)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Periksa user ID di tabel "admins":'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      'SELECT * FROM admins WHERE id = \'${SupabaseConfig.client.auth.currentUser?.id ?? ""}\';',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('2. Set role menjadi super_admin:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      'UPDATE admins SET role = \'super_admin\' WHERE id = \'${SupabaseConfig.client.auth.currentUser?.id ?? ""}\';',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                      '3. Jalankan SQL berikut untuk membuat tabel admins jika belum ada:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      'CREATE TABLE IF NOT EXISTS admins (\n  id UUID PRIMARY KEY,\n  user_id UUID NOT NULL,\n  email TEXT,\n  role TEXT DEFAULT \'admin\',\n  created_at TIMESTAMPTZ DEFAULT NOW(),\n  updated_at TIMESTAMPTZ DEFAULT NOW()\n);',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, size: 16),
                        onPressed: () => _copyToClipboard(
                          'CREATE TABLE IF NOT EXISTS admins (\n  id UUID PRIMARY KEY,\n  user_id UUID NOT NULL,\n  email TEXT,\n  role TEXT DEFAULT \'admin\',\n  created_at TIMESTAMPTZ DEFAULT NOW(),\n  updated_at TIMESTAMPTZ DEFAULT NOW()\n);',
                        ),
                        tooltip: 'Salin ke clipboard',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                      '4. Jalankan SQL berikut untuk menambahkan kolom role ke tabel admins:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      'ALTER TABLE admins ADD COLUMN IF NOT EXISTS role TEXT DEFAULT \'admin\';',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.copy, size: 16),
                        onPressed: () => _copyToClipboard(
                          'ALTER TABLE admins ADD COLUMN IF NOT EXISTS role TEXT DEFAULT \'admin\';',
                        ),
                        tooltip: 'Salin ke clipboard',
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text('5. Buat fungsi untuk membantu menambahkan kolom role:'),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      'CREATE OR REPLACE FUNCTION add_role_column()\nRETURNS void AS\n\$\$\nBEGIN\n  ALTER TABLE admins ADD COLUMN IF NOT EXISTS role TEXT DEFAULT \'admin\';\nEND;\n\$\$ LANGUAGE plpgsql;',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Step 3: Login as Super Admin
            Text(
              'Langkah 3: Login sebagai Super Admin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setelah membuat akun Super Admin dan mengkonfigurasi bucket storage:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text('1. Logout dari aplikasi'),
                  Text(
                      '2. Login kembali menggunakan email dan password Super Admin'),
                  Text(
                      '3. Akses fitur "Kelola Versi Aplikasi" dari menu admin'),
                  SizedBox(height: 16),
                  Text(
                    'Catatan: Hanya akun dengan role "super_admin" yang dapat mengakses fitur update aplikasi karena kebijakan RLS yang telah diatur.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
