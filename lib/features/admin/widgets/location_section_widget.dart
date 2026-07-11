import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:servicehponline/features/user/widgets/mobile_map_picker_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationSectionWidget extends StatelessWidget {
  final Map<String, dynamic> service;

  // Koordinat Service Center
  final serviceCenterPosition = Position(
    latitude: -6.151882179907883,
    longitude: 106.92619538817382,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  LocationSectionWidget({
    Key? key,
    required this.service,
  }) : super(key: key);

  // Koersi nilai dinamis (int/double/String) menjadi double; null bila gagal.
  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (service['shipping_method'] == 'antar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Service Center',
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.0),
          MapPicker(
            initialPosition: serviceCenterPosition,
            onPositionChanged: (_) {},
            isInteractive: false,
          ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: colorScheme.error,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jl. Raya Kalimalang No.46, RT.7/RW.1, Duren Sawit, Kec. Duren Sawit, Kota Jakarta Timur, DKI Jakarta 13440',
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (service['latitude'] != null && service['longitude'] != null) {
      // Koersi aman: kolom bisa berupa int/String, sedangkan Position butuh
      // double. Lewati bila tidak dapat di-parse agar tidak crash saat build.
      final lat = _toDouble(service['latitude']);
      final lng = _toDouble(service['longitude']);
      if (lat == null || lng == null) {
        return const SizedBox.shrink();
      }
      final pickupPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Penjemputan',
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface,
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.0),
          MapPicker(
            initialPosition: pickupPosition,
            onPositionChanged: (_) {},
            isInteractive: false,
          ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: colorScheme.error,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Koordinat: ${service['latitude']}, ${service['longitude']}',
                  style: GoogleFonts.poppins(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.0,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${service['latitude']},${service['longitude']}';
                  launchUrl(Uri.parse(url));
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: colorScheme.primary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Buka Maps',
                        style: GoogleFonts.poppins(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }
}
