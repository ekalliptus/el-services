import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:servicehponline/features/user/pages/service_history_page.dart';

class TestimonialPage extends StatefulWidget {
  final Map<String, dynamic> service;
  final int rating;
  final bool isUpdate;

  const TestimonialPage({
    Key? key,
    required this.service,
    required this.rating,
    this.isUpdate = false,
  }) : super(key: key);

  @override
  State<TestimonialPage> createState() => _TestimonialPageState();
}

class _TestimonialPageState extends State<TestimonialPage> {
  final _supabase = Supabase.instance.client;
  final _auth = firebase_auth.FirebaseAuth.instance;
  final _testimonialController = TextEditingController();
  bool _isSubmitting = false;
  String? _previousTestimonial;
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;
    if (widget.isUpdate) {
      _loadPreviousTestimonial();
    }
  }

  Future<void> _loadPreviousTestimonial() async {
    try {
      final testimonial = await _supabase
          .from('testimonials')
          .select('content')
          .eq('service_id', widget.service['id'])
          .single();

      if (!mounted) return;
      setState(() {
        _previousTestimonial = testimonial['content'];
        _testimonialController.text = _previousTestimonial ?? '';
      });
    } catch (e) {
      print('Error loading previous testimonial: $e');
    }
  }

  // Ambil inisial nama secara aman: lewati string kosong agar tidak terjadi
  // RangeError saat mengindeks [0].
  String _initialNama(dynamic customerName, String? displayName) {
    final c = customerName?.toString().trim() ?? '';
    if (c.isNotEmpty) return c[0].toUpperCase();
    final d = displayName?.trim() ?? '';
    if (d.isNotEmpty) return d[0].toUpperCase();
    return 'A';
  }

  Widget _buildAvatar(Map<String, dynamic> service, firebase_auth.User? user) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: user?.photoURL != null
            ? Colors.transparent
            : colorScheme.primary,
      ),
      child: CircleAvatar(
        backgroundColor: user?.photoURL != null
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Text(
                _initialNama(service['customer_name'], user?.displayName),
                style: GoogleFonts.poppins(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _testimonialController.dispose();
    super.dispose();
  }

  Future<void> _submitTestimonial() async {
    if (_testimonialController.text.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Peringatan',
        desc: 'Mohon isi testimoni Anda',
        btnOkColor: Theme.of(context).colorScheme.error,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        throw Exception(
            'Silakan login terlebih dahulu untuk memberikan testimoni');
      }

      if (widget.service['id'] == null) {
        throw Exception('Data service tidak valid');
      }

      if (widget.rating < 1 || widget.rating > 5) {
        throw Exception('Rating harus antara 1-5');
      }

      final deviceInfo =
          widget.service['device']?.toString().toLowerCase() == 'android'
              ? '${widget.service['brand']} - ${widget.service['model']}'
              : '${widget.service['brand']} - ${widget.service['model']}';

      final testimonialData = {
        'service_id': widget.service['id'],
        'user_id': firebaseUser.uid,
        'rating': _currentRating,
        'content': _testimonialController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'fullname': widget.service['customer_name'] ??
            firebaseUser.displayName ??
            firebaseUser.email?.split('@')[0] ??
            'Anonymous',
        'device': deviceInfo,
        'photo_url': firebaseUser.photoURL,
      };

      try {
        if (widget.isUpdate) {
          // Update testimoni yang sudah ada
          await _supabase
              .from('testimonials')
              .update(testimonialData)
              .eq('service_id', widget.service['id'])
              .eq('user_id', firebaseUser.uid);
        } else {
          // Insert testimoni baru
          await _supabase
              .from('testimonials')
              .insert(testimonialData)
              .select()
              .single();
        }

        if (!mounted) return;

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          dismissOnTouchOutside: false,
          dismissOnBackKeyPress: false,
          title: 'Berhasil',
          desc: widget.isUpdate
              ? 'Testimoni Anda berhasil diperbarui'
              : 'Terima kasih atas testimoni Anda',
          btnOkColor: Theme.of(context).colorScheme.primary,
          btnOkText: 'OK',
          btnOkOnPress: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceHistoryPage(),
              ),
              (route) => false,
            );
          },
        ).show();
      } catch (e) {
        print(
            'Error detail saat ${widget.isUpdate ? "update" : "insert"} ke Supabase: $e');
        throw Exception(
            'Gagal ${widget.isUpdate ? "memperbarui" : "menyimpan"} testimoni ke database');
      }
    } catch (e, stackTrace) {
      print('Error saat mengirim testimoni: $e');
      print('Stack trace: $stackTrace');

      if (!mounted) return;

      String errorMessage = 'Gagal mengirim testimoni. ';
      if (e.toString().contains('login')) {
        errorMessage += 'Silakan login terlebih dahulu.';
      } else if (e.toString().contains('service')) {
        errorMessage += 'Data service tidak valid.';
      } else if (e.toString().contains('rating')) {
        errorMessage += 'Rating tidak valid.';
      } else {
        errorMessage += 'Silakan coba lagi nanti.';
      }

      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'Error',
        desc: errorMessage,
        btnOkColor: Theme.of(context).colorScheme.error,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) {
          return false;
        }

        if (_testimonialController.text.isNotEmpty) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Batalkan Testimoni?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'TIDAK',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  // Hanya tutup dialog dengan hasil true; navigasi halaman
                  // dilakukan sekali oleh pemanggil (hindari pop ganda).
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'YA',
                    style: GoogleFonts.poppins(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () async {
              if (_isSubmitting) return;

              if (_testimonialController.text.isNotEmpty) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Batalkan Testimoni?',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: Text(
                      'Data yang telah diisi akan hilang. Anda yakin ingin membatalkan?',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'TIDAK',
                          style: GoogleFonts.poppins(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        // Hanya tutup dialog dengan hasil true; halaman
                        // di-pop sekali oleh pemanggil di bawah.
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'YA',
                          style: GoogleFonts.poppins(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if ((shouldPop ?? false) && mounted) {
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            widget.isUpdate ? 'Update Testimoni' : 'Tulis Testimoni',
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildAvatar(widget.service, currentUser),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service #${widget.service['id']}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.service['device']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'android'
                                  ? '${widget.service['brand']} - ${widget.service['model']}'
                                  : '${widget.service['brand']} - ${widget.service['model']}',
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Rating Anda',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(
                  5,
                  (index) => GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentRating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
                      child: Icon(
                        index < _currentRating ? Icons.star : Icons.star_border,
                        color: AppColors.warning,
                        size: MediaQuery.of(context).size.width < 360 ? 20 : 28,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (widget.isUpdate && _previousTestimonial != null) ...[
                Text(
                  'Testimoni Sebelumnya',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Text(
                    _previousTestimonial!,
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
              Text(
                widget.isUpdate ? 'Update Testimoni' : 'Testimoni',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _testimonialController,
                maxLines: 5,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  hintText: widget.isUpdate
                      ? 'Tulis testimoni baru Anda...'
                      : 'Bagikan pengalaman Anda...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: _isSubmitting
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHigh,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTestimonial,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor:
                        colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary),
                          ),
                        )
                      : Text(
                          widget.isUpdate
                              ? 'Update Testimoni'
                              : 'Kirim Testimoni',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
