import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPicker extends StatefulWidget {
  final Position? initialPosition;
  final Function(Position) onPositionChanged;
  final bool isInteractive;

  const MapPicker({
    Key? key,
    this.initialPosition,
    required this.onPositionChanged,
    this.isInteractive = true,
  }) : super(key: key);

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  LatLng _currentLatLng = const LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentLatLng = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
    }
    setState(() => _isMapReady = true);
  }

  @override
  void didUpdateWidget(MapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPosition != null &&
        widget.initialPosition != oldWidget.initialPosition) {
      _currentLatLng = LatLng(
        widget.initialPosition!.latitude,
        widget.initialPosition!.longitude,
      );
      if (_mapController.camera.zoom > 0) {
        _mapController.move(_currentLatLng, _mapController.camera.zoom);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLatLng,
                initialZoom: 15,
                onTap: widget.isInteractive ? _handleTap : null,
                interactionOptions: widget.isInteractive
                    ? const InteractionOptions()
                    : const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.servicehponline',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLatLng,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (!_isMapReady)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(TapPosition tapPosition, LatLng latLng) {
    if (!_isMapReady || !widget.isInteractive) return;

    setState(() {
      _currentLatLng = latLng;
    });

    // Pindahkan peta ke posisi yang dipilih
    _mapController.move(latLng, _mapController.camera.zoom);

    // Kirim posisi yang dipilih ke parent widget
    widget.onPositionChanged(
      Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
