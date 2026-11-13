class UserProfile {
  final int id;
  final String googleId;
  final String email;
  final String name;
  final String avatarUrl;
  final String phone;
  final String username;
  final String bio;
  final String city;
  final String coverUrl;
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
    this.username = '',
    this.bio = '',
    this.city = '',
    this.coverUrl = '',
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
      username: json['username']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'PENYEWA',
      lastLoginAt: json['lastLoginAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  String get displayHandle {
    final clean = username.trim().replaceAll(RegExp(r'^@+'), '');
    if (clean.isNotEmpty) return '@$clean';
    final emailPrefix = email.split('@').first.trim();
    return emailPrefix.isNotEmpty ? '@$emailPrefix' : '@hunigo_user';
  }

  String get normalizedRole {
    final upper = role.trim().toUpperCase();
    if (upper == 'PEMILIK') return 'PEMILIK_KOST';
    return upper.isEmpty ? 'PENYEWA' : upper;
  }

  bool get isAdministrator => normalizedRole == 'ADMINISTRATOR';

  bool get isPemilikKost => normalizedRole == 'PEMILIK_KOST';

  bool get canManageKost => isAdministrator || isPemilikKost;

  String get roleLabel {
    switch (normalizedRole) {
      case 'ADMINISTRATOR':
        return 'Administrator';
      case 'PEMILIK_KOST':
        return 'Pemilik Kost';
      default:
        return 'Penyewa Kost';
    }
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
