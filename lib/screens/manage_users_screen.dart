import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserProfile> _users = [];
  bool _loading = true;
  String? _error;
  String _selectedRoleFilter = 'SEMUA';
  final Set<int> _updatingUserIds = {};

  static const List<Map<String, String>> _roleOptions = [
    {'value': 'PENYEWA', 'label': 'Penyewa Kost'},
    {'value': 'PEMILIK_KOST', 'label': 'Pemilik Kost'},
    {'value': 'STAFF', 'label': 'Staff'},
    {'value': 'ADMINISTRATOR', 'label': 'Administrator'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await ApiService.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
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

  List<UserProfile> get _filteredUsers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _users.where((user) {
      final matchesRole = _selectedRoleFilter == 'SEMUA' ||
          user.normalizedRole == _selectedRoleFilter;
      if (!matchesRole) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _updateUserRole(UserProfile user, String newRole) async {
    if (user.normalizedRole == newRole) return;
    final current = AuthService.currentUserNotifier.value;
    if (current == null) return;
    setState(() => _updatingUserIds.add(user.id));
    try {
      final updated = await ApiService.updateUserRole(
        userId: user.id,
        role: newRole,
        requesterId: current.id,
      );
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) {
          _users[idx] = updated;
        }
        _updatingUserIds.remove(user.id);
      });

      if (current.id == updated.id) {
        AuthService.currentUserNotifier.value = updated;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            'Role ${updated.name} diubah menjadi ${updated.roleLabel}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal mengubah role pengguna: $e'),
        ),
      );
    }
  }

  Future<void> _confirmToggleBanUser(UserProfile user) async {
    final willBan = !user.isBanned;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBan ? 'Ban Pengguna' : 'Buka Ban Pengguna'),
        content: Text(
          willBan
              ? 'Yakin ingin mem-banned akun ${user.name} (${user.email})? Pengguna tidak akan bisa masuk lagi dan sesi aktifnya akan dihentikan.'
              : 'Yakin ingin membuka ban akun ${user.name} (${user.email}) agar bisa masuk kembali?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  willBan ? Colors.red.shade700 : AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(willBan ? 'Ban' : 'Buka Ban'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _updatingUserIds.add(user.id));
    try {
      final updated = await ApiService.setUserBanStatus(
        userId: user.id,
        isBanned: willBan,
      );
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx >= 0) {
          _users[idx] = updated;
        }
        _updatingUserIds.remove(user.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              willBan ? Colors.red.shade700 : AppColors.primaryGreen,
          content: Text(
            willBan
                ? 'Pengguna ${user.name} berhasil dibanned.'
                : 'Ban pengguna ${user.name} berhasil dibuka.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            willBan
                ? 'Gagal mem-banned pengguna: $e'
                : 'Gagal membuka ban pengguna: $e',
          ),
        ),
      );
    }
  }

  Color _roleBadgeBg(UserProfile user) {
    if (user.isAdministrator) return const Color(0xFFEDE9FE);
    if (user.isStaff) return const Color(0xFFDBEAFE);
    if (user.isPemilikKost) return const Color(0xFFFEF3C7);
    return AppColors.lightGreenBg;
  }

  Color _roleBadgeFg(UserProfile user) {
    if (user.isAdministrator) return const Color(0xFF5B21B6);
    if (user.isStaff) return const Color(0xFF1D4ED8);
    if (user.isPemilikKost) return const Color(0xFF92400E);
    return AppColors.darkGreen;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    final currentUserId = AuthService.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
        title: const Text(
          'Kelola Pengguna',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama, email, atau nomor HP...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF6F7F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('SEMUA', 'Semua (${_users.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ADMINISTRATOR', 'Administrator'),
                      const SizedBox(width: 8),
                      _buildFilterChip('STAFF', 'Staff'),
                      const SizedBox(width: 8),
                      _buildFilterChip('PEMILIK_KOST', 'Pemilik Kost'),
                      const SizedBox(width: 8),
                      _buildFilterChip('PENYEWA', 'Penyewa Kost'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 42,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadUsers,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('Tidak ada pengguna yang sesuai.'),
                          )
                        : RefreshIndicator(
                            color: AppColors.primaryGreen,
                            onRefresh: _loadUsers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = filtered[index];
                                final isBusy =
                                    _updatingUserIds.contains(user.id);
                                final isProtected =
                                    user.id == 1 || user.id == currentUserId;

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor:
                                                AppColors.lightGreenBg,
                                            backgroundImage:
                                                user.avatarUrl.trim().isNotEmpty
                                                    ? NetworkImage(
                                                        user.avatarUrl.trim(),
                                                      )
                                                    : null,
                                            child: user.avatarUrl.trim().isEmpty
                                                ? Text(
                                                    user.name.isNotEmpty
                                                        ? user.name[0]
                                                            .toUpperCase()
                                                        : 'U',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors
                                                          .primaryGreen,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        user.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 14.5,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '#${user.id}',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  user.email,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                if (user.phone
                                                    .trim()
                                                    .isNotEmpty)
                                                  Text(
                                                    user.phone,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _roleBadgeBg(user),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  user.roleLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _roleBadgeFg(user),
                                                  ),
                                                ),
                                              ),
                                              if (user.isBanned) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color:
                                                          Colors.red.shade200,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'DIBANNED',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              value: _roleOptions.any(
                                                (r) =>
                                                    r['value'] ==
                                                    user.normalizedRole,
                                              )
                                                  ? user.normalizedRole
                                                  : 'PENYEWA',
                                              isDense: true,
                                              decoration: InputDecoration(
                                                labelText: 'Ubah Role',
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              items: _roleOptions
                                                  .map(
                                                    (opt) => DropdownMenuItem(
                                                      value: opt['value'],
                                                      child: Text(
                                                        opt['label']!,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: isBusy || user.id == 1
                                                  ? null
                                                  : (val) {
                                                      if (val != null) {
                                                        _updateUserRole(
                                                          user,
                                                          val,
                                                        );
                                                      }
                                                    },
                                            ),
                                          ),
                                          if (!isProtected) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: user.isBanned
                                                  ? 'Buka Ban Pengguna'
                                                  : 'Ban Pengguna',
                                              onPressed: isBusy
                                                  ? null
                                                  : () =>
                                                      _confirmToggleBanUser(
                                                        user,
                                                      ),
                                              icon: Icon(
                                                user.isBanned
                                                    ? Icons.lock_open_rounded
                                                    : Icons.block_rounded,
                                                color: user.isBanned
                                                    ? AppColors.primaryGreen
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (isBusy) ...[
                                        const SizedBox(height: 8),
                                        const LinearProgressIndicator(
                                          minHeight: 2,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.lightGreenBg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.darkGreen : Colors.grey.shade700,
      ),
      onSelected: (_) {
        setState(() => _selectedRoleFilter = value);
      },
    );
  }
}
