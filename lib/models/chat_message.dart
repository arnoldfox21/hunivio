import 'kost.dart';

class ChatMessage {
  final int id;
  final int kostId;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final int receiverId;
  final String message;
  final String status; // 'SENT' | 'DELIVERED' | 'READ'
  final String createdAt;
  final int unreadCount;
  final Kost? kost;

  const ChatMessage({
    required this.id,
    required this.kostId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = '',
    required this.receiverId,
    required this.message,
    this.status = 'SENT',
    required this.createdAt,
    this.unreadCount = 0,
    this.kost,
  });

  ChatMessage copyWith({
    String? status,
    int? unreadCount,
    Kost? kost,
  }) {
    return ChatMessage(
      id: id,
      kostId: kostId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      kost: kost ?? this.kost,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      kostId: json['kostId'] is int
          ? json['kostId']
          : int.tryParse('${json['kostId']}') ?? 0,
      senderId: json['senderId'] is int
          ? json['senderId']
          : int.tryParse('${json['senderId']}') ?? 0,
      senderName: json['senderName']?.toString() ?? 'Pengguna',
      senderAvatar: json['senderAvatar']?.toString() ?? '',
      receiverId: json['receiverId'] is int
          ? json['receiverId']
          : int.tryParse('${json['receiverId']}') ?? 1,
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'SENT',
      createdAt: json['createdAt']?.toString() ?? '',
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount']
          : int.tryParse('${json['unreadCount']}') ?? 0,
      kost: json['kost'] is Map<String, dynamic>
          ? Kost.fromJson(json['kost'] as Map<String, dynamic>)
          : null,
    );
  }
}
