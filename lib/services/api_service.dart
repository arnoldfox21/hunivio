import 'dart:convert';
import 'dart:io';
import '../models/kost.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';

class ApiService {
  static const String localBaseUrl = 'http://192.168.18.12:3001/api';
  static const String onlineBaseUrl = 'https://hunigo-api.vercel.app/api';

  static String _baseUrl = localBaseUrl;

  static String get baseUrl => _baseUrl;
  static bool get isOnline => _baseUrl == onlineBaseUrl;

  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<List<Kost>> fetchKosts({
    String? search,
    String? type,
    String? city,
    String? facility,
    int? maxPrice,
    String? sortBy,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (type != null && type.isNotEmpty && type != 'Semua') {
      queryParams['type'] = type;
    }
    if (city != null && city.isNotEmpty && city != 'Semua Kota') {
      queryParams['city'] = city;
    }
    if (facility != null && facility.isNotEmpty) {
      queryParams['facility'] = facility;
    }
    if (maxPrice != null && maxPrice > 0) {
      queryParams['maxPrice'] = maxPrice.toString();
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sortBy'] = sortBy;
    }

    final uri = Uri.parse('$_baseUrl/kosts').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body);
        final List<dynamic> list =
            decoded is Map && decoded['data'] is List ? decoded['data'] : decoded;
        return list
            .map((item) => Kost.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Gagal memuat daftar kost. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<List<String>> fetchCities() async {
    final uri = Uri.parse('$_baseUrl/kosts/cities');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri);
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
      final request = await client.getUrl(uri);
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

  static Future<Kost> toggleFavorite(int kostId) async {
    final uri = Uri.parse('$_baseUrl/kosts/$kostId/favorite');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.patchUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      } else {
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
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Kost.fromJson(decoded);
      } else {
        throw Exception('Gagal menambah kost. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<Booking> createBooking({
    required int kostId,
    required String tenantName,
    required String tenantPhone,
    required String startDate,
    required int durationMonths,
    String? notes,
  }) async {
    final uri = Uri.parse('$_baseUrl/bookings');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'kostId': kostId,
        'tenantName': tenantName,
        'tenantPhone': tenantPhone,
        'startDate': startDate,
        'durationMonths': durationMonths,
        'notes': notes ?? '',
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return Booking.fromJson(decoded);
      } else {
        throw Exception('Gagal membuat pengajuan sewa. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<List<Booking>> fetchBookings() async {
    final uri = Uri.parse('$_baseUrl/bookings');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> list = jsonDecode(body);
        return list
            .map((e) => Booking.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Gagal memuat daftar pengajuan sewa.');
      }
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
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'googleId': googleId,
        'email': email,
        'name': name,
        'avatarUrl': avatarUrl,
        if (accessToken != null) 'accessToken': accessToken,
        if (idToken != null) 'idToken': idToken,
      });
      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        return GoogleAuthResult.fromJson(decoded);
      } else {
        throw Exception('Gagal masuk dengan akun Google. Silakan coba lagi.');
      }
    } finally {
      client.close();
    }
  }

  static Future<UserProfile> updateUserProfile({
    required int userId,
    required String name,
    required String phone,
    required String role,
    String? username,
    String? bio,
    String? city,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/users/$userId');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.patchUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final payload = jsonEncode({
        'name': name,
        'phone': phone,
        'role': role,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (city != null) 'city': city,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (coverUrl != null) 'coverUrl': coverUrl,
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

  static Future<List<UserProfile>> fetchUsers() async {
    final uri = Uri.parse('$_baseUrl/auth/users');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri);
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
      final request = await client.deleteUrl(uri);
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
      final request = await client.postUrl(uri);
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
        throw Exception('Gagal mengunggah foto kost.');
      }
    } finally {
      client.close();
    }
  }
}
