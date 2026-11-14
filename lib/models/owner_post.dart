class OwnerPost {
  final int id;
  final int ownerId;
  final String content;
  final String? imageUrl;
  final int? kostId;
  final String? kostName;
  final String? kostType;
  final String createdAt;
  final String updatedAt;

  const OwnerPost({
    required this.id,
    required this.ownerId,
    required this.content,
    this.imageUrl,
    this.kostId,
    this.kostName,
    this.kostType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OwnerPost.fromJson(Map<String, dynamic> json) {
    return OwnerPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
      content: (json['content'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      kostId: (json['kostId'] as num?)?.toInt(),
      kostName: json['kostName']?.toString(),
      kostType: json['kostType']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}
