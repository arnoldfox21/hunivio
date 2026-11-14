import 'kost.dart';

class Booking {
  final int id;
  final int kostId;
  final int? userId;
  final String tenantName;
  final String tenantPhone;
  final String startDate;
  final int durationMonths;
  final int totalPrice;
  final String bookingType; // 'SEWA' | 'SURVEI'
  final String surveyDateTime;
  final String paymentMethod;
  final String paymentStatus; // 'BELUM_BAYAR' | 'MENUNGGU_PEMBAYARAN' | 'LUNAS'
  final String invoiceNumber;
  final String status;
  final String? notes;
  final String createdAt;
  final Kost? kost;

  bool get isSurvey => bookingType.toUpperCase() == 'SURVEI';
  bool get isPaid => paymentStatus.toUpperCase() == 'LUNAS';

  const Booking({
    required this.id,
    required this.kostId,
    this.userId,
    required this.tenantName,
    required this.tenantPhone,
    required this.startDate,
    required this.durationMonths,
    required this.totalPrice,
    this.bookingType = 'SEWA',
    this.surveyDateTime = '',
    this.paymentMethod = 'COD',
    this.paymentStatus = 'BELUM_BAYAR',
    this.invoiceNumber = '',
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
      durationMonths: json['durationMonths'] is int
          ? json['durationMonths']
          : int.tryParse('${json['durationMonths']}') ?? 1,
      totalPrice: json['totalPrice'] is int
          ? json['totalPrice']
          : int.tryParse('${json['totalPrice']}') ?? 0,
      bookingType: json['bookingType']?.toString() ?? 'SEWA',
      surveyDateTime: json['surveyDateTime']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? 'COD',
      paymentStatus: json['paymentStatus']?.toString() ?? 'BELUM_BAYAR',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      status: json['status'] ?? 'MENUNGGU KONFIRMASI',
      notes: json['notes'],
      createdAt: json['createdAt'] ?? '',
      kost: json['kost'] != null && json['kost'] is Map<String, dynamic>
          ? Kost.fromJson(json['kost'] as Map<String, dynamic>)
          : null,
    );
  }
}
