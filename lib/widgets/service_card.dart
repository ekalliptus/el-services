// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:servicehponline/models/device_problems.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceCard extends StatelessWidget {
  final Map<String, String> device;
  final String active;
  final Function setActive;
  final Function nextPage;

  const ServiceCard({
    super.key,
    required this.device,
    required this.active,
    required this.setActive,
    required this.nextPage,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive = active == device["key"];
    return GestureDetector(
      onTap: () {
        setActive(device["key"]!);
      },
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey[100],
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 86,
                width: 86,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      isActive ? Colors.white.withOpacity(0.2) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SvgPicture.asset(
                  device["icon"]!,
                  colorFilter: isActive
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : null,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 12),
              Text(
                DeviceProblems.getDeviceName(device["key"]!),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.0,
                  color: isActive ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }
}
