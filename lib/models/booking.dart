import 'kost.dart';

class Booking {
  final int id;
  final int kostId;
  final String tenantName;
  final String tenantPhone;
  final String startDate;
  final int durationMonths;
  final int totalPrice;
  final String status;
  final String? notes;
  final String createdAt;
  final Kost? kost;

  const Booking({
    required this.id,
    required this.kostId,
    required this.tenantName,
    required this.tenantPhone,
    required this.startDate,
    required this.durationMonths,
    required this.totalPrice,
    required this.status,
    this.notes,
    required this.createdAt,
    this.kost,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      tenantName: json['tenantName'] ?? '',
      tenantPhone: json['tenantPhone'] ?? '',
      startDate: json['startDate'] ?? '',
      durationMonths: json['durationMonths'] is int
          ? json['durationMonths']
          : int.tryParse('${json['durationMonths']}') ?? 1,
      totalPrice: json['totalPrice'] is int
          ? json['totalPrice']
          : int.tryParse('${json['totalPrice']}') ?? 0,
      status: json['status'] ?? 'PENDING',
      notes: json['notes'],
      createdAt: json['createdAt'] ?? '',
      kost: json['kost'] != null && json['kost'] is Map<String, dynamic>
          ? Kost.fromJson(json['kost'] as Map<String, dynamic>)
          : null,
    );
  }
}
