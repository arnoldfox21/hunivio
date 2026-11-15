import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../widgets/location_autocomplete_field.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _phoneCtrl;

  String? _avatarUrl;
  String? _coverUrl;
  File? _pickedAvatarFile;
  File? _pickedCoverFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _usernameCtrl = TextEditingController(
      text: widget.user.username.replaceAll(RegExp(r'^@+'), ''),
    );
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _cityCtrl = TextEditingController(text: widget.user.city);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
    _avatarUrl = widget.user.avatarUrl;
    _coverUrl = widget.user.coverUrl;
    _showWhatsapp = widget.user.showWhatsapp;
  }

  late bool _showWhatsapp;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isCover}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isCover ? 'Pilih Foto Sampul' : 'Pilih Foto Profil',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primaryGreen,
              ),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryGreen,
              ),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            if (isCover &&
                ((_coverUrl != null && _coverUrl!.isNotEmpty) ||
                    _pickedCoverFile != null))
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade600),
                title: Text(
                  'Hapus Foto Sampul',
                  style: TextStyle(color: Colors.red.shade600),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _pickedCoverFile = null;
                    _coverUrl = '';
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: isCover ? 1400 : 800,
      imageQuality: 82,
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isCover) {
        _pickedCoverFile = File(picked.path);
      } else {
        _pickedAvatarFile = File(picked.path);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      String? finalAvatarUrl = _avatarUrl;
      String? finalCoverUrl = _coverUrl;

      if (_pickedAvatarFile != null) {
        finalAvatarUrl = await ApiService.uploadKostImage(_pickedAvatarFile!);
      }
      if (_pickedCoverFile != null) {
        finalCoverUrl = await ApiService.uploadKostImage(_pickedCoverFile!);
      }

      await AuthService.updateCurrentUserProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        avatarUrl: finalAvatarUrl,
        coverUrl: finalCoverUrl,
        showWhatsapp: _showWhatsapp,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menyimpan profil: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackAvatar =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'User')}&background=1BAA56&color=ffffff&size=256&bold=true&format=png';
    final effectiveAvatarUrl =
        (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty)
            ? _avatarUrl!.trim()
            : fallbackAvatar;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
        title: const Text(
          'Edit Profil',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  )
                : const Text(
                    'Simpan',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Cover + Overlapping Avatar
            SizedBox(
              height: 196,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(isCover: true),
                    child: Container(
                      height: 146,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1BAA56), Color(0xFF0A6832)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_pickedCoverFile != null)
                            Image.file(_pickedCoverFile!, fit: BoxFit.cover)
                          else if (_coverUrl != null &&
                              _coverUrl!.trim().isNotEmpty)
                            Image.network(
                              _coverUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          Container(
                            color: Colors.black.withOpacity(0.22),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Ubah Foto Sampul',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(isCover: false),
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _pickedAvatarFile != null
                                  ? Image.file(
                                      _pickedAvatarFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      effectiveAvatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppColors.lightGreenBg,
                                        alignment: Alignment.center,
                                        child: Text(
                                          widget.user.name.isNotEmpty
                                              ? widget.user.name[0]
                                                  .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primaryGreen,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
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
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nama tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'misal: kurniawan_id',
                        prefixText: '@',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        hintText:
                            'Ceritakan tentang dirimu, kampus, atau kost yang kamu kelola...',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 42),
                          child: Icon(Icons.edit_note_rounded),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    LocationAutocompleteField(
                      controller: _cityCtrl,
                      type: LocationAutocompleteType.city,
                      labelText: 'Kota / Domisili',
                      hintText: 'Misal: Kota Malang',
                      prefixIcon: const Icon(Icons.location_city_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor WhatsApp Aktif',
                        hintText: 'Contoh: 081234567890',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (widget.user.canManageKost) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          activeColor: AppColors.primaryGreen,
                          title: const Text(
                            'Tampilkan Nomor WhatsApp di Properti',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Penyewa dapat chat langsung ke WhatsApp Anda dari halaman properti.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _showWhatsapp,
                          onChanged: (val) =>
                              setState(() => _showWhatsapp = val),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Peran Pengguna',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        helperText:
                            'Peran akun terkunci dan hanya dapat diubah oleh Staff/Admin.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.user.roleLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _saveProfile,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          _saving ? 'Menyimpan...' : 'Simpan Perubahan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    if (widget.user.id != 1) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _saving ? null : _confirmDeleteAccount,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text(
                            'Hapus Akun Permanen',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun Permanen?'),
        content: const Text(
          'Semua data profil, favorit, dan riwayat akun Anda akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Akun'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ApiService.deleteMyAccount();
      await AuthService.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun Anda berhasil dihapus.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }
}
