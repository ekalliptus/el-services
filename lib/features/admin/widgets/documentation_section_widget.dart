import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:servicehponline/features/admin/dialogs/documentation_preview_dialog.dart';

class DocumentationSectionWidget extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(bool)? onUploadingDoc; // Callback untuk status upload

  const DocumentationSectionWidget({
    Key? key,
    required this.service,
    this.onUploadingDoc,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Dokumentasi biasa dari service
    Map<String, List<Map<String, dynamic>>> serviceDocs = {
      'damage': [], // Foto Kerusakan
      'front': [], // Foto Tampak Depan
      'back': [], // Foto Tampak Belakang
      'video': [], // Video
    };

    // Kategorikan foto berdasarkan jenisnya
    if (service['picture_damage_url'] != null) {
      serviceDocs['damage']!.add(
          {'file_type': 'image', 'file_url': service['picture_damage_url']});
    }
    if (service['picture_front_url'] != null) {
      serviceDocs['front']!.add(
          {'file_type': 'image', 'file_url': service['picture_front_url']});
    }
    if (service['picture_back_url'] != null) {
      serviceDocs['back']!
          .add({'file_type': 'image', 'file_url': service['picture_back_url']});
    }
    if (service['video_url'] != null) {
      serviceDocs['video']!
          .add({'file_type': 'video', 'file_url': service['video_url']});
    }

    // Dokumentasi dari komplain
    List<Map<String, dynamic>> complaintDocs = [];
    final complaints = service['complaints'];
    if (complaints != null && complaints is List) {
      for (var complaint in complaints) {
        if (complaint['photo_url'] != null) {
          complaintDocs.add({
            'file_type': 'image',
            'file_url': complaint['photo_url'],
            'created_at': complaint['created_at']
          });
        }
        if (complaint['video_url'] != null) {
          complaintDocs.add({
            'file_type': 'video',
            'file_url': complaint['video_url'],
            'created_at': complaint['created_at']
          });
        }
      }
    }

    bool hasServiceDocs = serviceDocs.values.any((list) => list.isNotEmpty);
    if (!hasServiceDocs && complaintDocs.isEmpty) {
      return Text(
        'Belum ada dokumentasi',
        style: GoogleFonts.poppins(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasServiceDocs) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dokumentasi Service',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.primary,
                  ),
                ),
                if (serviceDocs['damage']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Kerusakan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(context, serviceDocs['damage']!),
                ],
                if (serviceDocs['front']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Tampak Depan',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(context, serviceDocs['front']!),
                ],
                if (serviceDocs['back']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Foto Tampak Belakang',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(context, serviceDocs['back']!),
                ],
                if (serviceDocs['video']!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Video',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(context, serviceDocs['video']!),
                ],
              ],
            ),
          ),
        ],
        if (service['complain'] == true) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Komplain',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colorScheme.error,
                  ),
                ),
                SizedBox(height: 8),
                if (complaints != null &&
                    complaints.isNotEmpty &&
                    complaints[0]['created_at'] != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatDate(complaints[0]['created_at']),
                        style: GoogleFonts.poppins(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                ],
                Text(
                  complaints != null &&
                          complaints.isNotEmpty &&
                          complaints[0]['description'] != null
                      ? complaints[0]['description']
                      : 'Tidak ada deskripsi komplain',
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (complaintDocs.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Dokumentasi Komplain',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colorScheme.error,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDocumentationGrid(context, complaintDocs),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentationGrid(
      BuildContext context, List<Map<String, dynamic>> docs) {
    final colorScheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isVideo = doc['file_type'] == 'video';
        final url = doc['file_url'];
        final createdAt = doc['created_at'];

        return InkWell(
          onTap: () => showDocumentationPreview(context, url, isVideo),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              image: !isVideo && url != null
                  ? DecorationImage(
                      image: NetworkImage(url),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black87,
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVideo ? 'Video' : 'Foto',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (createdAt != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }
}
