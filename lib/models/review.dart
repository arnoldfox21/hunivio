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
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
