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
  final int durationCount;
  final String durationUnit;
  final int totalAmount;
  final int platformFee;
  final int ownerNetAmount;
  final String? paymentOrderId;
  final String? paymentUrl;
  final String paymentStatus;
  final String escrowStatus;
  final String disputeReason;
  final int pointsUsed;
  final int pointsDiscountAmount;
  final int pointsEarned;
  final String createdAt;
  final Kost? kost;

  bool get isSurvey => bookingType.toUpperCase() == 'SURVEI';
  bool get isDirectBooking => bookingType.toUpperCase() == 'SEWA';

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
    this.durationCount = 1,
    this.durationUnit = 'MONTH',
    this.totalAmount = 0,
    this.platformFee = 0,
    this.ownerNetAmount = 0,
    this.paymentOrderId,
    this.paymentUrl,
    this.paymentStatus = 'UNPAID',
    this.escrowStatus = 'NONE',
    this.disputeReason = '',
    this.pointsUsed = 0,
    this.pointsDiscountAmount = 0,
    this.pointsEarned = 0,
    required this.createdAt,
    this.kost,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, [int fallback = 0]) =>
        v is int ? v : int.tryParse('${v ?? fallback}') ?? fallback;

    return Booking(
      id: parseInt(json['id']),
      kostId: parseInt(json['kostId']),
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
      durationCount: parseInt(json['durationCount'], 1),
      durationUnit: json['durationUnit']?.toString() ?? 'MONTH',
      totalAmount: parseInt(json['totalAmount']),
      platformFee: parseInt(json['platformFee']),
      ownerNetAmount: parseInt(json['ownerNetAmount']),
      paymentOrderId: json['paymentOrderId']?.toString(),
      paymentUrl: json['paymentUrl']?.toString(),
      paymentStatus: json['paymentStatus']?.toString() ?? 'UNPAID',
      escrowStatus: json['escrowStatus']?.toString() ?? 'NONE',
      disputeReason: json['disputeReason']?.toString() ?? '',
      pointsUsed: parseInt(json['pointsUsed']),
      pointsDiscountAmount: parseInt(json['pointsDiscountAmount']),
      pointsEarned: parseInt(json['pointsEarned']),
      createdAt: json['createdAt'] ?? '',
      kost: json['kost'] != null && json['kost'] is Map<String, dynamic>
          ? Kost.fromJson(json['kost'] as Map<String, dynamic>)
          : null,
    );
  }
}
