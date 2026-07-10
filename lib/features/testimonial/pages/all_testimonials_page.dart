import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:servicehponline/core/theme/app_colors.dart';
import 'package:servicehponline/data/models/device_problems.dart';

class AllTestimonialsPage extends StatefulWidget {
  const AllTestimonialsPage({Key? key}) : super(key: key);

  @override
  State<AllTestimonialsPage> createState() => _AllTestimonialsPageState();
}

class _AllTestimonialsPageState extends State<AllTestimonialsPage> {
  final _supabase = Supabase.instance.client;
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _testimonials = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadTestimonials();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTestimonials({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _testimonials.clear();
        _page = 1;
        _hasMore = true;
      }
    });

    try {
      final response = await _supabase
          .from('testimonials')
          .select()
          .order('created_at', ascending: false)
          .range((_page - 1) * _limit, _page * _limit - 1);

      setState(() {
        if (response.isEmpty) {
          _hasMore = false;
        } else {
          _testimonials.addAll(List<Map<String, dynamic>>.from(response));
          _page++;
          // Cek apakah masih ada data selanjutnya
          _hasMore = response.length >= _limit;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading testimonials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat testimoni'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.95 &&
        !_isLoading &&
        _hasMore) {
      _loadTestimonials();
    }
  }

  // Ambil inisial nama secara aman (hindari RangeError pada string kosong/null).
  String _initialFrom(dynamic name) {
    final s = name?.toString().trim() ?? '';
    return s.isNotEmpty ? s[0].toUpperCase() : '?';
  }

  // Format tanggal secara defensif; kembalikan '-' bila null/format salah.
  String _formatTanggal(dynamic value) {
    final ts = DateTime.tryParse(value?.toString() ?? '');
    return ts == null ? '-' : DateFormat('dd MMM yyyy').format(ts);
  }

  Widget _buildAvatar(Map<String, dynamic> testimonial) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: testimonial['photo_url'] != null
            ? Colors.transparent
            : colorScheme.primary,
        border: Border.all(
          color: colorScheme.outline,
          width: 1,
        ),
      ),
      child: CircleAvatar(
        backgroundColor: testimonial['photo_url'] != null
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        backgroundImage: testimonial['photo_url'] != null
            ? NetworkImage(testimonial['photo_url'])
            : null,
        child: testimonial['photo_url'] == null
            ? Text(
                _initialFrom(testimonial['fullname']),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Semua Testimoni',
          style: GoogleFonts.poppins(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTestimonials(refresh: true),
        child: _testimonials.isEmpty && !_isLoading
            ? Center(
                child: Text(
                  'Belum ada testimoni',
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount:
                    _testimonials.length + (_hasMore && _isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _testimonials.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final testimonial = _testimonials[index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(testimonial),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    testimonial['fullname']?.toString() ??
                                        'Anonim',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DeviceProblems.formatDeviceName(
                                        testimonial),
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              _formatTanggal(testimonial['created_at']),
                              style: GoogleFonts.poppins(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 2,
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < (testimonial['rating'] ?? 0)
                                  ? Icons.star
                                  : Icons.star_border,
                              color: AppColors.warning,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          testimonial['content']?.toString() ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
