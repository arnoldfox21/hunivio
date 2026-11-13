import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF1BAA56);
  static const Color darkGreen = Color(0xFF0E7C3A);
  static const Color lightGreenBg = Color(0xFFE8F7EE);
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
