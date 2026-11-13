import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  static const MethodChannel _nativeGoogleChannel =
      MethodChannel('com.hunigo.app/google_auth');

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: (!kIsWeb && Platform.isAndroid)
        ? null
        : GoogleOAuthCredentials.clientId,
  );

  static final ValueNotifier<UserProfile?> currentUserNotifier =
      ValueNotifier<UserProfile?>(null);

  static UserProfile? get currentUser => currentUserNotifier.value;

  static Future<UserProfile?> restoreSilentSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      String? accessToken;
      String? idToken;
      try {
        final auth = await account.authentication;
        accessToken = auth.accessToken;
        idToken = auth.idToken;
      } catch (_) {}

      final result = await ApiService.loginOrRegisterWithGoogle(
        googleId: account.id,
        email: account.email,
        name: account.displayName ?? _deriveNameFromEmail(account.email),
        avatarUrl: account.photoUrl ?? '',
        accessToken: accessToken,
        idToken: idToken,
      );
      currentUserNotifier.value = result.user;
      return result.user;
    } catch (_) {
      return null;
    }
  }

  static Future<GoogleAuthResult?> signInOrRegisterWithGoogle() async {
    // Gunakan native Android Google Account Picker agar langsung mengambil
    // data akun Google yang diklik tanpa terhalang ApiException: 10
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final nativeAccount = await _nativeGoogleChannel
            .invokeMapMethod<String, dynamic>('pickGoogleAccount');
        if (nativeAccount == null) {
          // User membatalkan dialog pemilihan akun Google
          return null;
        }

        final email = (nativeAccount['email'] ?? '').toString().trim();
        final googleId = (nativeAccount['googleId'] ?? '').toString().trim();
        final name = (nativeAccount['name'] ?? '').toString().trim();
        final avatarUrl = (nativeAccount['avatarUrl'] ?? '').toString().trim();

        if (email.isEmpty) {
          return null;
        }

        final result = await ApiService.loginOrRegisterWithGoogle(
          googleId: googleId.isNotEmpty
              ? googleId
              : 'google_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}',
          email: email,
          name: name.isNotEmpty ? name : _deriveNameFromEmail(email),
          avatarUrl: avatarUrl,
        );

        currentUserNotifier.value = result.user;
        return result;
      } on MissingPluginException {
        // Fallback ke GoogleSignIn jika aplikasi belum di-rebuild (masih hot reload)
      }
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final account = await _googleSignIn.signIn();
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

    final result = await ApiService.loginOrRegisterWithGoogle(
      googleId: account.id,
      email: account.email,
      name: account.displayName ?? _deriveNameFromEmail(account.email),
      avatarUrl: account.photoUrl ?? '',
      accessToken: accessToken,
      idToken: idToken,
    );

    currentUserNotifier.value = result.user;
    return result;
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
          : 'Pengguna HuniGo';
    }
    return words
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static Future<UserProfile> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String role,
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
    );
    currentUserNotifier.value = updated;
    return updated;
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    currentUserNotifier.value = null;
  }
}
