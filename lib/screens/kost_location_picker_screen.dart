import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/mapbox_service.dart';
import '../utils/formatters.dart';

class KostLocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const KostLocationPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<KostLocationPickerScreen> createState() =>
      _KostLocationPickerScreenState();
}

class _KostLocationPickerScreenState extends State<KostLocationPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _pickedLocation;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? MapboxConfig.defaultCenter;
    if (widget.initialLocation == null) {
      _goToMyLocation();
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingGps = true);
    final res = await LocationHelper.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _pickedLocation = res.location;
      _loadingGps = false;
    });
    _mapController.move(res.location, 16.0);
    if (res.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pilih Pin Lokasi Kost',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: widget.initialLocation != null ? 16.0 : 14.0,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _pickedLocation = camera.center;
                  });
                }
              },
              onTap: (_, point) {
                setState(() => _pickedLocation = point);
                _mapController.move(point, _mapController.camera.zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapboxConfig.tileUrlTemplate,
                tileSize: 512,
                zoomOffset: -1,
                panBuffer: 0,
                keepBuffer: 2,
                tileProvider: CachedMapboxTileProvider.instance,
                userAgentPackageName: 'com.hunigo.app',
              ),
            ],
          ),

          // Pin tetap di tengah peta
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Geser peta untuk atur pin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.location_pin,
                      color: AppColors.primaryGreen,
                      size: 46,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tombol Lokasi Saya
          Positioned(
            right: 16,
            bottom: 148,
            child: FloatingActionButton.small(
              heroTag: 'picker_my_location_btn',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryGreen,
              tooltip: 'Gunakan Lokasi Saya',
              onPressed: _loadingGps ? null : _goToMyLocation,
              child: _loadingGps
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),

          // Attribution
          const Positioned(
            left: 12,
            bottom: 142,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '© Mapbox © OpenStreetMap',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ),
          ),

          // Bottom Confirmation Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pin_drop_rounded,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Koordinat: ${_pickedLocation.latitude.toStringAsFixed(6)}, ${_pickedLocation.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(_pickedLocation);
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text(
                          'Simpan Titik Lokasi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
