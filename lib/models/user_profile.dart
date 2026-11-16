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
  final bool showWhatsapp;
  final bool isBanned;
  final String? bannedAt;
  final bool onboardingCompleted;
  final String preferredCategory;
  final bool hasPassword;
  final int creditBalance;
  final int payoutBalance;
  final int pointsBalance;
  final int totalPointsEarned;
  final String loyaltyLevel;
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
    this.showWhatsapp = false,
    this.isBanned = false,
    this.bannedAt,
    this.onboardingCompleted = true,
    this.preferredCategory = '',
    this.hasPassword = false,
    this.creditBalance = 0,
    this.payoutBalance = 0,
    this.pointsBalance = 0,
    this.totalPointsEarned = 0,
    this.loyaltyLevel = 'Bronze',
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
      showWhatsapp: json['showWhatsapp'] == true,
      isBanned: json['isBanned'] == true,
      bannedAt: json['bannedAt']?.toString(),
      onboardingCompleted: json['onboardingCompleted'] is bool
          ? json['onboardingCompleted'] as bool
          : true,
      preferredCategory: json['preferredCategory']?.toString() ?? '',
      hasPassword: json['hasPassword'] == true,
      creditBalance: json['creditBalance'] is int
          ? json['creditBalance'] as int
          : int.tryParse('${json['creditBalance'] ?? 0}') ?? 0,
      payoutBalance: json['payoutBalance'] is int
          ? json['payoutBalance'] as int
          : int.tryParse('${json['payoutBalance'] ?? 0}') ?? 0,
      pointsBalance: json['pointsBalance'] is int
          ? json['pointsBalance'] as int
          : int.tryParse('${json['pointsBalance'] ?? 0}') ?? 0,
      totalPointsEarned: json['totalPointsEarned'] is int
          ? json['totalPointsEarned'] as int
          : int.tryParse('${json['totalPointsEarned'] ?? 0}') ?? 0,
      loyaltyLevel: json['loyaltyLevel']?.toString() ?? 'Bronze',
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
      'showWhatsapp': showWhatsapp,
      'isBanned': isBanned,
      if (bannedAt != null) 'bannedAt': bannedAt,
      'onboardingCompleted': onboardingCompleted,
      'preferredCategory': preferredCategory,
      'hasPassword': hasPassword,
      'creditBalance': creditBalance,
      'payoutBalance': payoutBalance,
      'pointsBalance': pointsBalance,
      'totalPointsEarned': totalPointsEarned,
      'loyaltyLevel': loyaltyLevel,
      'lastLoginAt': lastLoginAt,
      'createdAt': createdAt,
    };
  }

  String get displayHandle {
    final clean = username.trim().replaceAll(RegExp(r'^@+'), '');
    if (clean.isNotEmpty) return '@$clean';
    final emailPrefix = email.split('@').first.trim();
    return emailPrefix.isNotEmpty ? '@$emailPrefix' : '@keyloka_user';
  }

  String get computedLevel {
    if (totalPointsEarned >= 700) return 'Platinum';
    if (totalPointsEarned >= 300) return 'Gold';
    if (totalPointsEarned >= 100) return 'Silver';
    return 'Bronze';
  }

  int get nextLevelTarget {
    if (totalPointsEarned >= 700) return 700;
    if (totalPointsEarned >= 300) return 700;
    if (totalPointsEarned >= 100) return 300;
    return 100;
  }

  String? get nextLevelName {
    if (totalPointsEarned >= 700) return null;
    if (totalPointsEarned >= 300) return 'Platinum';
    if (totalPointsEarned >= 100) return 'Gold';
    return 'Silver';
  }

  double get levelProgress {
    if (totalPointsEarned >= 700) return 1.0;
    final min = totalPointsEarned >= 300
        ? 300
        : (totalPointsEarned >= 100 ? 100 : 0);
    return ((totalPointsEarned - min) / (nextLevelTarget - min)).clamp(0.0, 1.0);
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
