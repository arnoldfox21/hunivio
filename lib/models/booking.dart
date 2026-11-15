import 'kost.dart';

class Booking {
  final int id;
  final int kostId;
  final int? userId;
  final String tenantName;
  final String tenantPhone;
  final String startDate;
  final String bookingType;
  final String surveyDateTime;
  final String status;
  final String? notes;
  final String createdAt;
  final Kost? kost;

  bool get isSurvey => bookingType.toUpperCase() == 'SURVEI';

  const Booking({
    required this.id,
    required this.kostId,
    this.userId,
    required this.tenantName,
    required this.tenantPhone,
    required this.startDate,
    this.bookingType = 'SURVEI',
    this.surveyDateTime = '',
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
      userId: json['userId'] is int
          ? json['userId']
          : int.tryParse('${json['userId']}'),
      tenantName: json['tenantName'] ?? '',
      tenantPhone: json['tenantPhone'] ?? '',
      startDate: json['startDate'] ?? '',
      bookingType: json['bookingType']?.toString() ?? 'SURVEI',
      surveyDateTime: json['surveyDateTime']?.toString() ?? '',
      status: json['status'] ?? 'TERKIRIM',
      notes: json['notes'],
      createdAt: json['createdAt'] ?? '',
      kost: json['kost'] != null && json['kost'] is Map<String, dynamic>
          ? Kost.fromJson(json['kost'] as Map<String, dynamic>)
          : null,
    );
  }
}
