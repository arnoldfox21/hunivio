import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking.dart';
import '../models/kost.dart';
import '../models/review.dart';
import '../models/user_profile.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';
import '../widgets/facility_checkbox_group.dart';
import '../widgets/location_autocomplete_field.dart';
import 'add_property_wizard_screen.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';
import 'kost_group_chat_screen.dart';
import 'kost_location_picker_screen.dart';
import 'owner_wallet_screen.dart';

class ManagePropertiesScreen extends StatefulWidget {
  final UserProfile user;

  const ManagePropertiesScreen({super.key, required this.user});

  @override
  State<ManagePropertiesScreen> createState() => _ManagePropertiesScreenState();
}

class _ManagePropertiesScreenState extends State<ManagePropertiesScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;
  List<Kost> _kosts = [];
  List<Kost> _pendingKosts = [];
  List<ReviewReport> _reviewReports = [];
  List<Booking> _incomingBookings = [];
  bool _loading = true;
  bool _loadingPending = false;
  bool _loadingBookings = true;
  final Set<int> _processingApprovalIds = {};
  final Set<int> _processingReportIds = {};
  String? _error;

  bool get _canApprove => widget.user.canApproveProperties;

  bool _approvalTabLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _canApprove ? 3 : 2, vsync: this);
    if (_canApprove) {
      _tabCtrl.addListener(_onTabChanged);
    }
    _loadProperties();
    _loadIncomingBookings();
  }

  void _onTabChanged() {
    if (_canApprove && _tabCtrl.index == 2 && !_approvalTabLoaded) {
      _approvalTabLoaded = true;
      _loadPendingProperties();
    }
  }

  @override
  void dispose() {
    if (_canApprove) {
      _tabCtrl.removeListener(_onTabChanged);
    }
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIncomingBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final list = await ApiService.fetchBookings(
        ownerId: _canApprove ? null : widget.user.id,
        all: _canApprove,
      );
      if (!mounted) return;
      setState(() {
        _incomingBookings = list;
        _loadingBookings = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  Future<void> _cancelIncomingBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Batalkan Pengajuan?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Yakin ingin membatalkan pengajuan dari ${booking.tenantName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.cancelBooking(
        booking.id,
        userId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Pengajuan berhasil dibatalkan.'),
        ),
      );
      _loadIncomingBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal membatalkan pengajuan: $e'),
        ),
      );
    }
  }

  Future<void> _updateIncomingBookingStatus(
    Booking booking,
    String nextStatus,
  ) async {
    try {
      await ApiService.updateBookingStatus(booking.id, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Status pengajuan diubah menjadi $nextStatus.'),
        ),
      );
      _loadIncomingBookings();
      _loadProperties();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal memperbarui status: $e'),
        ),
      );
    }
  }

  Future<void> _quickAdjustAvailableRooms(Kost kost, int delta) async {
    final next = (kost.availableRooms + delta) < 0
        ? 0
        : kost.availableRooms + delta;
    if (next == kost.availableRooms) return;
    try {
      await ApiService.updateKost(kost.id, {'availableRooms': next});
      if (!mounted) return;
      setState(() {
        final idx = _kosts.indexWhere((k) => k.id == kost.id);
        if (idx >= 0) {
          _kosts[idx] = kost.copyWith(availableRooms: next);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal memperbarui sisa kamar: $e'),
        ),
      );
    }
  }

  Future<void> _addApplicantToGroup(Booking booking) async {
    final targetUserId = booking.userId;
    if (targetUserId == null || targetUserId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade700,
          content: const Text(
            'Pengajuan ini tidak terhubung ke akun terdaftar.',
          ),
        ),
      );
      return;
    }
    try {
      await ApiService.addGroupMember(
        kostId: booking.kostId,
        adminId: widget.user.id,
        targetUserId: targetUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text(
            '${booking.tenantName} berhasil ditambahkan ke grup penghuni!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menambahkan ke grup: $e'),
        ),
      );
    }
  }

  Future<void> _loadProperties() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.fetchKosts(
        search: _searchCtrl.text.trim(),
        ownerId: _canApprove ? null : widget.user.id,
        includePending: _canApprove,
      );
      if (!mounted) return;
      setState(() {
        _kosts = list;
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

  Future<void> _loadPendingProperties() async {
    if (!_canApprove) return;
    setState(() => _loadingPending = true);
    try {
      final results = await Future.wait<dynamic>([
        ApiService.fetchKosts(approvalStatus: 'PENDING'),
        ApiService.fetchReviewReports(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingKosts = results[0] as List<Kost>;
        _reviewReports = results[1] as List<ReviewReport>;
        _loadingPending = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _handleDismissReport(ReviewReport report) async {
    setState(() => _processingReportIds.add(report.id));
    try {
      await ApiService.dismissReviewReport(report.id);
      if (!mounted) return;
      setState(() {
        _processingReportIds.remove(report.id);
        _reviewReports.removeWhere((r) => r.id == report.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Laporan ulasan diabaikan.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingReportIds.remove(report.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Gagal mengabaikan laporan: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _handleDeleteReportedReview(ReviewReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Ulasan?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Ulasan oleh ${report.reviewAuthorName} akan dihapus permanen dan rating properti akan dihitung ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Ulasan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processingReportIds.add(report.id));
    try {
      await ApiService.deleteReview(report.reviewId);
      if (!mounted) return;
      setState(() {
        _processingReportIds.remove(report.id);
        _reviewReports.removeWhere((r) => r.reviewId == report.reviewId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Ulasan berhasil dihapus.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingReportIds.remove(report.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Gagal menghapus ulasan: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _handlePropertyApproval(Kost kost, String status) async {
    String? reason;
    if (status == 'REJECTED') {
      final reasonCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Tolak Properti',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Berikan alasan penolakan untuk "${kost.name}" (opsional):'),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Contoh: Foto properti kurang jelas / alamat belum lengkap',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tolak Properti'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        Future.delayed(const Duration(milliseconds: 400), reasonCtrl.dispose);
        return;
      }
      reason = reasonCtrl.text.trim();
      Future.delayed(const Duration(milliseconds: 400), reasonCtrl.dispose);
    }

    if (_processingApprovalIds.contains(kost.id)) return;
    setState(() => _processingApprovalIds.add(kost.id));
    try {
      await ApiService.approveOrRejectKost(
        kost.id,
        status: status,
        rejectionReason: reason,
        reviewerId: widget.user.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: status == 'APPROVED'
              ? AppColors.primaryGreen
              : Colors.red.shade600,
          content: Text(
            status == 'APPROVED'
                ? '${kost.name} berhasil disetujui dan tayang di beranda.'
                : '${kost.name} ditolak.',
          ),
        ),
      );
      _loadPendingProperties();
      _loadProperties();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal memproses persetujuan: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingApprovalIds.remove(kost.id));
      }
    }
  }

  Future<void> _deleteKost(Kost kost) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Properti?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${kost.name}"? Tindakan ini tidak dapat dibatalkan.',
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.deleteKost(kost.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('${kost.name} berhasil dihapus.'),
        ),
      );
      _loadProperties();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal menghapus properti: $e'),
        ),
      );
    }
  }

  Future<void> _openTransferOwnerDialog(Kost kost) async {
    List<UserProfile> users = [];
    bool loading = true;
    String? loadError;

    try {
      users = await ApiService.fetchUsers();
      loading = false;
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
      loading = false;
    }
    if (!mounted) return;
    if (loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal memuat daftar pengguna: $loadError'),
        ),
      );
      return;
    }

    final searchCtrl = TextEditingController();
    int? selectedOwnerId = kost.ownerId;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = users.where((u) {
            if (u.isBanned) return false;
            if (q.isEmpty) return true;
            return u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.roleLabel.toLowerCase().contains(q);
          }).toList();

          return AlertDialog(
            title: const Text(
              'Pindah Kepemilikan Properti',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Properti: ${kost.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Pemilik saat ini: ${kost.ownerName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau email pemilik baru...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, idx) {
                              final u = filtered[idx];
                              final selected = selectedOwnerId == u.id;
                              return RadioListTile<int>(
                                dense: true,
                                value: u.id,
                                groupValue: selectedOwnerId,
                                activeColor: AppColors.primaryGreen,
                                title: Text(
                                  u.name,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  '${u.email} • ${u.roleLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                onChanged: saving
                                    ? null
                                    : (v) => setDialogState(
                                          () => selectedOwnerId = v,
                                        ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: saving ||
                        selectedOwnerId == null ||
                        selectedOwnerId == kost.ownerId
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final updated = await ApiService.transferKostOwner(
                            kostId: kost.id,
                            targetOwnerId: selectedOwnerId!,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.primaryGreen,
                              content: Text(
                                'Kepemilikan "${updated.name}" dipindahkan ke ${updated.ownerName}.',
                              ),
                            ),
                          );
                          _loadProperties();
                          _loadPendingProperties();
                        } catch (e) {
                          setDialogState(() => saving = false);
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
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Pindahkan'),
              ),
            ],
          );
        },
      ),
    );
    Future.delayed(const Duration(milliseconds: 400), searchCtrl.dispose);
  }

  Future<void> _openBoostSheet(Kost kost) async {
    WalletPricing? pricing;
    try {
      pricing = await ApiService.fetchWalletPricing();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.discountRed,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
      return;
    }

    if (!mounted || pricing.boostPackages.isEmpty) return;

    var selectedCode = pricing.boostPackages.first.code;
    var submitting = false;
    final packages = pricing.boostPackages;
    final currentUser = AuthService.currentUserNotifier.value ?? widget.user;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final selectedPkg = packages.firstWhere(
              (p) => p.code == selectedCode,
              orElse: () => packages.first,
            );
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Boost Iklan Properti',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                kost.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Saldo Kredit Anda:',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatRupiah(currentUser.creditBalance),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...packages.map((pkg) {
                      final selected = pkg.code == selectedCode;
                      return GestureDetector(
                        onTap: submitting
                            ? null
                            : () => setSheetState(() => selectedCode = pkg.code),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFFFFBEB)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFD97706)
                                  : AppColors.cardBorder,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? const Color(0xFFD97706)
                                    : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unggulan ${pkg.label}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Tampil di posisi atas & badge Unggulan selama ${pkg.days} hari',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRupiah(pkg.price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: submitting
                            ? null
                            : () async {
                                setSheetState(() => submitting = true);
                                try {
                                  await ApiService.boostKost(
                                    kost.id,
                                    selectedPkg.code,
                                  );
                                  await AuthService.verifyActiveSession();
                                  if (sheetCtx.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                  }
                                  await _loadProperties();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.primaryGreen,
                                      content: Text(
                                        'Boost ${selectedPkg.label} aktif untuk ${kost.name}!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setSheetState(() => submitting = false);
                                  final msg = e
                                      .toString()
                                      .replaceFirst('Exception: ', '');
                                  final isShort = msg
                                      .toLowerCase()
                                      .contains('saldo kredit');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.discountRed,
                                      content: Text(msg),
                                      action: isShort
                                          ? SnackBarAction(
                                              label: 'Top-Up',
                                              textColor: Colors.white,
                                              onPressed: () {
                                                Navigator.of(sheetCtx).pop();
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        OwnerWalletScreen(
                                                      user: currentUser,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                }
                              },
                        child: submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Aktifkan Boost (${formatRupiah(selectedPkg.price)})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEditSheet(Kost kost) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: kost.name);
    final cityCtrl = TextEditingController(text: kost.city);
    final districtCtrl = TextEditingController(text: kost.district);
    final addressCtrl = TextEditingController(text: kost.address);
    final landmarkCtrl = TextEditingController(text: kost.nearbyLandmark);
    final priceCtrl = TextEditingController(
      text: kost.displayPrice.toString(),
    );
    final roomsCtrl = TextEditingController(text: kost.availableRooms.toString());
    final bedroomsCtrl = TextEditingController(text: kost.bedrooms.toString());
    final bathroomsCtrl = TextEditingController(text: kost.bathrooms.toString());
    final roomSizeCtrl = TextEditingController(text: kost.roomSize);
    final descCtrl = TextEditingController(text: kost.description);
    final ownerPhoneCtrl = TextEditingController(text: kost.ownerPhone);
    String selectedCategory = [
      'KOST',
      'APARTEMEN',
      'KONTRAKAN',
      'HUNIAN_HARIAN',
    ].contains(kost.propertyCategory)
        ? kost.propertyCategory
        : 'KOST';
    String selectedDailyUnitType =
        kost.unitType == 'Homestay' ? 'Homestay' : 'Villa';
    final initialFacilityPresets = ApiService.defaultFacilitiesFor(
      selectedCategory,
      unitType: selectedCategory == 'HUNIAN_HARIAN' ? selectedDailyUnitType : null,
    );
    List<String> masterRoomFacilities =
        List.from(initialFacilityPresets['room']!);
    List<String> masterPublicFacilities =
        List.from(initialFacilityPresets['public']!);
    final Set<String> selectedRoomFacilities = Set.from(kost.roomFacilities);
    final Set<String> selectedPublicFacilities =
        Set.from(kost.publicFacilities);
    bool loadedMasterFacilities = false;
    final rulesCtrl = TextEditingController(text: kost.rules.join(', '));
    String selectedType =
        ['Putri', 'Putra', 'Campur'].contains(kost.type) ? kost.type : 'Campur';
    bool electricityIncluded = kost.electricityIncluded;
    bool allowDirectBooking = kost.allowDirectBooking;
    LatLng? pickedLocation = kost.hasCoordinates
        ? LatLng(kost.latitude!, kost.longitude!)
        : null;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void reloadModalFacilities() {
            final fallback = ApiService.defaultFacilitiesFor(
              selectedCategory,
              unitType: selectedCategory == 'HUNIAN_HARIAN'
                  ? selectedDailyUnitType
                  : null,
            );
            setModalState(() {
              masterRoomFacilities = List.from(fallback['room']!);
              masterPublicFacilities = List.from(fallback['public']!);
            });
            ApiService.fetchMasterFacilities(
              category: selectedCategory,
              unitType: selectedCategory == 'HUNIAN_HARIAN'
                  ? selectedDailyUnitType
                  : null,
            ).then((data) {
              if (!mounted) return;
              setModalState(() {
                masterRoomFacilities = data['room'] ?? masterRoomFacilities;
                masterPublicFacilities =
                    data['public'] ?? masterPublicFacilities;
              });
            });
          }

          if (!loadedMasterFacilities) {
            loadedMasterFacilities = true;
            reloadModalFacilities();
          }
          return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Edit Properti',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Properti',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'KOST', child: Text('Kost')),
                      DropdownMenuItem(
                          value: 'APARTEMEN', child: Text('Apartemen')),
                      DropdownMenuItem(
                          value: 'KONTRAKAN', child: Text('Rumah Kontrakan')),
                      DropdownMenuItem(
                        value: 'HUNIAN_HARIAN',
                        child: Text('Hunian Harian (Villa / Homestay)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null && v != selectedCategory) {
                        setModalState(() => selectedCategory = v);
                        reloadModalFacilities();
                      }
                    },
                  ),
                  if (selectedCategory == 'HUNIAN_HARIAN') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedDailyUnitType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Hunian Harian',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Villa', child: Text('Villa')),
                        DropdownMenuItem(
                          value: 'Homestay',
                          child: Text('Homestay'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null && v != selectedDailyUnitType) {
                          setModalState(() => selectedDailyUnitType = v);
                          reloadModalFacilities();
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Properti',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (selectedCategory != 'HUNIAN_HARIAN' &&
                          selectedCategory != 'KONTRAKAN') ...[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipe',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Putri', child: Text('Putri')),
                              DropdownMenuItem(
                                  value: 'Putra', child: Text('Putra')),
                              DropdownMenuItem(
                                  value: 'Campur', child: Text('Campur')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setModalState(() => selectedType = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: LocationAutocompleteField(
                          controller: cityCtrl,
                          type: LocationAutocompleteType.city,
                          labelText: 'Kota / Kabupaten',
                          hintText: 'Misal: Kota Malang',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: LocationAutocompleteField(
                          controller: districtCtrl,
                          cityController: cityCtrl,
                          type: LocationAutocompleteType.district,
                          labelText: 'Kecamatan / Area',
                          hintText: 'Misal: Lowokwaru',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: selectedCategory == 'HUNIAN_HARIAN'
                                ? 'Harga / Malam (Rp)'
                                : selectedCategory == 'KONTRAKAN'
                                    ? 'Harga / Tahun (Rp)'
                                    : 'Harga / Bulan (Rp)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || int.tryParse(v.trim()) == null)
                                  ? 'Masukkan angka'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: roomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: selectedCategory == 'HUNIAN_HARIAN'
                                ? 'Unit Tersedia'
                                : 'Kamar Tersedia',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || int.tryParse(v.trim()) == null)
                                  ? 'Angka'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: roomSizeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ukuran',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Lengkap',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: landmarkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Patokan / Kampus Terdekat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickedLocation != null
                                ? 'Titik Peta: ${pickedLocation!.latitude.toStringAsFixed(5)}, ${pickedLocation!.longitude.toStringAsFixed(5)}'
                                : 'Belum ada titik peta',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final res = await Navigator.of(ctx).push<LatLng>(
                              MaterialPageRoute(
                                builder: (_) => KostLocationPickerScreen(
                                  initialLocation: pickedLocation,
                                ),
                              ),
                            );
                            if (res != null) {
                              if (!mounted || !ctx.mounted) return;
                              setModalState(() => pickedLocation = res);
                              try {
                                final geo =
                                    await LocationHelper.reverseGeocode(res);
                                if (!mounted || !ctx.mounted || geo == null) {
                                  return;
                                }
                                setModalState(() {
                                  if (geo.city.isNotEmpty) {
                                    cityCtrl.text = geo.city;
                                  }
                                  if (geo.district.isNotEmpty) {
                                    districtCtrl.text = geo.district;
                                  }
                                  if (geo.address.isNotEmpty) {
                                    addressCtrl.text = geo.address;
                                  }
                                });
                              } catch (_) {}
                            }
                          },
                          child: const Text('Pilih Peta'),
                        ),
                      ],
                    ),
                  ),
                  if (selectedCategory == 'HUNIAN_HARIAN' ||
                      selectedCategory == 'KONTRAKAN') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: bedroomsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kamar Tidur',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || int.tryParse(v.trim()) == null)
                                    ? 'Angka'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: bathroomsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Kamar Mandi',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || int.tryParse(v.trim()) == null)
                                    ? 'Angka'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  FacilityCheckboxGroup(
                    title: 'Fasilitas Kamar',
                    options: masterRoomFacilities,
                    selected: selectedRoomFacilities,
                    onToggle: (item) {
                      setModalState(() {
                        if (!selectedRoomFacilities.remove(item)) {
                          selectedRoomFacilities.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  FacilityCheckboxGroup(
                    title: 'Fasilitas Umum',
                    options: masterPublicFacilities,
                    selected: selectedPublicFacilities,
                    onToggle: (item) {
                      setModalState(() {
                        if (!selectedPublicFacilities.remove(item)) {
                          selectedPublicFacilities.add(item);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: rulesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Peraturan (pisahkan dengan koma)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Properti',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: ownerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'No. WA Pemilik / Pengelola',
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: validateIndonesianWhatsAppPhone,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Termasuk Listrik'),
                    activeColor: AppColors.primaryGreen,
                    value: electricityIncluded,
                    onChanged: (v) =>
                        setModalState(() => electricityIncluded = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan Booking Langsung (Escrow)'),
                    subtitle: Text(
                      widget.user.isVerifiedAccount
                          ? 'Penyewa dapat langsung membayar booking via Midtrans'
                          : 'Khusus pemilik terverifikasi. Verifikasi akun untuk mengaktifkan.',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    activeColor: AppColors.primaryGreen,
                    value: widget.user.isVerifiedAccount
                        ? allowDirectBooking
                        : false,
                    onChanged: widget.user.isVerifiedAccount
                        ? (v) => setModalState(() => allowDirectBooking = v)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => saving = true);
                              try {
                                List<String> splitCsv(String raw) => raw
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();

                                final parsedPrice =
                                    int.parse(priceCtrl.text.trim());
                                final isDaily =
                                    selectedCategory == 'HUNIAN_HARIAN';
                                final isKontrakan =
                                    selectedCategory == 'KONTRAKAN';
                                await ApiService.updateKost(kost.id, {
                                  'propertyCategory': selectedCategory,
                                  if (isDaily) 'unitType': selectedDailyUnitType,
                                  'name': nameCtrl.text.trim(),
                                  'type': (isDaily || isKontrakan)
                                      ? 'Campur'
                                      : selectedType,
                                  'city': cityCtrl.text.trim(),
                                  'district': districtCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'nearbyLandmark': landmarkCtrl.text.trim(),
                                  'pricePerMonth':
                                      (isDaily || isKontrakan) ? 0 : parsedPrice,
                                  if (isDaily) 'pricePerDay': parsedPrice,
                                  if (isKontrakan) 'pricePerYear': parsedPrice,
                                  'availableRooms':
                                      int.parse(roomsCtrl.text.trim()),
                                  if (isDaily ||
                                      selectedCategory == 'KONTRAKAN') ...{
                                    'bedrooms':
                                        int.tryParse(bedroomsCtrl.text.trim()) ??
                                            1,
                                    'bathrooms': int.tryParse(
                                            bathroomsCtrl.text.trim()) ??
                                        1,
                                  },
                                  'roomSize': roomSizeCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'ownerPhone': normalizeWhatsAppPhone(
                                    ownerPhoneCtrl.text.trim(),
                                  ),
                                  'roomFacilities':
                                      selectedRoomFacilities.toList(),
                                  'publicFacilities':
                                      selectedPublicFacilities.toList(),
                                  'rules': splitCsv(rulesCtrl.text),
                                  'electricityIncluded': electricityIncluded,
                                  if (widget.user.isVerifiedAccount)
                                    'allowDirectBooking': allowDirectBooking,
                                  if (pickedLocation != null) ...{
                                    'latitude': pickedLocation!.latitude,
                                    'longitude': pickedLocation!.longitude,
                                  },
                                });
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.primaryGreen,
                                    content: Text(
                                      'Data properti berhasil diperbarui!',
                                    ),
                                  ),
                                );
                                _loadProperties();
                              } catch (e) {
                                setModalState(() => saving = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade700,
                                    content: Text('Gagal memperbarui: $e'),
                                  ),
                                );
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        saving ? 'Menyimpan...' : 'Simpan Perubahan',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 400), () {
        nameCtrl.dispose();
        cityCtrl.dispose();
        districtCtrl.dispose();
        addressCtrl.dispose();
        landmarkCtrl.dispose();
        priceCtrl.dispose();
        roomsCtrl.dispose();
        bedroomsCtrl.dispose();
        bathroomsCtrl.dispose();
        roomSizeCtrl.dispose();
        descCtrl.dispose();
        rulesCtrl.dispose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableRooms =
        _kosts.fold<int>(0, (sum, k) => sum + k.availableRooms);
    final availableProperties =
        _kosts.where((k) => k.availableRooms > 0).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Kelola Properti',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_canApprove)
            TextButton.icon(
              onPressed: _openAdminPayoutRequestsSheet,
              icon: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              label: const Text(
                'Ajuan Withdraw',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: _canApprove,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Properti (${_kosts.length})'),
            Tab(text: 'Jadwal Survei (${_incomingBookings.length})'),
            if (_canApprove)
              Tab(
                text:
                    'Approval (${_pendingKosts.length + _reviewReports.length})',
              ),
          ],
        ),
      ),
      floatingActionButton: widget.user.canManageKost
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddPropertyWizardScreen(
                      currentUser: widget.user,
                    ),
                  ),
                );
                if (created == true && mounted) {
                  _loadProperties();
                  if (_canApprove) {
                    _loadPendingProperties();
                  }
                }
              },
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home_work_rounded),
              label: const Text(
                'Tambah Properti',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: Column(
        children: [
          // Dashboard Ringkasan Properti Strip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _buildMetricBox(
                  label: 'Total Properti',
                  value: '${_kosts.length}',
                  icon: Icons.apartment_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricBox(
                  label: 'Tersedia',
                  value: '$availableProperties',
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _buildMetricBox(
                  label: 'Kamar Kosong',
                  value: '$availableRooms',
                  icon: Icons.meeting_room_outlined,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF2F6)),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPropertiesTab(),
                _buildIncomingBookingsTab(),
                if (_canApprove) _buildApprovalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightGreenBg.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.darkGreen,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingBookingsTab() {
    if (_loadingBookings) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_incomingBookings.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada pengajuan sewa atau survei masuk.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadIncomingBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _incomingBookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final b = _incomingBookings[idx];
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SURVEI',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.kost?.name ?? 'Properti #${b.kostId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      b.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: b.status == 'DITOLAK'
                            ? AppColors.discountRed
                            : AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Penyewa: ${b.tenantName} (${b.tenantPhone})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  'Jadwal Survei: ${b.surveyDateTime.isNotEmpty ? b.surveyDateTime : b.startDate}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (b.status != 'DIBATALKAN' && b.status != 'DITOLAK')
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.discountRed,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _cancelIncomingBooking(b),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: const Text(
                            'Batalkan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (b.status != 'DIBATALKAN' &&
                        b.status != 'DITOLAK' &&
                        b.kost != null)
                      const SizedBox(width: 6),
                    if (b.kost != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: const BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => KostChatScreen(
                                  kost: b.kost!,
                                  peerUserId: b.userId,
                                  peerName: b.tenantName,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_rounded, size: 14),
                          label: const Text(
                            'Chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (b.userId != null &&
                        b.userId! > 0 &&
                        b.status != 'DIBATALKAN' &&
                        b.status != 'DITOLAK') ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _addApplicantToGroup(b),
                          icon: const Icon(Icons.group_add_rounded, size: 14),
                          label: const Text(
                            'Grup',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (b.status == 'TERKIRIM' ||
                    b.status == 'MENUNGGU KONFIRMASI') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () =>
                              _updateIncomingBookingStatus(b, 'DITOLAK'),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text(
                            'Tolak',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 36),
                          ),
                          onPressed: () =>
                              _updateIncomingBookingStatus(b, 'DISETUJUI'),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text(
                            'Setujui',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (b.status == 'DISETUJUI' || b.status == 'AKTIF') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () =>
                          _updateIncomingBookingStatus(b, 'SELESAI'),
                      icon: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text(
                        'Tandai Survei Selesai',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_canApprove && b.escrowStatus == 'DISPUTED') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.gavel_rounded,
                              size: 15,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sengketa Escrow (Admin/Staff)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (b.disputeReason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Alasan: ${b.disputeReason}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  minimumSize: const Size(0, 34),
                                  textStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () =>
                                    _resolveBookingDispute(b, 'REFUND'),
                                child: const Text('Refund Penyewa'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 34),
                                  textStyle: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onPressed: () =>
                                    _resolveBookingDispute(b, 'RELEASE'),
                                child: const Text('Cairkan ke Pemilik'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _resolveBookingDispute(Booking b, String resolution) async {
    final isRelease = resolution == 'RELEASE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isRelease ? 'Cairkan Dana ke Pemilik?' : 'Refund Dana ke Penyewa?',
        ),
        content: Text(
          isRelease
              ? 'Dana escrow booking ini akan dicairkan ke saldo pendapatan pemilik.'
              : 'Booking ini akan dibatalkan dan dana ditandai untuk refund ke penyewa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isRelease ? AppColors.primaryGreen : Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isRelease ? 'Ya, Cairkan' : 'Ya, Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.resolveBookingDispute(
        bookingId: b.id.toString(),
        resolution: resolution,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRelease
                ? 'Sengketa selesai: dana dicairkan ke pemilik.'
                : 'Sengketa selesai: booking di-refund ke penyewa.',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      _loadIncomingBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAdminPayoutRequestsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        List<Map<String, dynamic>> requests = [];
        bool loading = true;
        String? error;
        bool initialized = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> loadRequests() async {
              setSheetState(() {
                loading = true;
                error = null;
              });
              try {
                final data = await ApiService.fetchAllPayoutRequests();
                if (!sheetCtx.mounted) return;
                setSheetState(() {
                  requests = data;
                  loading = false;
                });
              } catch (e) {
                if (!sheetCtx.mounted) return;
                setSheetState(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                  loading = false;
                });
              }
            }

            if (!initialized) {
              initialized = true;
              Future.microtask(loadRequests);
            }

            Future<void> processReq(
              Map<String, dynamic> req,
              String action,
            ) async {
              final id = (req['id'] ?? '').toString();
              if (id.isEmpty) return;
              final noteCtrl = TextEditingController();
              final confirmed = await showDialog<bool>(
                context: sheetCtx,
                builder: (dCtx) => AlertDialog(
                  title: Text(
                    action == 'APPROVE'
                        ? 'Setujui Withdraw?'
                        : 'Tolak Withdraw?',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action == 'APPROVE'
                            ? 'Pastikan dana sudah ditransfer ke rekening pemilik.'
                            : 'Saldo pendapatan sewa pemilik akan dikembalikan.',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Admin (opsional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dCtx).pop(false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action == 'APPROVE'
                            ? AppColors.primaryGreen
                            : Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(dCtx).pop(true),
                      child: Text(action == 'APPROVE' ? 'Setujui' : 'Tolak'),
                    ),
                  ],
                ),
              );
              final noteText = noteCtrl.text.trim();
              noteCtrl.dispose();
              if (confirmed != true || !sheetCtx.mounted) return;

              try {
                await ApiService.processPayoutRequest(
                  requestId: id,
                  action: action,
                  adminNote: noteText,
                );
                if (!mounted || !sheetCtx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      action == 'APPROVE'
                          ? 'Pengajuan withdraw disetujui.'
                          : 'Pengajuan withdraw ditolak & saldo dikembalikan.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                loadRequests();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (_, scrollCtrl) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ajuan Withdraw Pemilik',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: loadRequests,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (loading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    else if (error != null)
                      Expanded(
                        child: Center(
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else if (requests.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Belum ada pengajuan withdraw.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          controller: scrollCtrl,
                          itemCount: requests.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final r = requests[idx];
                            final amount = (r['amount'] as num?)?.toInt() ?? 0;
                            final ownerName =
                                (r['ownerName'] ?? 'Pemilik').toString();
                            final ownerEmail =
                                (r['ownerEmail'] ?? '').toString();
                            final bankName = (r['bankName'] ?? '').toString();
                            final accNum =
                                (r['accountNumber'] ?? '').toString();
                            final accHolder =
                                (r['accountHolder'] ?? '').toString();
                            final status =
                                (r['status'] ?? 'PENDING')
                                    .toString()
                                    .toUpperCase();
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$ownerName ($ownerEmail)',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: status == 'APPROVED'
                                              ? AppColors.primaryGreen
                                              : status == 'REJECTED'
                                                  ? Colors.red.shade700
                                                  : Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatRupiah(amount),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$bankName • $accNum ($accHolder)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (status == 'PENDING') ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  Colors.red.shade700,
                                              side: BorderSide(
                                                color: Colors.red.shade300,
                                              ),
                                              minimumSize: const Size(0, 34),
                                            ),
                                            onPressed: () =>
                                                processReq(r, 'REJECT'),
                                            child: const Text('Tolak'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryGreen,
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size(0, 34),
                                            ),
                                            onPressed: () =>
                                                processReq(r, 'APPROVE'),
                                            child: const Text('Setujui'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPropertiesTab() {
    return Column(
      children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadProperties(),
                  decoration: InputDecoration(
                    hintText: 'Cari nama properti, area, atau kota...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryGreen,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadProperties();
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : IconButton(
                            onPressed: _loadProperties,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF3F6F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canApprove
                      ? 'Mode ${widget.user.roleLabel}: menampilkan ${_kosts.length} properti'
                      : 'Properti milik ${widget.user.name}: ${_kosts.length} properti',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Gagal memuat properti:\n$_error',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadProperties,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _kosts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.home_work_outlined,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Belum ada properti yang terdaftar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tambahkan kost, apartemen, atau kontrakan Anda untuk mulai mengelolanya di sini.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primaryGreen,
                            onRefresh: _loadProperties,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _kosts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final kost = _kosts[index];
                                final thumb = kost.images.isNotEmpty
                                    ? kost.images.first
                                    : '';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          thumb,
                                          width: 82,
                                          height: 82,
                                          fit: BoxFit.cover,
                                          cacheWidth: 200,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 82,
                                            height: 82,
                                            color: const Color(0xFFF1F5F9),
                                            child: const Icon(
                                              Icons.bed_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Text(
                                                    kost.categoryLabel,
                                                    style: const TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: getKostTypeBgColor(
                                                        kost.type),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: Text(
                                                    kost.type,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: getKostTypeColor(
                                                          kost.type),
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                _buildApprovalStatusBadge(kost),
                                              ],
                                            ),
                                            if (kost.isRejected &&
                                                kost.rejectionReason.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Alasan ditolak: ${kost.rejectionReason}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 5),
                                            Text(
                                              kost.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
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
                                            Row(
                                              children: [
                                                const Text(
                                                  'Kamar:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                InkWell(
                                                  onTap: kost.availableRooms > 0
                                                      ? () =>
                                                          _quickAdjustAvailableRooms(
                                                            kost,
                                                            -1,
                                                          )
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: kost.availableRooms >
                                                              0
                                                          ? const Color(
                                                              0xFFF3F6F9)
                                                          : Colors
                                                              .grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Icon(
                                                      Icons.remove_rounded,
                                                      size: 14,
                                                      color: kost.availableRooms >
                                                              0
                                                          ? AppColors
                                                              .textPrimary
                                                          : Colors
                                                              .grey.shade400,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 6),
                                                  child: Text(
                                                    kost.availableRooms > 0
                                                        ? 'Sisa ${kost.availableRooms}'
                                                        : 'Penuh',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: kost.availableRooms > 0
                                                          ? Colors.grey.shade800
                                                          : Colors.red.shade700,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () =>
                                                      _quickAdjustAvailableRooms(
                                                    kost,
                                                    1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFF3F6F9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: const Icon(
                                                      Icons.add_rounded,
                                                      size: 14,
                                                      color: AppColors
                                                          .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${formatRupiah(kost.displayPrice)}${kost.displayPriceShortUnit}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w800,
                                                      color:
                                                          AppColors.primaryGreen,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Grup Penghuni',
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            KostGroupChatScreen(
                                                          kostId: kost.id,
                                                          kostName: kost.name,
                                                          kostImage:
                                                              kost.images.isNotEmpty
                                                                  ? kost.images
                                                                      .first
                                                                  : '',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.groups_rounded,
                                                    size: 20,
                                                    color:
                                                        AppColors.primaryGreen,
                                                  ),
                                                ),
                                                if (widget.user.canApproveProperties)
                                                  IconButton(
                                                    tooltip:
                                                        'Pindah Kepemilikan',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () =>
                                                        _openTransferOwnerDialog(
                                                            kost),
                                                    icon: const Icon(
                                                      Icons.swap_horiz_rounded,
                                                      size: 20,
                                                      color: Color(0xFF0369A1),
                                                    ),
                                                  ),
                                                if (widget.user.isAdministrator ||
                                                    kost.ownerId ==
                                                        widget.user.id) ...[
                                                  IconButton(
                                                    tooltip: kost.isBoosted
                                                        ? 'Perpanjang Boost Iklan'
                                                        : 'Boost Iklan',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () =>
                                                        _openBoostSheet(kost),
                                                    icon: Icon(
                                                      Icons.bolt_rounded,
                                                      size: 21,
                                                      color: kost.isBoosted
                                                          ? const Color(0xFFD97706)
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Edit Properti',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () =>
                                                        _openEditSheet(kost),
                                                    icon: const Icon(
                                                      Icons.edit_rounded,
                                                      size: 19,
                                                      color:
                                                          AppColors.primaryGreen,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Hapus Properti',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    onPressed: () =>
                                                        _deleteKost(kost),
                                                    icon: Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 19,
                                                      color:
                                                          Colors.red.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
    );
  }

  Widget _buildApprovalStatusBadge(Kost kost) {
    final Color bg;
    final Color fg;
    final String label;
    if (kost.isPendingApproval) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'Menunggu';
    } else if (kost.isRejected) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      label = 'Ditolak';
    } else {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
      label = 'Disetujui';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildApprovalTab() {
    if (_loadingPending) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_pendingKosts.isEmpty && _reviewReports.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadPendingProperties,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Tidak ada properti yang menunggu persetujuan atau laporan ulasan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    final items = <Widget>[];
    if (_reviewReports.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Laporan Ulasan (${_reviewReports.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
      for (final report in _reviewReports) {
        final isProcessingReport = _processingReportIds.contains(report.id);
        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.kostName.isNotEmpty
                            ? report.kostName
                            : 'Properti #${report.kostId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report.reason,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dilaporkan oleh: ${report.reporterName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (report.details != null &&
                    report.details!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan pelapor: ${report.details!.trim()}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ulasan oleh: ${report.reviewAuthorName}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            report.reviewOverallRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.reviewComment,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessingReport
                            ? null
                            : () => _handleDismissReport(report),
                        child: const Text('Abaikan'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isProcessingReport
                            ? null
                            : () => _handleDeleteReportedReview(report),
                        child: isProcessingReport
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Hapus Ulasan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }
    if (_pendingKosts.isNotEmpty) {
      items.add(
        Padding(
          padding: EdgeInsets.only(
            top: _reviewReports.isNotEmpty ? 6 : 0,
            bottom: 10,
          ),
          child: Text(
            'Properti Menunggu Persetujuan (${_pendingKosts.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadPendingProperties,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + _pendingKosts.length,
        itemBuilder: (context, index) {
          if (index < items.length) {
            return items[index];
          }
          final kost = _pendingKosts[index - items.length];
          final isProcessing = _processingApprovalIds.contains(kost.id);
          final thumb = kost.images.isNotEmpty ? kost.images.first : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KostDetailScreen(
                    kost: kost,
                    isFavorite: kost.isFavorite,
                    onToggleFavorite: () {},
                    onBookingCreated: () {},
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MENUNGGU PERSETUJUAN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kost.categoryLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KostDetailScreen(
                                kost: kost,
                                isFavorite: kost.isFavorite,
                                onToggleFavorite: () {},
                                onBookingCreated: () {},
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                        label: const Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: thumb.isNotEmpty
                            ? Image.network(
                                thumb,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: const Color(0xFFF3F6F9),
                                  child: const Icon(
                                    Icons.apartment_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                color: const Color(0xFFF3F6F9),
                                child: const Icon(
                                  Icons.apartment_rounded,
                                  color: AppColors.textSecondary,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
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
                            const SizedBox(height: 3),
                            Text(
                              '${formatRupiah(kost.displayPrice)}${kost.displayPriceShortUnit} • ${kost.availableRooms > 0 ? 'Sisa ${kost.availableRooms} kamar' : 'Penuh'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Pemilik: ${kost.ownerName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.discountRed,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _handlePropertyApproval(kost, 'REJECTED'),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isProcessing
                              ? null
                              : () =>
                                  _handlePropertyApproval(kost, 'APPROVED'),
                          child: isProcessing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Memproses...'),
                                  ],
                                )
                              : const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}
