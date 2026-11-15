class Review {
  final int id;
  final int kostId;
  final int userId;
  final String userName;
  final String userAvatar;
  final double ratingCleanliness;
  final double ratingSecurity;
  final double ratingAccuracy;
  final double overallRating;
  final String comment;
  final String? ownerReply;
  final String? ownerReplyAt;
  final String kostName;
  final String createdAt;

  const Review({
    required this.id,
    required this.kostId,
    required this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.ratingCleanliness,
    required this.ratingSecurity,
    required this.ratingAccuracy,
    required this.overallRating,
    required this.comment,
    this.ownerReply,
    this.ownerReplyAt,
    this.kostName = '',
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 5.0;

    return Review(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      userId: json['userId'] is int
          ? json['userId']
          : int.tryParse('${json['userId']}') ?? 0,
      userName: json['userName']?.toString() ?? 'Penghuni',
      userAvatar: json['userAvatar']?.toString() ?? '',
      ratingCleanliness: toDouble(json['ratingCleanliness']),
      ratingSecurity: toDouble(json['ratingSecurity']),
      ratingAccuracy: toDouble(json['ratingAccuracy']),
      overallRating: toDouble(json['overallRating']),
      comment: json['comment']?.toString() ?? '',
      ownerReply: json['ownerReply']?.toString(),
      ownerReplyAt: json['ownerReplyAt']?.toString(),
      kostName: json['kostName']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class ReviewReport {
  final int id;
  final int reviewId;
  final int kostId;
  final String kostName;
  final int reporterId;
  final String reporterName;
  final String reason;
  final String? details;
  final String status;
  final String reviewComment;
  final String reviewAuthorName;
  final double reviewOverallRating;
  final String createdAt;

  const ReviewReport({
    required this.id,
    required this.reviewId,
    required this.kostId,
    this.kostName = '',
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    this.details,
    this.status = 'OPEN',
    required this.reviewComment,
    required this.reviewAuthorName,
    required this.reviewOverallRating,
    required this.createdAt,
  });

  factory ReviewReport.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

    return ReviewReport(
      id: toInt(json['id']),
      reviewId: toInt(json['reviewId']),
      kostId: toInt(json['kostId']),
      kostName: json['kostName']?.toString() ?? '',
      reporterId: toInt(json['reporterId']),
      reporterName: json['reporterName']?.toString() ?? 'Pengguna',
      reason: json['reason']?.toString() ?? '',
      details: json['details']?.toString(),
      status: json['status']?.toString().toUpperCase() ?? 'OPEN',
      reviewComment: json['reviewComment']?.toString() ?? '',
      reviewAuthorName: json['reviewAuthorName']?.toString() ?? 'Penghuni',
      reviewOverallRating: toDouble(json['reviewOverallRating']),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
