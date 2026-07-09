import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

mixin GPSMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  bool _isGpsEnabled = false;
  BuildContext? _dialogContext;
  // Guard sinkron: di-set true SEBELUM showDialog agar dua pemanggil hampir
  // bersamaan tidak sama-sama membuka dialog GPS (dialog dobel).
  bool _isGpsDialogShowing = false;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;

  bool get isGpsEnabled => _isGpsEnabled;

  @override
  void initState() {
    super.initState();
    // Daftarkan observer siklus hidup agar didChangeAppLifecycleState aktif.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupGpsListener();
      _checkGPSAndCloseDialog();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGPSAndCloseDialog();
    }
  }

  Future<void> _checkGPSAndCloseDialog() async {
    try {
      bool isEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _isGpsEnabled = isEnabled;
        });

        if (isEnabled) {
          if (_dialogContext != null) {
            Navigator.of(_dialogContext!).pop();
            _dialogContext = null;
          }
        } else {
          _showGpsDialog();
        }
      }
    } catch (e) {
      print('Error checking GPS status: $e');
    }
  }

  void _setupGpsListener() {
    _gpsStatusSubscription?.cancel();
    _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) async {
        print('GPS Status Changed: $status');
        if (status == ServiceStatus.enabled) {
          await _checkGPSAndCloseDialog();
        } else if (status == ServiceStatus.disabled) {
          if (mounted) {
            setState(() {
              _isGpsEnabled = false;
            });
            _showGpsDialog();
          }
        }
      },
    );
  }

  void _showGpsDialog() {
    // Guard sinkron: cegah dua dialog terbuka bersamaan. _dialogContext baru
    // terisi pada frame berikutnya, sehingga tidak cukup sebagai penjaga.
    if (!mounted || _isGpsDialogShowing || _dialogContext != null) return;
    _isGpsDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _dialogContext = dialogContext;
        return WillPopScope(
          onWillPop: () async {
            bool isEnabled = await Geolocator.isLocationServiceEnabled();
            if (isEnabled) {
              if (mounted) {
                setState(() => _isGpsEnabled = true);
                Navigator.of(dialogContext).pop();
                _dialogContext = null;
              }
              return false;
            }
            return true;
          },
          child: AlertDialog(
            title: Text(
              'GPS Tidak Aktif',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Aplikasi membutuhkan akses lokasi untuk melanjutkan. Silakan aktifkan GPS pada perangkat Anda.',
                  style: GoogleFonts.poppins(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: <Widget>[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'AKTIFKAN GPS',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                        await Future.delayed(Duration(milliseconds: 500));
                        bool isEnabled =
                            await Geolocator.isLocationServiceEnabled();
                        if (isEnabled && mounted) {
                          setState(() => _isGpsEnabled = true);
                          if (_dialogContext != null) {
                            Navigator.of(_dialogContext!).pop();
                            _dialogContext = null;
                          }
                        }
                        await _checkGPSAndCloseDialog();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      _dialogContext = null;
      _isGpsDialogShowing = false;
    });
  }
}
