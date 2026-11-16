import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/kost.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';
import '../models/chat_message.dart';
import '../models/kost_group.dart';
import '../models/review.dart';
import '../models/owner_post.dart';
import '../models/wallet.dart';

class PaginatedKostsResult {
  final List<Kost> data;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const PaginatedKostsResult({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}

class ApiService {
  static const String localBaseUrl = 'http://192.168.18.12:3001/api';
  static const String onlineBaseUrl = 'http://168.110.208.39:80/api';

  static String _baseUrl = kReleaseMode ? onlineBaseUrl : localBaseUrl;
  static String? _authToken;
  static void Function(String? reason)? onSessionInvalidated;

  static void _handleAuthRejectionIfNeeded(int statusCode, String body) {
    if (statusCode == 401 || statusCode == 403) {
      String? msg;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
      } catch (_) {}
      if (statusCode == 401 ||
          (msg != null && msg.toLowerCase().contains('diblokir'))) {
        onSessionInvalidated?.call(msg);
      }
    }
  }

  static String get baseUrl => _baseUrl;
  static String? get authToken => _authToken;
  static String get socketBaseUrl => _baseUrl.endsWith('/api')
      ? _baseUrl.substring(0, _baseUrl.length - 4)
      : _baseUrl;
  static bool get isOnline => _baseUrl == onlineBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static void setAuthToken(String? token) {
    _authToken = (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  static HttpClientRequest _attachAuth(HttpClientRequest request) {
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return request;
  }

  static Future<List<Kost>> fetchKosts({
    String? search,
    String? propertyCategory,
    String? unitType,
    String? type,
    String? city,
    String? district,
    String? facility,
    int? minPrice,
    int? maxPrice,
    bool onlyAvailable = false,
    bool onlyFavorite = false,
    String? sortBy,
    int? ownerId,
    bool includePending = false,
    String? approvalStatus,
  }) async {
    final res = await fetchKostsPaginated(
      search: search,
      propertyCategory: propertyCategory,
      unitType: unitType,
      type: type,
      city: city,
      district: district,
      facility: facility,
      minPrice: minPrice,
      maxPrice: maxPrice,
      onlyAvailable: onlyAvailable,
      onlyFavorite: onlyFavorite,
      sortBy: sortBy,
      ownerId: ownerId,
      includePending: includePending,
      approvalStatus: approvalStatus,
    );
    return res.data;
  }

  static Future<PaginatedKostsResult> fetchKostsPaginated({
    String? search,
    String? propertyCategory,
    String? unitType,
    String? type,
    String? city,
    String? district,
    String? facility,
    int? minPrice,
    int? maxPrice,
    bool onlyAvailable = false,
    bool onlyFavorite = false,
    String? sortBy,
    int? ownerId,
    bool includePending = false,
    String? approvalStatus,
    int? page,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (propertyCategory != null &&
        propertyCategory.isNotEmpty &&
        propertyCategory != 'SEMUA') {
      queryParams['propertyCategory'] = propertyCategory;
    }
    if (unitType != null && unitType.isNotEmpty && unitType != 'Semua') {
      queryParams['unitType'] = unitType;
    }
    if (type != null && type.isNotEmpty && type != 'Semua') {
      queryParams['type'] = type;
    }
    if (city != null && city.isNotEmpty && city != 'Semua Kota') {
      queryParams['city'] = city;
    }
    if (district != null && district.isNotEmpty && district != 'Semua Area') {
      queryParams['district'] = district;
    }
    if (facility != null && facility.isNotEmpty) {
      queryParams['facility'] = facility;
    }
    if (minPrice != null && minPrice > 0) {
      queryParams['minPrice'] = minPrice.toString();
    }
    if (maxPrice != null && maxPrice > 0) {
      queryParams['maxPrice'] = maxPrice.toString();
    }
    if (onlyAvailable) {
      queryParams['onlyAvailable'] = 'true';
    }
    if (onlyFavorite) {
      queryParams['onlyFavorite'] = 'true';
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sortBy'] = sortBy;
    }
    if (ownerId != null && ownerId > 0) {
      queryParams['ownerId'] = ownerId.toString();
    }
    if (includePending) {
      queryParams['includePending'] = 'true';
    }
    if (approvalStatus != null && approvalStatus.trim().isNotEmpty) {
      queryParams['approvalStatus'] = approvalStatus.trim().toUpperCase();
    }
    if (page != null) {
      queryParams['page'] = page.toString();
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }

    final uri = Uri.parse('$_baseUrl/kosts').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['data'] is List) {
          final items = (decoded['data'] as List<dynamic>)
              .map((item) => Kost.fromJson(item as Map<String, dynamic>))
              .toList();
          return PaginatedKostsResult(
            data: items,
            total: decoded['total'] is int ? decoded['total'] : items.length,
            page: decoded['page'] is int ? decoded['page'] : (page ?? 1),
            limit: decoded['limit'] is int
                ? decoded['limit']
                : (limit ?? items.length),
            hasMore: decoded['hasMore'] == true,
          );
        }
        final list = (decoded as List<dynamic>)
            .map((item) => Kost.fromJson(item as Map<String, dynamic>))
            .toList();
        return PaginatedKostsResult(
          data: list,
          total: list.length,
          page: 1,
          limit: list.length,
          hasMore: false,
        );
      } else {
        throw Exception('Gagal memuat daftar properti. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<List<Kost>> fetchMapPoints({
    String? propertyCategory,
    String? unitType,
    String? type,
    String? city,
    String? district,
  }) async {
    final queryParams = <String, String>{};
    if (propertyCategory != null &&
        propertyCategory.isNotEmpty &&
        propertyCategory != 'SEMUA') {
      queryParams['propertyCategory'] = propertyCategory;
    }
    if (unitType != null && unitType.isNotEmpty && unitType != 'Semua') {
      queryParams['unitType'] = unitType;
    }
    if (type != null && type.isNotEmpty && type != 'Semua') {
      queryParams['type'] = type;
    }
    if (city != null && city.isNotEmpty && city != 'Semua Kota') {
      queryParams['city'] = city;
    }
    if (district != null && district.isNotEmpty && district != 'Semua Area') {
      queryParams['district'] = district;
    }
    if (district != null && district.isNotEmpty && district != 'Semua Area') {
      queryParams['district'] = district;
    }

    final uri = Uri.parse('$_baseUrl/kosts/map-points').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((item) => Kost.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<String>> fetchCities() async {
    final uri = Uri.parse('$_baseUrl/kosts/cities');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list.map((e) => e['city'].toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Map<String, List<String>>> fetchFilters() async {
    final uri = Uri.parse('$_baseUrl/kosts/filters');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return {
          'cities': (decoded['cities'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
          'types': (decoded['types'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
          'facilities': (decoded['facilities'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
        };
      }
      return {'cities': [], 'types': [], 'facilities': []};
    } catch (_) {
      return {'cities': [], 'types': [], 'facilities': []};
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCityFilterStats() async {
    final uri = Uri.parse('$_baseUrl/kosts/filters');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final rawStats = decoded['cityStats'] as List<dynamic>? ?? [];
        return rawStats
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  static const List<String> defaultRoomFacilities = [
    'AC',
    'Kipas Angin',
    'WiFi',
    'Kasur',
    'Bantal & Guling',
    'Sprei',
    'Lemari Baju',
    'Meja Belajar',
    'Kursi',
    'Cermin',
    'Kamar Mandi Dalam',
    'Kamar Mandi Luar',
    'Kloset Duduk',
    'Kloset Jongkok',
    'Shower',
    'Water Heater',
    'TV',
    'Kulkas Mini',
    'Jendela',
    'Balkon',
  ];

  static const List<String> defaultPublicFacilities = [
    'WiFi Umum',
    'Parkir Motor',
    'Parkir Mobil',
    'Parkir Sepeda',
    'Dapur Bersama',
    'Kompor & Gas',
    'Kulkas',
    'Dispenser',
    'Mesin Cuci',
    'Jemuran',
    'Ruang Tamu',
    'Ruang Santai',
    'Mushola',
    'CCTV',
    'Penjaga Kost',
    'Security 24 Jam',
    'Akses 24 Jam',
    'Laundry',
    'Kolam Renang',
    'Gym / Fitness',
    'Taman',
    'Free Listrik',
    'Free Air',
  ];

  static Future<Map<String, List<String>>> fetchMasterFacilities() async {
    final uri = Uri.parse('$_baseUrl/kosts/master-facilities');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final room = (decoded['roomFacilities'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        final pub = (decoded['publicFacilities'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        return {
          'room': room.isNotEmpty ? room : defaultRoomFacilities,
          'public': pub.isNotEmpty ? pub : defaultPublicFacilities,
        };
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return {
      'room': defaultRoomFacilities,
      'public': defaultPublicFacilities,
    };
  }

  static Future<Kost> toggleFavorite(int kostId) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId/favorite');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        throw Exception('Gagal memperbarui status favorit');
      }
    } finally {
      client.close();
    }
  }

  static Future<Kost> createKost(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl/kosts');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        throw Exception('Gagal menambah kost. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<Booking> createBooking({
    required int kostId,
    int? userId,
    required String tenantName,
    required String tenantPhone,
    required String startDate,
    String bookingType = 'SURVEI',
    String surveyDateTime = '',
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'kostId': kostId,
        if (userId != null && userId > 0) 'userId': userId,
        'tenantName': tenantName,
        'tenantPhone': tenantPhone,
        'startDate': startDate,
        'bookingType': bookingType,
        'surveyDateTime': surveyDateTime,
        'notes': notes ?? '',
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Booking.fromJson(decoded);
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        String msg = 'Gagal membuat pengajuan survei. Silakan coba lagi.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            msg = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<List<Booking>> fetchBookings({
    int? userId,
    int? ownerId,
    bool all = false,
  }) async {
    final queryParams = <String, String>{
      if (userId != null && userId > 0) 'userId': userId.toString(),
      if (ownerId != null && ownerId > 0) 'ownerId': ownerId.toString(),
      if (all) 'all': 'true',
    };
    final uri = Uri.parse('$_baseUrl/bookings').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => Booking.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        throw Exception('Gagal memuat daftar pengajuan sewa.');
      }
    } finally {
      client.close();
    }
  }

  static Future<Booking> updateBookingStatus(
    int bookingId,
    String status,
  ) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/status');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'status': status})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        throw Exception('Gagal memperbarui status pengajuan.');
      }
    } finally {
      client.close();
    }
  }

  static Future<Booking> cancelBooking(
    int bookingId, {
    int? userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/cancel');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            if (userId != null && userId > 0) 'userId': userId,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      String msg = 'Gagal membatalkan pengajuan.';
      try {
        final parsed = jsonDecode(body);
        if (parsed is Map && parsed['message'] != null) {
          msg = parsed['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    } finally {
      client.close();
    }
  }

  static Future<GoogleAuthResult> loginOrRegisterWithGoogle({
    required String googleId,
    required String email,
    required String name,
    required String avatarUrl,
    String? accessToken,
    String? idToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/google');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'googleId': googleId,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        if (accessToken != null && accessToken.isNotEmpty)
          'accessToken': accessToken,
        if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return GoogleAuthResult.fromJson(decoded);
      } else {
        String msg = 'Gagal masuk dengan akun Google (${response.statusCode}).';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map<String, dynamic> && errJson['message'] != null) {
            msg = errJson['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<GoogleAuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'email': email.trim(),
            'password': password,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return GoogleAuthResult.fromJson(decoded);
      } else {
        String msg = 'Gagal masuk (${response.statusCode}).';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map<String, dynamic> && errJson['message'] != null) {
            final rawMsg = errJson['message'];
            msg = rawMsg is List ? rawMsg.join(', ') : rawMsg.toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> setOrChangePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/password');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            if (currentPassword != null && currentPassword.isNotEmpty)
              'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final userMap = decoded['user'] as Map<String, dynamic>;
        return UserProfile.fromJson(userMap);
      } else {
        String msg = 'Gagal menyimpan password (${response.statusCode}).';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map<String, dynamic> && errJson['message'] != null) {
            final rawMsg = errJson['message'];
            msg = rawMsg is List ? rawMsg.join(', ') : rawMsg.toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> updateUserProfile({
    required int userId,
    required String name,
    required String phone,
    String? role,
    String? username,
    String? bio,
    String? city,
    String? avatarUrl,
    String? coverUrl,
    bool? showWhatsapp,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'name': name,
        'phone': phone,
        if (role != null && role.isNotEmpty) 'role': role,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (city != null) 'city': city,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (showWhatsapp != null) 'showWhatsapp': showWhatsapp,
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return UserProfile.fromJson(decoded);
      } else {
        throw Exception('Gagal memperbarui profil. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<({UserProfile user, String accessToken})> completeOnboarding({
    required String role,
    String? preferredCategory,
    String? city,
    String? phone,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/onboarding');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'role': role,
        if (preferredCategory != null && preferredCategory.trim().isNotEmpty)
          'preferredCategory': preferredCategory.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final userMap = decoded['user'] as Map<String, dynamic>;
        final accessToken = decoded['accessToken']?.toString() ?? '';
        return (
          user: UserProfile.fromJson(userMap),
          accessToken: accessToken,
        );
      } else {
        String msg = 'Gagal menyelesaikan pengaturan akun.';
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['message'] != null) {
            msg = parsed['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> updateUserRole({
    required int userId,
    required String role,
    required int requesterId,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId/role');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({
        'role': role,
        'requesterId': requesterId,
      })));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return UserProfile.fromJson(decoded);
      } else {
        String message = 'Gagal mengubah peran pengguna.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            message = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> fetchUserById(int userId) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UserProfile.fromJson(jsonDecode(body) as Map<String, dynamic>);
      } else {
        throw Exception('Gagal memuat profil pemilik.');
      }
    } finally {
      client.close();
    }
  }

  static Future<List<OwnerPost>> fetchOwnerPosts(
    int ownerId, {
    int? viewerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts').replace(
      queryParameters: {
        'ownerId': '$ownerId',
        if (viewerId != null) 'viewerId': '$viewerId',
      },
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => OwnerPost.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Gagal memuat postingan pemilik.');
      }
    } finally {
      client.close();
    }
  }

  static Future<OwnerPost> createOwnerPost({
    required int ownerId,
    required String content,
    String? imageUrl,
    int? kostId,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({
        'ownerId': ownerId,
        'content': content,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (kostId != null) 'kostId': kostId,
      })));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return OwnerPost.fromJson(jsonDecode(body) as Map<String, dynamic>);
      } else {
        String message = 'Gagal membuat postingan.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            message = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<OwnerPost> updateOwnerPost({
    required int postId,
    required int requesterId,
    String? content,
    String? imageUrl,
    int? kostId,
    bool clearKostId = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = <String, dynamic>{
        'requesterId': requesterId,
        if (content != null) 'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (clearKostId)
          'kostId': null
        else if (kostId != null)
          'kostId': kostId,
      };
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return OwnerPost.fromJson(jsonDecode(body) as Map<String, dynamic>);
      } else {
        String message = 'Gagal memperbarui postingan.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            message = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<void> deleteOwnerPost({
    required int postId,
    required int requesterId,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId?requesterId=$requesterId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gagal menghapus postingan.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            message = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<List<UserProfile>> fetchUsers({
    String? search,
    String? role,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (role != null && role.trim().isNotEmpty && role != 'SEMUA')
        'role': role.trim(),
    };
    final uri =
        Uri.parse('$_baseUrl/auth/users').replace(queryParameters: params);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Gagal memuat daftar pengguna.');
      }
    } finally {
      client.close();
    }
  }

  static Future<void> deleteUser(int userId) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gagal menghapus pengguna.';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<String> uploadKostImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.path.split(Platform.pathSeparator).last;
    final lower = filename.toLowerCase();
    final mimeType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';

    final uri = Uri.parse('$_baseUrl/kosts/upload-image');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'base64': base64Encode(bytes),
            'filename': filename,
            'mimeType': mimeType,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final url = decoded['url']?.toString() ?? '';
        if (url.isEmpty) {
          throw Exception('URL gambar tidak ditemukan dari server.');
        }
        return url;
      } else {
        _handleAuthRejectionIfNeeded(response.statusCode, body);
        var message = 'Gagal mengunggah foto kost (${response.statusCode}).';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map && decoded['message'] != null) {
            final serverMsg = decoded['message'];
            message = serverMsg is List ? serverMsg.join(', ') : serverMsg.toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<Kost> updateKost(
    int kostId,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      } else {
        throw Exception('Gagal memperbarui data kost.');
      }
    } finally {
      client.close();
    }
  }

  static Future<Kost> transferKostOwner({
    required int kostId,
    required int targetOwnerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId/transfer-owner');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'targetOwnerId': targetOwnerId})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      }
      String msg = 'Gagal memindahkan kepemilikan (${response.statusCode})';
      try {
        final err = jsonDecode(body);
        if (err is Map<String, dynamic> && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    } finally {
      client.close();
    }
  }

  static Future<Kost> approveOrRejectKost(
    int kostId, {
    required String status,
    String? rejectionReason,
    int? reviewerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId/approval');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'status': status,
          if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
            'rejectionReason': rejectionReason.trim(),
          if (reviewerId != null) 'reviewerId': reviewerId,
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gagal memperbarui status persetujuan properti.';
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['message'] != null) {
            message = parsed['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
      return Kost.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  static Future<void> deleteKost(int kostId) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gagal menghapus properti kost.');
      }
    } finally {
      client.close();
    }
  }

  static Future<List<ChatMessage>> fetchChatMessages({
    required int kostId,
    int? userId,
  }) async {
    final queryParams = <String, String>{
      'kostId': kostId.toString(),
      if (userId != null && userId > 0) 'userId': userId.toString(),
    };
    final uri =
        Uri.parse('$_baseUrl/chats').replace(queryParameters: queryParams);
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Gagal memuat pesan chat.');
      }
    } finally {
      client.close();
    }
  }

  static Future<ChatMessage> sendChatMessage({
    required int kostId,
    required int senderId,
    required String senderName,
    String senderAvatar = '',
    required int receiverId,
    required String message,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'kostId': kostId,
            'senderId': senderId,
            'senderName': senderName,
            'senderAvatar': senderAvatar,
            'receiverId': receiverId,
            'message': message,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return ChatMessage.fromJson(decoded);
      } else {
        String message = response.statusCode == 401
            ? 'Sesi login belum terautentikasi. Silakan keluar lalu masuk ulang dengan Google.'
            : 'Gagal mengirim pesan (${response.statusCode}).';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            message = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } finally {
      client.close();
    }
  }

  static Future<List<ChatMessage>> fetchChatConversations(int userId) async {
    final uri = Uri.parse('$_baseUrl/chats/conversations/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (response.statusCode == 401) {
        throw Exception(
          'Sesi login kedaluwarsa. Silakan keluar lalu masuk ulang dengan Google.',
        );
      }
      throw Exception('Gagal memuat kotak pesan (${response.statusCode}).');
    } finally {
      client.close();
    }
  }

  static Future<List<Review>> fetchReviews(int kostId) async {
    final uri = Uri.parse('$_baseUrl/reviews?kostId=$kostId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } finally {
      client.close();
    }
  }

  static Future<Review> createReview({
    required int kostId,
    required int userId,
    required String userName,
    String userAvatar = '',
    required double ratingCleanliness,
    required double ratingSecurity,
    required double ratingAccuracy,
    required String comment,
  }) async {
    final uri = Uri.parse('$_baseUrl/reviews');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'kostId': kostId,
            'userId': userId,
            'userName': userName,
            'userAvatar': userAvatar,
            'ratingCleanliness': ratingCleanliness,
            'ratingSecurity': ratingSecurity,
            'ratingAccuracy': ratingAccuracy,
            'comment': comment,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Review.fromJson(jsonDecode(body) as Map<String, dynamic>);
      } else {
        String msg = 'Gagal mengirim ulasan.';
        try {
          final err = jsonDecode(body);
          if (err is Map && err['message'] != null) {
            msg = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<void> updateUserFcmToken({
    required int userId,
    required String fcmToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId/fcm-token');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'fcmToken': fcmToken})));
      await request.close();
    } catch (_) {
    } finally {
      client.close();
    }
  }

  static Future<void> markChatAsRead({
    required int kostId,
    required int readerId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/read');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(jsonEncode({'kostId': kostId, 'readerId': readerId})),
      );
      await request.close();
    } catch (_) {
    } finally {
      client.close();
    }
  }

  static Future<Kost?> fetchKostById(int id) async {
    final uri = Uri.parse('$_baseUrl/kosts/$id');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Kost.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<List<KostGroupRoom>> fetchGroupRoomsForUser(int userId) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/user/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => KostGroupRoom.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (response.statusCode == 401) {
        throw Exception(
          'Sesi login kedaluwarsa. Silakan keluar lalu masuk ulang dengan Google.',
        );
      }
      throw Exception('Gagal memuat daftar grup (${response.statusCode}).');
    } finally {
      client.close();
    }
  }

  static Future<KostGroupDetail> fetchGroupDetail({
    required int kostId,
    required int userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/$kostId?userId=$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return KostGroupDetail.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      String msg = 'Gagal memuat grup penghuni.';
      try {
        final err = jsonDecode(body);
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    } finally {
      client.close();
    }
  }

  static Future<KostGroupMessage> sendGroupMessageRest({
    required int kostId,
    required int senderId,
    required String senderName,
    String senderAvatar = '',
    required String message,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/$kostId/messages');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'senderId': senderId,
            'senderName': senderName,
            'senderAvatar': senderAvatar,
            'message': message,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return KostGroupMessage.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      String msg = 'Gagal mengirim pesan grup.';
      try {
        final err = jsonDecode(body);
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    } finally {
      client.close();
    }
  }

  static Future<void> kickGroupMember({
    required int kostId,
    required int adminId,
    required int targetUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/$kostId/kick');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({'adminId': adminId, 'targetUserId': targetUserId}),
        ),
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gagal mengeluarkan anggota.');
      }
    } finally {
      client.close();
    }
  }

  static Future<void> addGroupMember({
    required int kostId,
    required int adminId,
    required int targetUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/$kostId/members');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({'adminId': adminId, 'targetUserId': targetUserId}),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String msg = 'Gagal menambahkan anggota ke grup.';
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['message'] != null) {
            msg = parsed['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> searchGroupCandidates({
    required int kostId,
    required int adminId,
    String query = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/chats/groups/$kostId/candidates').replace(
      queryParameters: {
        'adminId': adminId.toString(),
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      }
      throw Exception('Gagal memuat daftar pengguna.');
    } finally {
      client.close();
    }
  }

  static Future<List<String>> fetchLocationCities({String query = ''}) async {
    final uri = Uri.parse('$_baseUrl/locations/cities').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<List<String>> fetchLocationDistricts({
    String city = '',
    String query = '',
  }) async {
    final uri = Uri.parse('$_baseUrl/locations/districts').replace(
      queryParameters: {
        if (city.trim().isNotEmpty) 'city': city.trim(),
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  static Future<void> reportReview({
    required int reviewId,
    required String reason,
    String? details,
  }) async {
    final uri = Uri.parse('$_baseUrl/reviews/$reviewId/report');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'reason': reason,
            if (details != null && details.trim().isNotEmpty)
              'details': details.trim(),
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      String msg = 'Gagal mengirim laporan ulasan.';
      try {
        final err = jsonDecode(body);
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    } finally {
      client.close();
    }
  }

  static Future<List<ReviewReport>> fetchReviewReports() async {
    final uri = Uri.parse('$_baseUrl/reviews/reports');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => ReviewReport.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } finally {
      client.close();
    }
  }

  static Future<void> dismissReviewReport(int reportId) async {
    final uri = Uri.parse('$_baseUrl/reviews/reports/$reportId/dismiss');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal mengabaikan laporan ulasan.');
    } finally {
      client.close();
    }
  }

  static Future<void> deleteReview(int reviewId) async {
    final uri = Uri.parse('$_baseUrl/reviews/$reviewId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal menghapus ulasan.');
    } finally {
      client.close();
    }
  }

  static Future<UserProfile?> fetchMe() async {
    final uri = Uri.parse('$_baseUrl/auth/me');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UserProfile.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      return null;
    } finally {
      client.close();
    }
  }

  static Future<void> deleteMyAccount() async {
    final uri = Uri.parse('$_baseUrl/auth/users/me');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal menghapus akun.');
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> setUserBanStatus({
    required int userId,
    required bool isBanned,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId/ban');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'isBanned': isBanned})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return UserProfile.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal memperbarui status blokir pengguna.');
    } finally {
      client.close();
    }
  }

  static Future<Review> replyToReview({
    required int reviewId,
    required String reply,
  }) async {
    final uri = Uri.parse('$_baseUrl/reviews/$reviewId/reply');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'reply': reply})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Review.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal mengirim balasan ulasan.');
    } finally {
      client.close();
    }
  }

  static Future<({bool liked, int likeCount})> togglePostLike(
      int postId) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId/like');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return (
          liked: decoded['liked'] == true,
          likeCount: decoded['likeCount'] is int
              ? decoded['likeCount'] as int
              : int.tryParse('${decoded['likeCount']}') ?? 0,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal memperbarui suka.');
    } finally {
      client.close();
    }
  }

  static Future<List<OwnerPostComment>> fetchPostComments(int postId) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId/comments');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => OwnerPostComment.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Gagal memuat komentar.');
    } finally {
      client.close();
    }
  }

  static Future<OwnerPostComment> createPostComment({
    required int postId,
    required String content,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId/comments');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'content': content})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return OwnerPostComment.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal mengirim komentar.');
    } finally {
      client.close();
    }
  }

  static Future<void> deletePostComment({
    required int postId,
    required int commentId,
  }) async {
    final uri = Uri.parse('$_baseUrl/posts/$postId/comments/$commentId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = _attachAuth(await client.deleteUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception('Gagal menghapus komentar.');
    } finally {
      client.close();
    }
  }

  static String _extractErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final msg = decoded['message'];
        if (msg is List && msg.isNotEmpty) {
          return msg.first.toString();
        }
        return msg.toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Future<WalletSummary> fetchWalletSummary() async {
    final uri = Uri.parse('$_baseUrl/wallet/me');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return WalletSummary.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memuat saldo kredit.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<CreateTopupResult> createWalletTopup(int amount) async {
    final uri = Uri.parse('$_baseUrl/wallet/topup');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'amount': amount})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CreateTopupResult.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal membuat transaksi top-up.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<SyncTopupResult> syncWalletTopupStatus(String orderId) async {
    final uri = Uri.parse('$_baseUrl/wallet/topup/$orderId/sync');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SyncTopupResult.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memeriksa status pembayaran.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<WalletPricing> fetchWalletPricing() async {
    final uri = Uri.parse('$_baseUrl/wallet/pricing');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return WalletPricing.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      throw Exception(
        _extractErrorMessage(body, 'Gagal memuat daftar tarif kredit.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<BoostKostResult> boostKost(
    int kostId,
    String packageCode,
  ) async {
    final uri = Uri.parse('$_baseUrl/wallet/boost/$kostId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'packageCode': packageCode})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BoostKostResult.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal mengaktifkan boost iklan.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Booking> createDirectBooking({
    required int kostId,
    required String tenantName,
    required String tenantPhone,
    required String startDate,
    required int durationCount,
    String notes = '',
    bool usePoints = false,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings/direct');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'kostId': kostId,
            'tenantName': tenantName,
            'tenantPhone': tenantPhone,
            'startDate': startDate,
            'durationCount': durationCount,
            'notes': notes,
            'usePoints': usePoints,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal membuat booking langsung.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Booking> syncDirectBookingPayment(int bookingId) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/sync-payment');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memeriksa status pembayaran.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Booking> confirmBookingCheckIn(int bookingId) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/confirm-checkin');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal mengonfirmasi check-in.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Booking> reportBookingDispute(
    int bookingId,
    String reason,
  ) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/dispute');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode({'reason': reason})));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Booking.fromJson(jsonDecode(body) as Map<String, dynamic>);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal melaporkan kendala.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> fetchMyLoyaltySummary() async {
    final uri = Uri.parse('$_baseUrl/bookings/loyalty/me');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memuat data poin & level.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> createPayoutRequest({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final uri = Uri.parse('$_baseUrl/wallet/payout-requests');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'amount': amount,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountHolder': accountHolder,
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal mengajukan penarikan dana.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyPayoutRequests() async {
    final uri = Uri.parse('$_baseUrl/wallet/payout-requests/me');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memuat riwayat penarikan dana.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllPayoutRequests() async {
    final uri = Uri.parse('$_baseUrl/wallet/payout-requests');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.getUrl(uri));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memuat daftar pengajuan withdraw.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> processPayoutRequest({
    required String requestId,
    required String action,
    String? adminNote,
  }) async {
    final uri =
        Uri.parse('$_baseUrl/wallet/payout-requests/$requestId/process');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.patchUrl(uri));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'action': action,
          if (adminNote != null && adminNote.trim().isNotEmpty)
            'adminNote': adminNote.trim(),
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal memproses pengajuan withdraw.'),
      );
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> resolveBookingDispute({
    required String bookingId,
    required String resolution,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings/$bookingId/resolve-dispute');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = _attachAuth(await client.postUrl(uri));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'resolution': resolution}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Map<String, dynamic>.from(jsonDecode(body) as Map);
      }
      _handleAuthRejectionIfNeeded(response.statusCode, body);
      throw Exception(
        _extractErrorMessage(body, 'Gagal menyelesaikan sengketa escrow.'),
      );
    } finally {
      client.close();
    }
  }
}
