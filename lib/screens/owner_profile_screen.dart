import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/kost.dart';
import '../models/owner_post.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';

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
        ApiService.fetchOwnerPosts(widget.ownerId),
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

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
                                imageQuality: 82,
                              );
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

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.darkGreen],
                  ),
                  image: owner.coverUrl.trim().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(owner.coverUrl.trim()),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
              Positioned(
                left: 16,
                bottom: -36,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 37,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (owner.username.trim().isNotEmpty)
                            Text(
                              '@${owner.username.replaceAll(RegExp(r'^@+'), '')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(20),
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
                if (owner.city.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        owner.city.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (owner.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    owner.bio.trim(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (!_isOwnProfile) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _openChatWithOwner,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text(
                        'Chat Pemilik',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
        itemCount: _posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = _posts[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(post.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_canManagePosts)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openPostEditor(existing: post);
                          } else if (value == 'delete') {
                            _confirmDeletePost(post);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        post.imageUrl!,
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (post.kostId != null &&
                    post.kostName != null &&
                    post.kostName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () => _openKostById(post.kostId!),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.home_work_outlined,
                              size: 15,
                              color: AppColors.darkGreen,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                post.kostName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.darkGreen,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _properties.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final kost = _properties[index];
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
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kost.images.isNotEmpty
                      ? Image.network(
                          kost.images.first,
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 82,
                          height: 82,
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
                      Text(
                        kost.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${kost.district}, ${kost.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatRupiah(kost.pricePerMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
