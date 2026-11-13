import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/kost.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';

class KostMapSearchView extends StatefulWidget {
  final List<Kost> kosts;
  final ValueChanged<Kost> onOpenDetail;

  const KostMapSearchView({
    super.key,
    required this.kosts,
    required this.onOpenDetail,
  });

  @override
  State<KostMapSearchView> createState() => _KostMapSearchViewState();
}

class _KostMapSearchViewState extends State<KostMapSearchView> {
  final MapController _mapController = MapController();

  LatLng _userCenter = MapboxConfig.defaultCenter;
  bool _hasUserLocation = false;
  bool _loadingLocation = true;
  String? _locationNotice;
  double? _radiusKm; // null = Semua
  Kost? _selectedKost;

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationNotice = null;
    });
    final res = await LocationHelper.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _userCenter = res.location;
      _hasUserLocation = res.isUserLocation;
      _locationNotice = res.message;
      _loadingLocation = false;
    });
    // Langsung pindah tanpa animasi zoom bertahap agar hemat request tile.
    _mapController.move(res.location, 13.5);
  }

  List<Kost> get _mappableKosts {
    final withCoords = widget.kosts.where((k) => k.hasCoordinates).toList();
    if (_radiusKm == null) return withCoords;
    return withCoords.where((k) {
      final d = LocationHelper.distanceKm(
        _userCenter,
        LatLng(k.latitude!, k.longitude!),
      );
      return d <= _radiusKm!;
    }).toList();
  }

  String _compactPrice(int price) {
    if (price >= 1000000) {
      final jt = price / 1000000;
      final formatted =
          jt % 1 == 0 ? jt.toStringAsFixed(0) : jt.toStringAsFixed(1);
      return 'Rp${formatted.replaceAll('.', ',')}jt';
    }
    if (price >= 1000) {
      return 'Rp${(price / 1000).round()}rb';
    }
    return 'Rp$price';
  }

  @override
  Widget build(BuildContext context) {
    final visibleKosts = _mappableKosts;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userCenter,
            initialZoom: 13.5,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) {
              if (_selectedKost != null) {
                setState(() => _selectedKost = null);
              }
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
            if (_radiusKm != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _userCenter,
                    radius: _radiusKm! * 1000,
                    useRadiusInMeter: true,
                    color: AppColors.primaryGreen.withOpacity(0.10),
                    borderColor: AppColors.primaryGreen.withOpacity(0.45),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_hasUserLocation)
                  Marker(
                    point: _userCenter,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withOpacity(0.22),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade600,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ...visibleKosts.map((kost) {
                  final isSelected = _selectedKost?.id == kost.id;
                  return Marker(
                    point: LatLng(kost.latitude!, kost.longitude!),
                    width: 88,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedKost = kost);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primaryGreen,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _compactPrice(kost.pricePerMonth),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppColors.darkGreen,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Top Radius Filter & Info Bar
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRadiusChip('Semua', null),
                    const SizedBox(width: 6),
                    _buildRadiusChip('2 km', 2),
                    const SizedBox(width: 6),
                    _buildRadiusChip('5 km', 5),
                    const SizedBox(width: 6),
                    _buildRadiusChip('10 km', 10),
                    const SizedBox(width: 6),
                    _buildRadiusChip('25 km', 25),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${visibleKosts.length} kost di peta',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loadingLocation) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Mencari lokasimu...',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (_locationNotice != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _locationNotice!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _initUserLocation,
                        child: Text(
                          'Coba lagi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // My Location Button
        Positioned(
          right: 14,
          bottom: _selectedKost != null ? 156 : 24,
          child: FloatingActionButton.small(
            heroTag: 'map_my_location_btn',
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryGreen,
            tooltip: 'Lokasi Saya',
            onPressed: _initUserLocation,
            child: const Icon(Icons.my_location_rounded),
          ),
        ),

        // Mapbox Attribution
        Positioned(
          left: 10,
          bottom: _selectedKost != null ? 150 : 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '© Mapbox © OpenStreetMap',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ),

        // Selected Kost Preview Card
        if (_selectedKost != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: _buildPreviewCard(_selectedKost!),
          ),
      ],
    );
  }

  Widget _buildRadiusChip(String label, double? radiusKm) {
    final selected = _radiusKm == radiusKm;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      elevation: 2,
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF1F2937),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _radiusKm = radiusKm;
          if (_selectedKost != null && !_mappableKosts.contains(_selectedKost)) {
            _selectedKost = null;
          }
        });
      },
    );
  }

  Widget _buildPreviewCard(Kost kost) {
    final distKm = LocationHelper.distanceKm(
      _userCenter,
      LatLng(kost.latitude!, kost.longitude!),
    );
    final imageUrl = kost.images.isNotEmpty ? kost.images.first : '';

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpenDetail(kost),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Kost ${kost.type}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.near_me_rounded,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          LocationHelper.formatDistance(distKm),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kost.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${kost.district}, ${kost.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formatRupiah(kost.pricePerMonth)}/bln',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const Text(
                          'Lihat Detail →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 92,
      height: 92,
      color: Colors.grey.shade200,
      child: const Icon(Icons.home_work_outlined, color: Colors.grey),
    );
  }
}
