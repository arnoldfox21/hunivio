class UserProfile {
  final int id;
  final String googleId;
  final String email;
  final String name;
  final String avatarUrl;
  final String phone;
  final String role;
  final String lastLoginAt;
  final String createdAt;

  const UserProfile({
    required this.id,
    required this.googleId,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.phone,
    required this.role,
    required this.lastLoginAt,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      googleId: json['googleId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'PENYEWA',
      lastLoginAt: json['lastLoginAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class GoogleAuthResult {
  final UserProfile user;
  final bool isNewUser;

  const GoogleAuthResult({
    required this.user,
    required this.isNewUser,
  });

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) {
    return GoogleAuthResult(
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      isNewUser: json['isNewUser'] == true,
    );
  }
}
