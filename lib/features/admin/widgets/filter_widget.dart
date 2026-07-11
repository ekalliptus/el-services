import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:servicehponline/features/admin/models/service_filter_model.dart';

class FilterWidget extends StatelessWidget {
  final String selectedFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(String) onFilterChanged;
  final VoidCallback onShowDateRangePicker;
  final VoidCallback? onClearDateRange;

  const FilterWidget({
    Key? key,
    required this.selectedFilter,
    this.startDate,
    this.endDate,
    required this.onFilterChanged,
    required this.onShowDateRangePicker,
    this.onClearDateRange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filters = ServiceFilterModel.getFilterList();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tampilkan tanggal jika ada dan label Filter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (startDate != null && endDate != null)
                  Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Chip(
                      label: Text(
                        '${DateFormat('dd/MM/yyyy').format(startDate!)} - ${DateFormat('dd/MM/yyyy').format(endDate!)}',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      onDeleted: onClearDateRange,
                    ),
                  ),
                Text(
                  'Filter:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Buat scroll horizontal untuk filter options
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...filters.map((filter) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            filter.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: selectedFilter == filter.filterKey
                                  ? filter.textColor
                                  : null,
                            ),
                          ),
                          selected: selectedFilter == filter.filterKey,
                          selectedColor: filter.selectedColor,
                          onSelected: (selected) {
                            if (selected) {
                              onFilterChanged(filter.filterKey);
                            }
                          },
                        ),
                      )),
                  // Tambahkan tombol filter tanggal
                  SizedBox(width: 8),
                  Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: InkWell(
                      onTap: onShowDateRangePicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Tanggal',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
