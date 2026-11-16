import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF1BAA56);
  static const Color darkGreen = Color(0xFF0E7C3A);
  static const Color lightGreenBg = Color(0xFFE8F7EE);
  static const Color surfaceBg = Color(0xFFF6F8FA);
  static const Color cardBorder = Color(0xFFE6ECF2);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color putriPink = Color(0xFFE02954);
  static const Color putriBg = Color(0xFFFDECEF);
  static const Color putraBlue = Color(0xFF1E6CEB);
  static const Color putraBg = Color(0xFFEAF2FF);
  static const Color campurPurple = Color(0xFF7B2CBF);
  static const Color campurBg = Color(0xFFF3E8FF);
  static const Color discountRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFF6D00);
}

String formatRupiah(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    buffer.write(str[i]);
    count++;
    if (count == 3 && i != 0) {
      buffer.write('.');
      count = 0;
    }
  }
  final formatted = buffer.toString().split('').reversed.join('');
  return 'Rp$formatted';
}

Color getKostTypeColor(String type) {
  switch (type.toLowerCase()) {
    case 'putri':
      return AppColors.putriPink;
    case 'putra':
      return AppColors.putraBlue;
    default:
      return AppColors.campurPurple;
  }
}

Color getKostTypeBgColor(String type) {
  switch (type.toLowerCase()) {
    case 'putri':
      return AppColors.putriBg;
    case 'putra':
      return AppColors.putraBg;
    default:
      return AppColors.campurBg;
  }
}

IconData getFacilityIcon(String facility) {
  final lower = facility.toLowerCase();
  if (lower.contains('ac')) return Icons.ac_unit_rounded;
  if (lower.contains('wifi')) return Icons.wifi_rounded;
  if (lower.contains('mandi')) return Icons.bathtub_outlined;
  if (lower.contains('kasur')) return Icons.bed_rounded;
  if (lower.contains('meja')) return Icons.desk_rounded;
  if (lower.contains('lemari')) return Icons.door_sliding_outlined;
  if (lower.contains('heater') || lower.contains('air panas')) {
    return Icons.hot_tub_rounded;
  }
  if (lower.contains('mobil')) return Icons.directions_car_filled_outlined;
  if (lower.contains('motor')) return Icons.two_wheeler_rounded;
  if (lower.contains('dapur')) return Icons.kitchen_rounded;
  if (lower.contains('cctv')) return Icons.videocam_outlined;
  if (lower.contains('kulkas')) return Icons.kitchen_outlined;
  if (lower.contains('tv')) return Icons.tv_rounded;
  if (lower.contains('24 jam')) return Icons.access_time_filled_rounded;
  return Icons.check_circle_outline_rounded;
}

const MethodChannel _externalLauncherChannel =
    MethodChannel('com.keyloka.app/launcher');

String normalizeWhatsAppPhone(String rawPhone) {
  var digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (digits.startsWith('8')) {
    digits = '62$digits';
  }
  return digits;
}

/// Validates Indonesian WhatsApp numbers (accepts 08..., 628..., +628...).
String? validateIndonesianWhatsAppPhone(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) {
    return 'No. WA wajib diisi';
  }
  if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
    return 'No. WA hanya boleh berisi angka';
  }
  final normalized = normalizeWhatsAppPhone(trimmed);
  if (!normalized.startsWith('628')) {
    return 'Gunakan awalan 08 atau 628';
  }
  if (normalized.length < 11) {
    return 'No. WA terlalu pendek (min. 10 digit)';
  }
  if (normalized.length > 15) {
    return 'No. WA terlalu panjang (maks. 14 digit)';
  }
  if (!RegExp(r'^628[0-9]{8,12}$').hasMatch(normalized)) {
    return 'Format No. WA tidak valid';
  }
  return null;
}

String buildKostWhatsAppTemplate({
  required String ownerName,
  required String kostName,
  required String propertyCategory,
  required String kostType,
  required String address,
  required String district,
  required String city,
  required int pricePerMonth,
}) {
  final category = propertyCategory.trim().isNotEmpty
      ? propertyCategory.trim().toLowerCase()
      : 'properti';
  final locationParts = [address, district, city]
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(', ');
  return 'Halo Bapak/Ibu $ownerName, saya melihat $category '
      '*$kostName* ($kostType) di aplikasi *Keyloka*.\n\n'
      'Lokasi: $locationParts\n'
      'Harga: ${formatRupiah(pricePerMonth)}/bulan\n\n'
      'Apakah masih ada kamar/unit yang tersedia dan boleh tanya info lebih lanjut? Terima kasih.';
}

Future<void> openWhatsAppChat({
  required String phone,
  required String message,
}) async {
  final normalized = normalizeWhatsAppPhone(phone);
  if (normalized.isEmpty) {
    throw Exception('Nomor WhatsApp pemilik belum tersedia.');
  }
  final url =
      'https://wa.me/$normalized?text=${Uri.encodeComponent(message)}';
  await _externalLauncherChannel.invokeMethod('openExternalUrl', {'url': url});
}

Future<void> openGoogleMapsLocation({
  required double latitude,
  required double longitude,
  String? label,
}) async {
  final encodedLabel = (label != null && label.trim().isNotEmpty)
      ? '(${Uri.encodeComponent(label.trim())})'
      : '';
  final geoUrl =
      'geo:$latitude,$longitude?q=$latitude,$longitude$encodedLabel';
  final webUrl =
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  try {
    await _externalLauncherChannel
        .invokeMethod('openExternalUrl', {'url': geoUrl});
  } catch (_) {
    await _externalLauncherChannel
        .invokeMethod('openExternalUrl', {'url': webUrl});
  }
}

Future<void> shareTextContent({
  required String text,
  String? subject,
}) async {
  await _externalLauncherChannel.invokeMethod('shareText', {
    'text': text,
    if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
  });
}

String buildKostShareText({
  required String kostName,
  required String propertyCategory,
  required String kostType,
  required int pricePerMonth,
  required String address,
  required String district,
  required String city,
  required double rating,
  double? latitude,
  double? longitude,
}) {
  final category = propertyCategory.trim().isNotEmpty
      ? propertyCategory.trim()
      : 'Properti';
  final location = [address, district, city]
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .join(', ');
  final buffer = StringBuffer()
    ..writeln('Rekomendasi $category di Keyloka:')
    ..writeln('*$kostName* ($kostType)')
    ..writeln('Harga: ${formatRupiah(pricePerMonth)}/bulan')
    ..writeln('Rating: ${rating.toStringAsFixed(1)}/5.0')
    ..writeln('Lokasi: $location');
  if (latitude != null && longitude != null) {
    buffer.writeln(
      'Google Maps: https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
  }
  buffer.write('\nTemukan hunian nyaman lainnya di aplikasi Keyloka!');
  return buffer.toString();
}
