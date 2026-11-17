import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/kost.dart';
import '../models/owner_post.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/owner_post_card.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';
import 'post_detail_screen.dart';

class OwnerProfileScreen extends StatefulWidget {
  final int ownerId;
  final String? initialOwnerName;
  final Kost? sourceKost;

  const OwnerProfileScreen({
    super.key,
    required this.ownerId,
    this.initialOwnerName,
    this.sourceKost,
  });

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _updatingWhatsappSetting = false;
  String? _error;
  UserProfile? _owner;
  List<OwnerPost> _posts = [];
  List<Kost> _properties = [];

  bool get _isOwnProfile {
    final current = AuthService.currentUser;
    return current != null && current.id == widget.ownerId;
  }

  bool get _canManagePosts {
    final current = AuthService.currentUser;
    return _isOwnProfile && current != null && current.canManageKost;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiService.fetchUserById(widget.ownerId),
        ApiService.fetchOwnerPosts(
          widget.ownerId,
          viewerId: AuthService.currentUser?.id,
        ),
        ApiService.fetchKosts(ownerId: widget.ownerId),
      ]);
      if (!mounted) return;
      final owner = results[0] as UserProfile;
      final posts = results[1] as List<OwnerPost>;
      final kostList = results[2] as List<Kost>;
      final approved = kostList
          .where((k) => k.approvalStatus.toUpperCase() == 'APPROVED')
          .toList();

      setState(() {
        _owner = owner;
        _posts = posts;
        _properties = approved;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChatWithOwner() async {
    final kost = widget.sourceKost ??
        (_properties.isNotEmpty ? _properties.first : null);
    if (kost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemilik belum memiliki properti aktif untuk di-chat.'),
        ),
      );
      return;
    }
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk chat pemilik.'),
        ),
      );
      return;
    }
    if (user.id == widget.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat mengirim chat ke akun Anda sendiri.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KostChatScreen(kost: kost)),
    );
  }

  Future<void> _openWhatsAppOwner() async {
    final owner = _owner;
    if (owner == null || owner.phone.trim().isEmpty) return;
    try {
      await openWhatsAppChat(
        phone: owner.phone,
        message:
            'Halo ${owner.name}, saya melihat profil Anda di Keyloka dan ingin menanyakan informasi kamar/properti yang tersedia.',
      );
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _openPostEditor({OwnerPost? existing}) async {
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    int? selectedKostId = existing?.kostId;
    String? imageUrl = existing?.imageUrl;
    File? pickedImage;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  existing == null ? 'Buat Postingan Baru' : 'Edit Postingan',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Bagikan info kamar kosong, promo, atau kondisi terbaru properti Anda...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_properties.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _properties.any((k) => k.id == selectedKostId)
                        ? selectedKostId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Tautkan Properti (Opsional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tidak ditautkan ke properti'),
                      ),
                      ..._properties.map(
                        (k) => DropdownMenuItem<int?>(
                          value: k.id,
                          child: Text(
                            k.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => selectedKostId = v),
                  ),
                ],
                const SizedBox(height: 12),
                if (pickedImage != null ||
                    (imageUrl != null && imageUrl!.isNotEmpty))
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: pickedImage != null
                            ? Image.file(
                                pickedImage!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                imageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              setModalState(() {
                                pickedImage = null;
                                imageUrl = '';
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1400,
                                maxHeight: 1400,
                                imageQuality: 82,
                              );
                              if (!ctx.mounted) return;
                              if (picked != null) {
                                setModalState(() {
                                  pickedImage = File(picked.path);
                                });
                              }
                            },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Pilih Foto'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final text = contentCtrl.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Isi postingan tidak boleh kosong.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                String? finalImageUrl = imageUrl;
                                if (pickedImage != null) {
                                  finalImageUrl =
                                      await ApiService.uploadKostImage(
                                    pickedImage!,
                                  );
                                }
                                if (existing == null) {
                                  await ApiService.createOwnerPost(
                                    ownerId: widget.ownerId,
                                    content: text,
                                    imageUrl: finalImageUrl,
                                    kostId: selectedKostId,
                                  );
                                } else {
                                  await ApiService.updateOwnerPost(
                                    postId: existing.id,
                                    requesterId: AuthService.currentUser!.id,
                                    content: text,
                                    imageUrl: finalImageUrl,
                                    kostId: selectedKostId,
                                    clearKostId: selectedKostId == null,
                                  );
                                }
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                _loadData();
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setModalState(() => saving = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade700,
                                    content: Text('Gagal menyimpan: $e'),
                                  ),
                                );
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(saving ? 'Menyimpan...' : 'Publikasikan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), contentCtrl.dispose);
  }

  Future<void> _confirmDeletePost(OwnerPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Postingan'),
        content: const Text('Yakin ingin menghapus postingan ini?'),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteOwnerPost(
        postId: post.id,
        requesterId: AuthService.currentUser!.id,
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menghapus postingan: $e'),
        ),
      );
    }
  }

  void _openKostById(int kostId) {
    final match = _properties.where((k) => k.id == kostId).toList();
    if (match.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KostDetailScreen(
            kost: match.first,
            isFavorite: false,
            onToggleFavorite: () {},
            onBookingCreated: () {},
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _owner?.name.isNotEmpty == true
        ? _owner!.name
        : (widget.initialOwnerName ?? 'Pemilik Properti');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(displayName),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: _canManagePosts
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              onPressed: () => _openPostEditor(),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text(
                'Buat Postingan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gagal memuat profil: $_error'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(child: _buildProfileHeader()),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primaryGreen,
                          unselectedLabelColor: AppColors.textSecondary,
                          indicatorColor: AppColors.primaryGreen,
                          tabs: [
                            Tab(text: 'Postingan (${_posts.length})'),
                            Tab(text: 'Properti (${_properties.length})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsTab(),
                      _buildPropertiesTab(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final owner = _owner!;
    final fallbackAvatar =
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(owner.name.isNotEmpty ? owner.name : 'Pemilik')}&background=1BAA56&color=ffffff&size=256&bold=true&format=png';
    final avatarUrl =
        owner.avatarUrl.trim().isNotEmpty ? owner.avatarUrl.trim() : fallbackAvatar;
    final hasCover = owner.coverUrl.trim().isNotEmpty;

    final totalAvailableRooms =
        _properties.fold<int>(0, (sum, k) => sum + k.availableRooms);
    final totalReviews =
        _properties.fold<int>(0, (sum, k) => sum + k.reviewCount);
    final reviewedProperties =
        _properties.where((k) => k.reviewCount > 0).toList();
    final avgRating = reviewedProperties.isEmpty
        ? 0.0
        : reviewedProperties.fold<double>(0, (sum, k) => sum + k.rating) /
            reviewedProperties.length;
    final minPrice = _properties.isEmpty
        ? 0
        : _properties
            .map((k) => k.pricePerMonth)
            .reduce((a, b) => a < b ? a : b);
    final serviceAreas = _properties
        .map((k) => k.district.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');
    final isVerifiedOwner = owner.isVerifiedAccount;
    final canWhatsApp =
        !_isOwnProfile && owner.showWhatsapp && owner.phone.trim().isNotEmpty;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: hasCover
                    ? () => FullScreenImageViewer.open(
                          context,
                          imageUrl: owner.coverUrl.trim(),
                          heroTag: 'owner-cover-${owner.id}',
                        )
                    : null,
                child: Container(
                  height: 145,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryGreen, AppColors.darkGreen],
                    ),
                    image: hasCover
                        ? DecorationImage(
                            image: NetworkImage(owner.coverUrl.trim()),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.28),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -38,
                child: GestureDetector(
                  onTap: () => FullScreenImageViewer.open(
                    context,
                    imageUrl: avatarUrl,
                    heroTag: 'owner-avatar-${owner.id}',
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  owner.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (isVerifiedOwner) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 19,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ],
                          ),
                          if (owner.username.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@${owner.username.replaceAll(RegExp(r'^@+'), '')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        owner.roleLabel,
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
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (owner.city.trim().isNotEmpty)
                      _buildInfoMetaItem(
                        Icons.location_on_outlined,
                        owner.city.trim(),
                      ),
                    if (serviceAreas.isNotEmpty)
                      _buildInfoMetaItem(
                        Icons.map_outlined,
                        'Area: $serviceAreas',
                      ),
                    if (minPrice > 0)
                      _buildInfoMetaItem(
                        Icons.payments_outlined,
                        'Mulai ${formatRupiah(minPrice)}/bln',
                      ),
                  ],
                ),
                if (owner.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      owner.bio.trim(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _buildOwnerStatItem(
                        value: '${_properties.length}',
                        label: 'Properti',
                      ),
                      _buildStatDivider(),
                      _buildOwnerStatItem(
                        value: '$totalAvailableRooms',
                        label: 'Kamar Kosong',
                        highlight: totalAvailableRooms > 0,
                      ),
                      _buildStatDivider(),
                      _buildOwnerStatItem(
                        value: totalReviews == 0
                            ? '-'
                            : '${avgRating.toStringAsFixed(1)}★',
                        label: '$totalReviews Ulasan',
                      ),
                      _buildStatDivider(),
                      _buildOwnerStatItem(
                        value: '${_posts.length}',
                        label: 'Postingan',
                      ),
                    ],
                  ),
                ),
                if (_isOwnProfile && owner.canManageKost) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      activeColor: AppColors.primaryGreen,
                      secondary: const Icon(
                        Icons.chat_rounded,
                        color: Color(0xFF25D366),
                      ),
                      title: const Text(
                        'Tampilkan No. WhatsApp di Properti',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Aktifkan agar penyewa bisa chat langsung ke WhatsApp Anda.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: owner.showWhatsapp,
                      onChanged: _updatingWhatsappSetting
                          ? null
                          : _toggleShowWhatsapp,
                    ),
                  ),
                ],
                if (!_isOwnProfile) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _openChatWithOwner,
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Chat Pemilik',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (canWhatsApp) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF15803D),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              backgroundColor: const Color(0xFFF0FDF4),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openWhatsAppOwner,
                            icon: const Icon(Icons.chat_rounded, size: 18),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 26,
      width: 1,
      color: AppColors.cardBorder,
    );
  }

  Widget _buildOwnerStatItem({
    required String value,
    required String label,
    bool highlight = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primaryGreen : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPostDetail(
    OwnerPost post, {
    bool focusComment = false,
  }) async {
    final owner = _owner;
    if (owner == null) return;
    final updated = await Navigator.of(context).push<OwnerPost>(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          owner: owner,
          focusComment: focusComment,
          onOpenKostById: _openKostById,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == updated.id);
      if (idx >= 0) {
        _posts[idx] = updated;
      }
    });
  }

  Future<void> _togglePostLike(OwnerPost post) async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk menyukai postingan.'),
        ),
      );
      return;
    }
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;

    final prevLiked = post.isLiked;
    final prevCount = post.likeCount;
    setState(() {
      _posts[idx] = post.copyWith(
        isLiked: !prevLiked,
        likeCount: prevLiked
            ? (prevCount > 0 ? prevCount - 1 : 0)
            : prevCount + 1,
      );
    });

    try {
      final res = await ApiService.togglePostLike(post.id);
      if (!mounted) return;
      final currentIdx = _posts.indexWhere((p) => p.id == post.id);
      if (currentIdx >= 0) {
        setState(() {
          _posts[currentIdx] = _posts[currentIdx].copyWith(
            isLiked: res.liked,
            likeCount: res.likeCount,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      final currentIdx = _posts.indexWhere((p) => p.id == post.id);
      if (currentIdx >= 0) {
        setState(() {
          _posts[currentIdx] = _posts[currentIdx].copyWith(
            isLiked: prevLiked,
            likeCount: prevCount,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui suka: $e')),
      );
    }
  }

  Future<void> _toggleShowWhatsapp(bool value) async {
    final owner = _owner;
    if (owner == null || _updatingWhatsappSetting) return;
    if (value && owner.phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan isi Nomor WhatsApp Aktif di Edit Profil terlebih dahulu.',
          ),
        ),
      );
      return;
    }
    setState(() => _updatingWhatsappSetting = true);
    try {
      final updated = await AuthService.updateCurrentUserProfile(
        name: owner.name,
        phone: owner.phone,
        showWhatsapp: value,
      );
      if (!mounted) return;
      setState(() {
        _owner = updated;
        _updatingWhatsappSetting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            value
                ? 'Nomor WhatsApp kini ditampilkan di properti Anda.'
                : 'Nomor WhatsApp disembunyikan dari properti Anda.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingWhatsappSetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal memperbarui pengaturan WhatsApp: $e'),
        ),
      );
    }
  }

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dynamic_feed_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                _canManagePosts
                    ? 'Belum ada postingan. Bagikan info kamar kosong atau promo properti Anda!'
                    : 'Pemilik ini belum membuat postingan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final owner = _owner;
    if (owner == null) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFFF0F2F5),
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
          itemCount: _posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final post = _posts[index];
            return OwnerPostCard(
              post: post,
              owner: owner,
              canManage: _canManagePosts,
              onTapPost: () => _openPostDetail(post),
              onTapComment: () => _openPostDetail(post, focusComment: true),
              onTapLike: () => _togglePostLike(post),
              onTapImage: (post.imageUrl != null &&
                      post.imageUrl!.trim().isNotEmpty)
                  ? () => FullScreenImageViewer.open(
                        context,
                        imageUrl: post.imageUrl!,
                        heroTag: 'post-image-${post.id}',
                      )
                  : null,
              onTapKost:
                  post.kostId != null ? () => _openKostById(post.kostId!) : null,
              onEdit: () => _openPostEditor(existing: post),
              onDelete: () => _confirmDeletePost(post),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPropertiesTab() {
    if (_properties.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada properti aktif yang ditampilkan.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _properties.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final kost = _properties[index];
          final hasRooms = kost.availableRooms > 0;
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KostDetailScreen(
                    kost: kost,
                    isFavorite: false,
                    onToggleFavorite: () {},
                    onBookingCreated: () {},
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kost.images.isNotEmpty
                        ? Image.network(
                            kost.images.first,
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 92,
                            height: 92,
                            color: AppColors.lightGreenBg,
                            child: const Icon(
                              Icons.home_work_outlined,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightGreenBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${kost.propertyCategory} • ${kost.type}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              kost.reviewCount > 0
                                  ? '${kost.rating.toStringAsFixed(1)} (${kost.reviewCount})'
                                  : 'Baru',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          kost.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${kost.district}, ${kost.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${formatRupiah(kost.displayPrice)}${kost.displayPriceShortUnit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: hasRooms
                                    ? Colors.orange.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasRooms
                                    ? 'Sisa ${kost.availableRooms} kamar'
                                    : 'Penuh',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: hasRooms
                                      ? Colors.orange.shade900
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
