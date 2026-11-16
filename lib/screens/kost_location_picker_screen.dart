import 'dart:async';
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
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late LatLng _pickedLocation;
  bool _loadingGps = false;
  bool _searchingAddress = false;
  String? _pickedAddress;
  List<ForwardGeocodeResult> _searchResults = const [];
  Timer? _searchDebounce;
  Timer? _reverseDebounce;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? MapboxConfig.defaultCenter;
    if (widget.initialLocation == null) {
      _goToMyLocation();
    } else {
      _scheduleReverseGeocode(_pickedLocation);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = const [];
        _searchingAddress = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _performAddressSearch(trimmed);
    });
  }

  Future<void> _performAddressSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;
    setState(() => _searchingAddress = true);
    final results = await LocationHelper.forwardGeocode(
      trimmed,
      proximity: _pickedLocation,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searchingAddress = false;
    });
  }

  void _selectSearchResult(ForwardGeocodeResult item) {
    _searchFocusNode.unfocus();
    setState(() {
      _pickedLocation = item.location;
      _pickedAddress = item.subtitle.isNotEmpty ? item.subtitle : item.title;
      _searchResults = const [];
      _searchCtrl.text = item.title;
    });
    _mapController.move(item.location, 16.5);
  }

  void _scheduleReverseGeocode(LatLng point) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 550), () async {
      final res = await LocationHelper.reverseGeocode(point);
      if (!mounted || res == null) return;
      final formatted = res.address.isNotEmpty
          ? res.address
          : [res.district, res.city].where((s) => s.isNotEmpty).join(', ');
      if (formatted.isNotEmpty) {
        setState(() => _pickedAddress = formatted);
      }
    });
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
    _scheduleReverseGeocode(res.location);
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
          'Pilih Pin Lokasi Properti',
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
                  _scheduleReverseGeocode(camera.center);
                }
              },
              onTap: (_, point) {
                _searchFocusNode.unfocus();
                setState(() {
                  _pickedLocation = point;
                  _searchResults = const [];
                });
                _mapController.move(point, _mapController.camera.zoom);
                _scheduleReverseGeocode(point);
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
                userAgentPackageName: 'com.hunivio.app',
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

          // Search Bar Alamat di atas peta
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    onSubmitted: _performAddressSearch,
                    decoration: InputDecoration(
                      hintText: 'Cari alamat, jalan, kampus, atau area...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGreen,
                        size: 21,
                      ),
                      suffixIcon: _searchingAddress
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            )
                          : _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchResults = const []);
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 230),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (_, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: item.subtitle.isNotEmpty
                              ? Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Attribution (diperkecil)
          const Positioned(
            left: 10,
            bottom: 148,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x99FFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                child: Text(
                  '© Mapbox © OSM',
                  style: TextStyle(fontSize: 8.5, color: Colors.black45),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_pickedAddress != null &&
                                  _pickedAddress!.isNotEmpty)
                                Text(
                                  _pickedAddress!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              Text(
                                'Koordinat: ${_pickedLocation.latitude.toStringAsFixed(6)}, ${_pickedLocation.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontWeight: _pickedAddress != null
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  fontSize: _pickedAddress != null ? 11.5 : 13,
                                  color: _pickedAddress != null
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
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
