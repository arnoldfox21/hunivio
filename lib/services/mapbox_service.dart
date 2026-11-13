import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapboxConfig {
  static const String publicToken =
      'pk.eyJ1IjoiaHVuaWdvYXBwIiwiYSI6ImNtd2ZiaTE3YzA2MmEyeW9kcG53cWNrMHoifQ.9ruDsta7XvtIQW8t1jzEBg';

  /// Menggunakan tile 512x512 (dengan zoomOffset: -1 pada TileLayer)
  /// sehingga 1 request mencakup area 4x lebih luas dibanding 256x256.
  static const String tileUrlTemplate =
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/512/{z}/{x}/{y}?access_token=$publicToken';

  static const LatLng defaultCenter = LatLng(-7.9666, 112.6326);
}

class LocationResult {
  final LatLng location;
  final bool isUserLocation;
  final String? message;

  const LocationResult({
    required this.location,
    required this.isUserLocation,
    this.message,
  });
}

class LocationHelper {
  static const Distance _distance = Distance();

  static double distanceKm(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Kilometer, a, b);
  }

  static String formatDistance(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  static Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          location: MapboxConfig.defaultCenter,
          isUserLocation: false,
          message: 'GPS tidak aktif. Menampilkan lokasi default.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            location: MapboxConfig.defaultCenter,
            isUserLocation: false,
            message: 'Izin lokasi ditolak. Menampilkan lokasi default.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          location: MapboxConfig.defaultCenter,
          isUserLocation: false,
          message: 'Izin lokasi diblokir permanen di pengaturan.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LocationResult(
        location: LatLng(pos.latitude, pos.longitude),
        isUserLocation: true,
      );
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult(
            location: LatLng(last.latitude, last.longitude),
            isUserLocation: true,
          );
        }
      } catch (_) {}
      return const LocationResult(
        location: MapboxConfig.defaultCenter,
        isUserLocation: false,
        message: 'Gagal mendapatkan lokasi GPS. Menampilkan lokasi default.',
      );
    }
  }
}

/// TileProvider hemat request dengan cache memori + cache disk lokal + dedup in-flight.
class CachedMapboxTileProvider extends TileProvider {
  CachedMapboxTileProvider._();
  static final CachedMapboxTileProvider instance = CachedMapboxTileProvider._();

  static const int _maxMemoryEntries = 180;
  static const Duration _diskCacheMaxAge = Duration(days: 14);

  final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = Directory('${Directory.systemTemp.path}/hunigo_mapbox_tiles');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final cacheKey = 'z${coordinates.z}_x${coordinates.x}_y${coordinates.y}';
    return _CachedMapboxTileImage(
      url: url,
      cacheKey: cacheKey,
      provider: this,
    );
  }

  Future<Uint8List> _fetchTileBytes(String cacheKey, String url) {
    final memHit = _memoryCache[cacheKey];
    if (memHit != null) {
      return SynchronousFuture<Uint8List>(memHit);
    }
    return _inFlight.putIfAbsent(
      cacheKey,
      () => _loadFromDiskOrNetwork(cacheKey, url).whenComplete(() {
        _inFlight.remove(cacheKey);
      }),
    );
  }

  Future<Uint8List> _loadFromDiskOrNetwork(String cacheKey, String url) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$cacheKey.tile');
      if (await file.exists()) {
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified) < _diskCacheMaxAge) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _putMemory(cacheKey, bytes);
            return bytes;
          }
        }
      }
    } catch (_) {
      // Abaikan error baca disk dan lanjut ke jaringan.
    }

    final req = await _httpClient.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Gagal memuat tile peta (${res.statusCode})');
    }
    final bytes = await consolidateHttpClientResponseBytes(res);
    _putMemory(cacheKey, bytes);

    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/$cacheKey.tile');
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // Abaikan error tulis cache disk.
    }

    return bytes;
  }

  void _putMemory(String key, Uint8List bytes) {
    if (_memoryCache.length >= _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[key] = bytes;
  }
}

class _CachedMapboxTileImage extends ImageProvider<_CachedMapboxTileImage> {
  final String url;
  final String cacheKey;
  final CachedMapboxTileProvider provider;

  const _CachedMapboxTileImage({
    required this.url,
    required this.cacheKey,
    required this.provider,
  });

  @override
  Future<_CachedMapboxTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_CachedMapboxTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CachedMapboxTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _loadAsync(
    _CachedMapboxTileImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.provider._fetchTileBytes(key.cacheKey, key.url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CachedMapboxTileImage && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}
