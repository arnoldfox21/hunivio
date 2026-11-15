class OwnerPost {
  final int id;
  final int ownerId;
  final String content;
  final String? imageUrl;
  final int? kostId;
  final String? kostName;
  final String? kostType;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
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
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  OwnerPost copyWith({
    String? content,
    String? imageUrl,
    int? kostId,
    String? kostName,
    String? kostType,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return OwnerPost(
      id: id,
      ownerId: ownerId,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      kostId: kostId ?? this.kostId,
      kostName: kostName ?? this.kostName,
      kostType: kostType ?? this.kostType,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory OwnerPost.fromJson(Map<String, dynamic> json) {
    return OwnerPost(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
      content: (json['content'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString(),
      kostId: (json['kostId'] as num?)?.toInt(),
      kostName: json['kostName']?.toString(),
      kostType: json['kostType']?.toString(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] == true,
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

class OwnerPostComment {
  final int id;
  final int postId;
  final int userId;
  final String userName;
  final String userAvatarUrl;
  final String userRole;
  final String content;
  final String createdAt;
  final String updatedAt;

  const OwnerPostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.userRole,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OwnerPostComment.fromJson(Map<String, dynamic> json) {
    return OwnerPostComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['postId'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userName: (json['userName'] ?? 'Pengguna').toString(),
      userAvatarUrl: (json['userAvatarUrl'] ?? '').toString(),
      userRole: (json['userRole'] ?? 'PENCARI_KOST').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}
