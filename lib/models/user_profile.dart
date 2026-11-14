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
  final bool onboardingCompleted;
  final String preferredCategory;
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
    this.onboardingCompleted = true,
    this.preferredCategory = '',
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
      onboardingCompleted: json['onboardingCompleted'] is bool
          ? json['onboardingCompleted'] as bool
          : true,
      preferredCategory: json['preferredCategory']?.toString() ?? '',
      lastLoginAt: json['lastLoginAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'googleId': googleId,
      'email': email,
      'name': name,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'username': username,
      'bio': bio,
      'city': city,
      'coverUrl': coverUrl,
      'role': role,
      'onboardingCompleted': onboardingCompleted,
      'preferredCategory': preferredCategory,
      'lastLoginAt': lastLoginAt,
      'createdAt': createdAt,
    };
  }

  String get displayHandle {
    final clean = username.trim().replaceAll(RegExp(r'^@+'), '');
    if (clean.isNotEmpty) return '@$clean';
    final emailPrefix = email.split('@').first.trim();
    return emailPrefix.isNotEmpty ? '@$emailPrefix' : '@hunivio_user';
  }

  String get normalizedRole {
    final upper = role.trim().toUpperCase();
    if (upper == 'PEMILIK') return 'PEMILIK_KOST';
    return upper.isEmpty ? 'PENYEWA' : upper;
  }

  bool get isAdministrator => normalizedRole == 'ADMINISTRATOR';

  bool get isStaff => normalizedRole == 'STAFF';

  bool get isPemilikKost => normalizedRole == 'PEMILIK_KOST';

  bool get canApproveProperties => isAdministrator || isStaff;

  bool get canManageKost => isAdministrator || isStaff || isPemilikKost;

  String get roleLabel {
    switch (normalizedRole) {
      case 'ADMINISTRATOR':
        return 'Administrator';
      case 'STAFF':
        return 'Staff';
      case 'PEMILIK_KOST':
        return 'Pemilik Kost';
      default:
        return 'Penyewa Kost';
    }
  }
}

class GoogleAuthResult {
  final UserProfile user;
  final String accessToken;
  final bool isNewUser;

  const GoogleAuthResult({
    required this.user,
    this.accessToken = '',
    required this.isNewUser,
  });

  factory GoogleAuthResult.fromJson(Map<String, dynamic> json) {
    return GoogleAuthResult(
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: (json['accessToken'] ?? '').toString(),
      isNewUser: json['isNewUser'] == true,
    );
  }
}
