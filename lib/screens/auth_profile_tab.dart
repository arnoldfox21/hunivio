import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../widgets/animated_vectors.dart';
import 'edit_profile_screen.dart';
import 'manage_properties_screen.dart';
import 'manage_users_screen.dart';
import 'onboarding_wizard_screen.dart';
import 'owner_profile_screen.dart';

class AuthProfileTab extends StatefulWidget {
  const AuthProfileTab({super.key});

  @override
  State<AuthProfileTab> createState() => _AuthProfileTabState();
}

class _AuthProfileTabState extends State<AuthProfileTab> {
  bool _loadingGoogle = false;

  Future<void> _handleGoogleAuth({required bool isRegisterFlow}) async {
    setState(() => _loadingGoogle = true);
    try {
      final result =
          await AuthService.signInOrRegisterWithGoogle(context: context);
      if (!mounted) return;
      if (result == null) {
        setState(() => _loadingGoogle = false);
        return;
      }
      if (result.isNewUser || !result.user.onboardingCompleted) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => OnboardingWizardScreen(user: result.user),
          ),
        );
        if (!mounted) return;
      }
      final currentUser = AuthService.currentUserNotifier.value ?? result.user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            result.isNewUser
                ? 'Pendaftaran berhasil! Selamat datang di HuniVio, ${currentUser.name}.'
                : 'Berhasil masuk sebagai ${currentUser.name} (${currentUser.email}).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Gagal ${isRegisterFlow ? 'mendaftar' : 'masuk'} dengan Google: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingGoogle = false);
      }
    }
  }

  Future<void> _openEditProfile(UserProfile user) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: user),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Profil berhasil diperbarui!'),
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Keluar dari Akun?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Anda harus masuk kembali dengan akun Google untuk mengakses profil dan pengajuan sewa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await AuthService.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anda telah keluar dari akun Google.'),
      ),
    );
  }

  int _calculateCompleteness(UserProfile user) {
    int filled = 0;
    const total = 6;
    if (user.name.trim().isNotEmpty) filled++;
    if (user.username.trim().isNotEmpty) filled++;
    if (user.bio.trim().isNotEmpty) filled++;
    if (user.city.trim().isNotEmpty) filled++;
    if (user.phone.trim().isNotEmpty) filled++;
    if (user.avatarUrl.trim().isNotEmpty) filled++;
    return ((filled / total) * 100).round();
  }

  String _formatJoinDate(String iso) {
    if (iso.trim().isEmpty) return 'Baru bergabung';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Baru bergabung';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return _buildLoggedOutView();
        }
        return _buildLoggedInView(user);
      },
    );
  }

  Widget _buildLoggedOutView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryGreen, AppColors.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: AnimatedVectorBackdrop(subtle: true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/hunivio_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Masuk atau Daftar di HuniVio',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kelola profil, simpan kost favorit, dan ajukan sewa dengan mudah menggunakan akun Google.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loadingGoogle
                        ? null
                        : () => _handleGoogleAuth(isRegisterFlow: false),
                    icon: _loadingGoogle
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: const Text(
                      'Masuk dengan Google',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loadingGoogle
                        ? null
                        : () => _handleGoogleAuth(isRegisterFlow: true),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Daftar Akun Baru',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Masuk lebih cepat dan aman dengan akun Google Anda.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(UserProfile user, {double size = 88}) {
    final fallbackUrl =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name.isNotEmpty ? user.name : 'User')}&background=1BAA56&color=ffffff&size=256&bold=true&format=png';
    final imageUrl =
        user.avatarUrl.trim().isNotEmpty ? user.avatarUrl.trim() : fallbackUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightGreenBg,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoggedInView(UserProfile user) {
    final completeness = _calculateCompleteness(user);
    final joinLabel = _formatJoinDate(user.createdAt);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Social-Media-Style Header Card (Cover + Overlapping Avatar + Bio)
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 178,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover Banner
                      GestureDetector(
                        onTap: () => _openEditProfile(user),
                        child: Container(
                          height: 132,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF1BAA56),
                                Color(0xFF0E7C3A),
                                Color(0xFF0A5226),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (user.coverUrl.trim().isNotEmpty)
                                Image.network(
                                  user.coverUrl.trim(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              // Subtle gradient overlay for contrast
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.05),
                                      Colors.black.withOpacity(0.25),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Overlapping Avatar
                      Positioned(
                        left: 16,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _openEditProfile(user),
                          child: _buildAvatarWidget(user, size: 90),
                        ),
                      ),

                      // Top-right Edit Profile CTA
                      Positioned(
                        right: 16,
                        bottom: 6,
                        child: Material(
                          color: Colors.white,
                          elevation: 1.5,
                          shadowColor: Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _openEditProfile(user),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCE4EC),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 15,
                                    color: AppColors.primaryGreen,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Edit Profil',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Identity & Bio
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primaryGreen,
                            size: 19,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            user.displayHandle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreenBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user.roleLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (user.bio.trim().isNotEmpty)
                        Text(
                          user.bio.trim(),
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Color(0xFF374151),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _openEditProfile(user),
                          child: Text(
                            '+ Tambahkan bio untuk memperkenalkan dirimu...',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Meta row: City & Join Date
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (user.city.trim().isNotEmpty)
                            _buildMetaChip(
                              Icons.location_on_outlined,
                              user.city.trim(),
                            ),
                          _buildMetaChip(
                            Icons.calendar_today_outlined,
                            'Bergabung $joinLabel',
                          ),
                          if (user.phone.trim().isNotEmpty)
                            _buildMetaChip(
                              Icons.phone_outlined,
                              user.phone.trim(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stats Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      value: 'Terverifikasi',
                      label: 'Akun Google',
                      icon: Icons.verified_user_outlined,
                    ),
                  ),
                  _verticalDivider(),
                  Expanded(
                    child: _buildStatItem(
                      value: user.roleLabel,
                      label: 'Peran Aktif',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  _verticalDivider(),
                  Expanded(
                    child: _buildStatItem(
                      value: '$completeness%',
                      label: 'Kelengkapan',
                      icon: Icons.pie_chart_outline_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Informasi Kontak & Akun Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Text(
                      'Informasi Akun',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _buildInfoTile(
                    icon: Icons.email_outlined,
                    title: 'Email Google',
                    value: user.email,
                  ),
                  const Divider(height: 1, indent: 52),
                  _buildInfoTile(
                    icon: Icons.phone_outlined,
                    title: 'Nomor WhatsApp',
                    value: user.phone.trim().isNotEmpty
                        ? user.phone.trim()
                        : 'Belum diisi',
                    onTap: () => _openEditProfile(user),
                  ),
                  const Divider(height: 1, indent: 52),
                  _buildInfoTile(
                    icon: Icons.location_city_outlined,
                    title: 'Kota / Domisili',
                    value: user.city.trim().isNotEmpty
                        ? user.city.trim()
                        : 'Belum diisi',
                    onTap: () => _openEditProfile(user),
                  ),
                ],
              ),
            ),
          ),

          if (user.canManageKost) ...[
            const SizedBox(height: 12),

            // Kelola Properti Card (hanya untuk Pemilik Properti, Staff, dan Administrator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8F8EE), Color(0xFFD1FAE5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.domain_rounded,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manajemen Properti',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.canApproveProperties
                                  ? 'Kelola & setujui pengajuan kost, apartemen, dan kontrakan.'
                                  : 'Kelola unit kost, apartemen, dan kontrakan Anda.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManagePropertiesScreen(user: user),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard_customize_rounded, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'Buka Kelola Properti',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],

          if (user.isAdministrator) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel Administrator',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola akun pengguna, ubah role, atau hapus akun.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ManageUsersScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.manage_accounts_rounded),
                        label: const Text(
                          'Manage User',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (user.isPemilikKost || user.canApproveProperties) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.dynamic_feed_rounded,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Postingan & Profil Publik',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Bagikan info kamar kosong, promo, atau update properti ke calon penyewa.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OwnerProfileScreen(
                                ownerId: user.id,
                                initialOwnerName: user.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text(
                          'Kelola Postingan & Lihat Profil Publik',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Keluar dari Akun Google',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primaryGreen, size: 21),
      title: Text(
        title,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
            )
          : null,
    );
  }
}
