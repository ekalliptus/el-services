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

  @override
  Widget build(BuildContext context) {
    if (service['shipping_method'] == 'antar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Service Center',
            style: GoogleFonts.poppins(
              color: Colors.black87,
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
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jl. Raya Kalimalang No.46, RT.7/RW.1, Duren Sawit, Kec. Duren Sawit, Kota Jakarta Timur, DKI Jakarta 13440',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (service['latitude'] != null && service['longitude'] != null) {
      final pickupPosition = Position(
        latitude: service['latitude'],
        longitude: service['longitude'],
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
              color: Colors.black87,
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
                color: Colors.red,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Koordinat: ${service['latitude']}, ${service['longitude']}',
                  style: GoogleFonts.poppins(
                    color: Colors.black54,
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Buka Maps',
                        style: GoogleFonts.poppins(
                          color: Colors.blue,
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
