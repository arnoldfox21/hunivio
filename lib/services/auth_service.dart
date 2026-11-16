import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'api_service.dart';

class GoogleOAuthCredentials {
  static const String clientId =
      '946056205847-4rh8tk8j7oha26gh9fs80olh43juh77m.apps.googleusercontent.com';
  static const String projectId = 'celestial-gecko-465811-m4';
  static const String authUri = 'https://accounts.google.com/o/oauth2/auth';
  static const String tokenUri = 'https://oauth2.googleapis.com/token';
  static const String authProviderX509CertUrl =
      'https://www.googleapis.com/oauth2/v1/certs';
}

class AuthService {
  static const String _prefsLoggedInKey = 'hunivio_is_logged_in';
  static const String _prefsUserKey = 'hunivio_cached_user';
  static const String _prefsTokenKey = 'hunivio_auth_token';
  static const String _prefsAuthMethodKey = 'hunivio_auth_method';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: (!kIsWeb && Platform.isAndroid)
        ? null
        : GoogleOAuthCredentials.clientId,
  );

  static final ValueNotifier<UserProfile?> currentUserNotifier =
      ValueNotifier<UserProfile?>(null);

  static UserProfile? get currentUser => currentUserNotifier.value;

  static Future<void> _saveSession(
    UserProfile user, {
    String? accessToken,
    String? authMethod,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsLoggedInKey, true);
    await prefs.setString(_prefsUserKey, jsonEncode(user.toJson()));
    if (authMethod != null && authMethod.trim().isNotEmpty) {
      await prefs.setString(_prefsAuthMethodKey, authMethod.trim());
    }
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      await prefs.setString(_prefsTokenKey, accessToken.trim());
      ApiService.setAuthToken(accessToken.trim());
    }
  }

  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsLoggedInKey);
    await prefs.remove(_prefsUserKey);
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsAuthMethodKey);
    ApiService.setAuthToken(null);
  }

  static Future<UserProfile?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_prefsLoggedInKey) ?? false;
      if (!isLoggedIn) return null;
      final token = prefs.getString(_prefsTokenKey);
      if (token != null && token.trim().isNotEmpty) {
        ApiService.setAuthToken(token.trim());
      }
      final raw = prefs.getString(_prefsUserKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Dipanggil setiap aplikasi pertama dibuka.
  /// Mempertahankan sesi login tersimpan dan melakukan refresh token Google.
  /// Jika refresh token gagal, sesi akan otomatis logout.
  static Future<UserProfile?> restoreAndRefreshSession() async {
    ApiService.onSessionInvalidated ??= (_) => forceSignOut();
    final cachedUser = await _loadCachedUser();
    if (cachedUser == null) {
      currentUserNotifier.value = null;
      return null;
    }
    if (cachedUser.isBanned) {
      await forceSignOut();
      return null;
    }

    // Pertahankan status login sementara proses refresh token berjalan
    currentUserNotifier.value = cachedUser;

    final prefs = await SharedPreferences.getInstance();
    final authMethod = prefs.getString(_prefsAuthMethodKey) ?? 'google';
    if (authMethod == 'email') {
      try {
        final me = await ApiService.fetchMe();
        if (me == null) {
          await signOut();
          return null;
        }
        if (me.isBanned) {
          await forceSignOut();
          return null;
        }
        await _saveSession(me, authMethod: 'email');
        currentUserNotifier.value = me;
        ApiService.onSessionInvalidated ??= (_) => forceSignOut();
        return me;
      } catch (_) {
        // Pertahankan sesi lokal jika offline, kecuali token invalid (ditangani onSessionInvalidated)
        return cachedUser;
      }
    }

    try {
      final account =
          await _googleSignIn.signInSilently(reAuthenticate: true);
      if (account == null) {
        await signOut();
        return null;
      }

      final auth = await account.authentication;
      final accessToken = auth.accessToken?.trim();
      final idToken = auth.idToken?.trim();

      if ((accessToken == null || accessToken.isEmpty) &&
          (idToken == null || idToken.isEmpty)) {
        await signOut();
        return null;
      }

      final displayName =
          (account.displayName != null && account.displayName!.trim().isNotEmpty)
              ? account.displayName!.trim()
              : (cachedUser.name.isNotEmpty
                  ? cachedUser.name
                  : _deriveNameFromEmail(account.email));

      final googlePhoto = account.photoUrl?.trim() ?? '';
      final resolvedAvatar = googlePhoto.isNotEmpty
          ? googlePhoto
          : (cachedUser.avatarUrl.trim().isNotEmpty
              ? cachedUser.avatarUrl.trim()
              : _buildDefaultAvatarUrl(displayName));

      final result = await ApiService.loginOrRegisterWithGoogle(
        googleId: account.id,
        email: account.email,
        name: displayName,
        avatarUrl: resolvedAvatar,
        accessToken: accessToken,
        idToken: idToken,
      );

      await _saveSession(result.user, accessToken: result.accessToken);
      currentUserNotifier.value = result.user;
      ApiService.onSessionInvalidated ??= (_) => forceSignOut();
      return result.user;
    } catch (_) {
      // Refresh token gagal -> logout otomatis
      await signOut();
      return null;
    }
  }

  /// Alias kompatibilitas untuk pemanggil lama.
  static Future<UserProfile?> restoreSilentSession() =>
      restoreAndRefreshSession();

  /// Login atau daftar menggunakan popup bawaan Google Sign-In
  /// yang menampilkan foto profil, nama lengkap, dan email akun Google.
  static Future<GoogleAuthResult?> signInOrRegisterWithGoogle({
    BuildContext? context,
  }) async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        return null;
      }
      final detail = (e.message != null && e.message!.trim().isNotEmpty)
          ? e.message!.trim()
          : e.code;
      throw Exception(
        'Google Sign-In gagal ($detail). '
        'Jika error ApiException 10, daftarkan package com.hunivio.app dan SHA-1 debug keystore di Google Cloud Console.',
      );
    }

    if (account == null) {
      return null;
    }

    String? accessToken;
    String? idToken;
    try {
      final auth = await account.authentication;
      accessToken = auth.accessToken;
      idToken = auth.idToken;
    } catch (_) {}

    final displayName =
        (account.displayName != null && account.displayName!.trim().isNotEmpty)
            ? account.displayName!.trim()
            : _deriveNameFromEmail(account.email);

    // Pastikan foto profil dari Google (account.photoUrl) disimpan saat pertama login
    final googlePhoto = account.photoUrl?.trim() ?? '';
    final resolvedAvatar = googlePhoto.isNotEmpty
        ? googlePhoto
        : _buildDefaultAvatarUrl(displayName);

    final result = await ApiService.loginOrRegisterWithGoogle(
      googleId: account.id,
      email: account.email,
      name: displayName,
      avatarUrl: resolvedAvatar,
      accessToken: accessToken,
      idToken: idToken,
    );

    await _saveSession(
      result.user,
      accessToken: result.accessToken,
      authMethod: 'google',
    );
    ApiService.onSessionInvalidated ??= (_) => forceSignOut();
    currentUserNotifier.value = result.user;
    return result;
  }

  static Future<GoogleAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await ApiService.loginWithEmail(
      email: email,
      password: password,
    );
    await _saveSession(
      result.user,
      accessToken: result.accessToken,
      authMethod: 'email',
    );
    currentUserNotifier.value = result.user;
    ApiService.onSessionInvalidated ??= (_) => forceSignOut();
    return result;
  }

  static Future<UserProfile> setOrChangePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final updated = await ApiService.setOrChangePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _saveSession(updated);
    currentUserNotifier.value = updated;
    return updated;
  }

  static String _buildDefaultAvatarUrl(String name) {
    final encoded = Uri.encodeComponent(name.trim().isNotEmpty ? name : 'User');
    return 'https://ui-avatars.com/api/?name=$encoded&background=1BAA56&color=ffffff&size=256&bold=true&format=png';
  }

  static String _deriveNameFromEmail(String email) {
    final localPart = email.split('@').first;
    final words = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\d+$'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return localPart.isNotEmpty
          ? '${localPart[0].toUpperCase()}${localPart.substring(1)}'
          : 'Pengguna HuniVio';
    }
    return words
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static Future<UserProfile> updateCurrentUserProfile({
    required String name,
    required String phone,
    String? role,
    String? username,
    String? bio,
    String? city,
    String? avatarUrl,
    String? coverUrl,
    bool? showWhatsapp,
  }) async {
    final user = currentUserNotifier.value;
    if (user == null) {
      throw Exception('Belum login');
    }
    final updated = await ApiService.updateUserProfile(
      userId: user.id,
      name: name,
      phone: phone,
      role: role,
      username: username,
      bio: bio,
      city: city,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      showWhatsapp: showWhatsapp,
    );
    await _saveSession(updated);
    currentUserNotifier.value = updated;
    return updated;
  }

  static Future<UserProfile> completeOnboarding({
    required String role,
    String? preferredCategory,
    String? city,
    String? phone,
  }) async {
    final result = await ApiService.completeOnboarding(
      role: role,
      preferredCategory: preferredCategory,
      city: city,
      phone: phone,
    );
    await _saveSession(result.user, accessToken: result.accessToken);
    currentUserNotifier.value = result.user;
    return result.user;
  }

  static Future<void> verifyActiveSession() async {
    if (currentUserNotifier.value == null) return;
    try {
      final me = await ApiService.fetchMe();
      if (me != null) {
        if (me.isBanned) {
          await forceSignOut();
        } else {
          await _saveSession(me);
          currentUserNotifier.value = me;
        }
      }
    } catch (_) {}
  }

  static Future<void> forceSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _clearSession();
    currentUserNotifier.value = null;
  }

  static Future<void> signOut() async {
    final prevUser = currentUserNotifier.value;
    if (prevUser != null) {
      try {
        await ApiService.updateUserFcmToken(
          userId: prevUser.id,
          fcmToken: '',
        );
      } catch (_) {}
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _clearSession();
    currentUserNotifier.value = null;
  }
}
