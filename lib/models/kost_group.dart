class KostGroupRoom {
  final int kostId;
  final String kostName;
  final String kostImage;
  final String city;
  final String district;
  final bool isAdmin;
  final bool adminOnly;
  final int memberCount;
  final String lastMessage;
  final String lastSenderName;
  final String lastMessageAt;

  const KostGroupRoom({
    required this.kostId,
    required this.kostName,
    this.kostImage = '',
    this.city = '',
    this.district = '',
    this.isAdmin = false,
    this.adminOnly = false,
    this.memberCount = 1,
    this.lastMessage = '',
    this.lastSenderName = '',
    this.lastMessageAt = '',
  });

  factory KostGroupRoom.fromJson(Map<String, dynamic> json) {
    return KostGroupRoom(
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      kostName: json['kostName']?.toString() ?? 'Grup Penghuni',
      kostImage: json['kostImage']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      isAdmin: json['isAdmin'] == true,
      adminOnly: json['adminOnly'] == true,
      memberCount: json['memberCount'] is int
          ? json['memberCount']
          : int.tryParse('${json['memberCount']}') ?? 1,
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastSenderName: json['lastSenderName']?.toString() ?? '',
      lastMessageAt: json['lastMessageAt']?.toString() ?? '',
    );
  }
}

class KostGroupMessage {
  final int id;
  final int kostId;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final String senderRole; // 'ADMIN' | 'MEMBER'
  final String message;
  final String createdAt;

  const KostGroupMessage({
    required this.id,
    required this.kostId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = '',
    this.senderRole = 'MEMBER',
    required this.message,
    required this.createdAt,
  });

  factory KostGroupMessage.fromJson(Map<String, dynamic> json) {
    return KostGroupMessage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      senderId: json['senderId'] is int
          ? json['senderId']
          : int.tryParse('${json['senderId']}') ?? 0,
      senderName: json['senderName']?.toString() ?? 'Penghuni',
      senderAvatar: json['senderAvatar']?.toString() ?? '',
      senderRole: json['senderRole']?.toString().toUpperCase() ?? 'MEMBER',
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class KostGroupSettings {
  final int? pinnedMessageId;
  final String? pinnedText;
  final bool adminOnly;

  const KostGroupSettings({
    this.pinnedMessageId,
    this.pinnedText,
    this.adminOnly = false,
  });

  factory KostGroupSettings.fromJson(Map<String, dynamic> json) {
    return KostGroupSettings(
      pinnedMessageId: json['pinnedMessageId'] is int
          ? json['pinnedMessageId']
          : int.tryParse('${json['pinnedMessageId']}'),
      pinnedText: json['pinnedText']?.toString(),
      adminOnly: json['adminOnly'] == true,
    );
  }
}

class KostGroupMember {
  final int userId;
  final String name;
  final String avatarUrl;
  final String role; // 'ADMIN' | 'MEMBER'

  const KostGroupMember({
    required this.userId,
    required this.name,
    this.avatarUrl = '',
    this.role = 'MEMBER',
  });

  factory KostGroupMember.fromJson(Map<String, dynamic> json) {
    return KostGroupMember(
      userId: json['userId'] is int
          ? json['userId']
          : int.tryParse('${json['userId']}') ?? 0,
      name: json['name']?.toString() ?? 'Penghuni',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString().toUpperCase() ?? 'MEMBER',
    );
  }
}

class KostGroupDetail {
  final int kostId;
  final String kostName;
  final String kostImage;
  final int ownerId;
  final String myRole;
  final KostGroupSettings settings;
  final List<KostGroupMember> members;
  final List<KostGroupMessage> messages;

  const KostGroupDetail({
    required this.kostId,
    required this.kostName,
    this.kostImage = '',
    required this.ownerId,
    required this.myRole,
    required this.settings,
    required this.members,
    required this.messages,
  });

  factory KostGroupDetail.fromJson(Map<String, dynamic> json) {
    return KostGroupDetail(
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      kostName: json['kostName']?.toString() ?? 'Grup Penghuni',
      kostImage: json['kostImage']?.toString() ?? '',
      ownerId: json['ownerId'] is int
          ? json['ownerId']
          : int.tryParse('${json['ownerId']}') ?? 1,
      myRole: json['myRole']?.toString().toUpperCase() ?? 'MEMBER',
      settings: KostGroupSettings.fromJson(
        (json['settings'] as Map<String, dynamic>?) ?? const {},
      ),
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((e) => KostGroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((e) => KostGroupMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
