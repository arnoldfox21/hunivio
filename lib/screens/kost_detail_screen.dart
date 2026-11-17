import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking.dart';
import '../models/kost.dart';
import '../models/review.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';
import '../widgets/booking_sheet.dart';
import '../widgets/direct_booking_sheet.dart';
import 'kost_chat_screen.dart';
import 'owner_profile_screen.dart';

class KostDetailScreen extends StatefulWidget {
  final Kost kost;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onBookingCreated;

  const KostDetailScreen({
    super.key,
    required this.kost,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onBookingCreated,
  });

  @override
  State<KostDetailScreen> createState() => _KostDetailScreenState();
}

class _KostDetailScreenState extends State<KostDetailScreen> {
  late Kost _kost;
  UserProfile? _ownerProfile;
  int _currentImageIndex = 0;
  late bool _isFav;
  List<Review> _reviews = [];
  bool _loadingReviews = true;
  Booking? _ongoingBooking;

  @override
  void initState() {
    super.initState();
    _kost = widget.kost;
    _isFav = widget.isFavorite;
    _loadReviews();
    _loadOwnerProfile();
    _checkOngoingBooking();
  }

  Future<void> _loadOwnerProfile() async {
    if (_kost.ownerId <= 0) return;
    try {
      final profile = await ApiService.fetchUserById(_kost.ownerId);
      if (!mounted) return;
      setState(() => _ownerProfile = profile);
    } catch (_) {}
  }

  Future<void> _checkOngoingBooking() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final list = await ApiService.fetchBookings(userId: user.id);
      if (!mounted) return;
      Booking? match;
      for (final b in list) {
        if (b.kostId == _kost.id &&
            const [
              'TERKIRIM',
              'MENUNGGU KONFIRMASI',
              'DISETUJUI',
              'APPROVED',
              'AKTIF',
            ].contains(b.status.toUpperCase())) {
          match = b;
          break;
        }
      }
      setState(() => _ongoingBooking = match);
    } catch (_) {}
  }

  Future<void> _loadReviews() async {
    try {
      final list = await ApiService.fetchReviews(_kost.id);
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  void _openWriteReviewDialog() {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk menulis ulasan.'),
        ),
      );
      return;
    }
    final commentCtrl = TextEditingController();
    double clean = 5;
    double security = 5;
    double accuracy = 5;
    bool submitting = false;
    String? validationError;
    final selectedTags = <String>{};
    const quickTags = [
      'Bersih & Rapi',
      'Pemilik Ramah',
      'Lokasi Strategis',
      'Wi-Fi Kencang',
      'Tenang & Nyaman',
      'Sesuai Foto',
    ];

    String ratingLabel(double avg) {
      if (avg >= 4.6) return 'Luar Biasa';
      if (avg >= 4.0) return 'Sangat Bagus';
      if (avg >= 3.2) return 'Cukup Baik';
      return 'Perlu Perbaikan';
    }

    Widget buildStarRow(
      String label,
      IconData icon,
      double current,
      ValueChanged<double> onChanged,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (idx) {
                final star = idx + 1;
                final filled = star <= current.round();
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(star.toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 26,
                      color: filled
                          ? const Color(0xFFF59E0B)
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final avg = (clean + security + accuracy) / 3.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
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
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tulis Ulasan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 13, color: AppColors.primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'Penghuni',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _kost.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ratingLabel(avg),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Rata-rata penilaian Anda dari 3 aspek',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildStarRow(
                    'Kebersihan',
                    Icons.cleaning_services_outlined,
                    clean,
                    (v) => setSheetState(() => clean = v),
                  ),
                  buildStarRow(
                    'Keamanan',
                    Icons.shield_outlined,
                    security,
                    (v) => setSheetState(() => security = v),
                  ),
                  buildStarRow(
                    'Kesesuaian Foto',
                    Icons.photo_camera_outlined,
                    accuracy,
                    (v) => setSheetState(() => accuracy = v),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Kesan Singkat (Opsional)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickTags.map((tag) {
                      final active = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.darkGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                        selected: active,
                        selectedColor: AppColors.lightGreenBg,
                        checkmarkColor: AppColors.primaryGreen,
                        side: BorderSide(
                          color: active
                              ? AppColors.primaryGreen
                              : AppColors.cardBorder,
                        ),
                        onSelected: (sel) {
                          setSheetState(() {
                            if (sel) {
                              selectedTags.add(tag);
                              if (!commentCtrl.text.contains(tag)) {
                                final current = commentCtrl.text.trim();
                                commentCtrl.text =
                                    current.isEmpty ? tag : '$current, $tag';
                              }
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 4,
                    maxLength: 300,
                    onChanged: (_) {
                      if (validationError != null) {
                        setSheetState(() => validationError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Ceritakan pengalaman tinggal Anda',
                      hintText:
                        _kost.isDailyStay
                            ? 'Bagaimana kenyamanan unit, kebersihan, dan pelayanan pemilik?'
                            : 'Bagaimana kondisi kamar, lingkungan, dan keramahan pemilik?',
                      alignLabelWithHint: true,
                      errorText: validationError,
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (commentCtrl.text.trim().isEmpty) {
                                setSheetState(() {
                                  validationError =
                                      'Mohon tuliskan ulasan singkat Anda terlebih dahulu.';
                                });
                                return;
                              }
                              setSheetState(() => submitting = true);
                              try {
                                await ApiService.createReview(
                                  kostId: _kost.id,
                                  userId: user.id,
                                  userName: user.name,
                                  userAvatar: user.avatarUrl,
                                  ratingCleanliness: clean,
                                  ratingSecurity: security,
                                  ratingAccuracy: accuracy,
                                  comment: commentCtrl.text.trim(),
                                );
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                _loadReviews();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.primaryGreen,
                                    content: Text(
                                      'Terima kasih! Ulasan Anda berhasil dipublikasikan.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() => submitting = false);
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade700,
                                    content: Text(e
                                        .toString()
                                        .replaceFirst('Exception: ', '')),
                                  ),
                                );
                              }
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        submitting ? 'Mengirim Ulasan...' : 'Kirim Ulasan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(
      () => Future.delayed(const Duration(milliseconds: 400), commentCtrl.dispose),
    );
  }

  bool get _isOwner =>
      AuthService.currentUser != null &&
      AuthService.currentUser!.id == _kost.ownerId;

  Future<void> _shareKost() async {
    final kost = _kost;
    final text = buildKostShareText(
      kostName: kost.name,
      propertyCategory: kost.propertyCategory,
      kostType: kost.type,
      pricePerMonth: kost.displayPrice,
      address: kost.address,
      district: kost.district,
      city: kost.city,
      rating: kost.rating,
      latitude: kost.latitude,
      longitude: kost.longitude,
    );
    try {
      await shareTextContent(text: text, subject: kost.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal membagikan properti: $e'),
        ),
      );
    }
  }

  Future<void> _openReplyReviewDialog(Review review) async {
    final replyCtrl = TextEditingController(text: review.ownerReply ?? '');
    bool submitting = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            (review.ownerReply != null && review.ownerReply!.trim().isNotEmpty)
                ? 'Edit Balasan Ulasan'
                : 'Balas Ulasan Penghuni',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: TextField(
            controller: replyCtrl,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Tulis tanggapan Anda untuk ulasan ini...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final text = replyCtrl.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => submitting = true);
                      try {
                        final updated = await ApiService.replyToReview(
                          reviewId: review.id,
                          reply: text,
                        );
                        if (!mounted) return;
                        setState(() {
                          final idx = _reviews.indexWhere(
                            (r) => r.id == updated.id,
                          );
                          if (idx >= 0) {
                            _reviews[idx] = updated;
                          }
                        });
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.primaryGreen,
                            content: Text('Balasan ulasan berhasil disimpan.'),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.shade700,
                            content: Text('Gagal membalas ulasan: $e'),
                          ),
                        );
                      }
                    },
              child: Text(submitting ? 'Menyimpan...' : 'Kirim Balasan'),
            ),
          ],
        ),
      ),
    );
    replyCtrl.dispose();
  }

  Future<void> _openReportReviewDialog(Review rev) async {
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk melaporkan ulasan.'),
        ),
      );
      return;
    }

    const reasons = [
      'Spam / Iklan',
      'Ujaran Kebencian / Kasar',
      'Informasi Palsu',
      'Tidak Relevan',
      'Lainnya',
    ];
    String selectedReason = reasons.first;
    final detailsCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Laporkan Ulasan',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih alasan pelaporan untuk ulasan oleh ${rev.userName}:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: reasons.map((r) {
                    final selected = selectedReason == r;
                    return ChoiceChip(
                      label: Text(r, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      selectedColor: AppColors.lightGreenBg,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.darkGreen
                            : AppColors.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (val) {
                        if (val) setDialogState(() => selectedReason = r);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Keterangan tambahan (opsional)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        await ApiService.reportReview(
                          reviewId: rev.id,
                          reason: selectedReason,
                          details: detailsCtrl.text,
                        );
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.primaryGreen,
                            content: Text(
                              'Laporan ulasan berhasil dikirim. Tim kami akan meninjau.',
                            ),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => submitting = false);
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
              child: Text(submitting ? 'Mengirim...' : 'Kirim Laporan'),
            ),
          ],
        ),
      ),
    );
    detailsCtrl.dispose();
  }

  Future<void> _openInGoogleMaps() async {
    final kost = _kost;
    if (!kost.hasCoordinates) return;
    try {
      await openGoogleMapsLocation(
        latitude: kost.latitude!,
        longitude: kost.longitude!,
        label: kost.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Tidak dapat membuka Google Maps: $e'),
        ),
      );
    }
  }

  Future<void> _openWhatsAppOwner() async {
    final kost = _kost;
    final msg = buildKostWhatsAppTemplate(
      ownerName: kost.ownerName,
      kostName: kost.name,
      propertyCategory: kost.propertyCategory,
      kostType: kost.type,
      address: kost.address,
      district: kost.district,
      city: kost.city,
      pricePerMonth: kost.displayPrice,
    );
    try {
      await openWhatsAppChat(
        phone: kost.ownerPhone,
        message: msg,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Tidak dapat membuka WhatsApp: $e'),
        ),
      );
    }
  }

  void _openChatScreen() {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk bertanya ke pemilik.'),
        ),
      );
      return;
    }
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat mengirim pesan ke properti milik sendiri.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KostChatScreen(kost: _kost),
      ),
    );
  }

  void _openBookingSheet() {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk mengajukan survei.'),
        ),
      );
      return;
    }
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat mengajukan survei pada properti milik sendiri.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BookingSheet(
        kost: _kost,
        onSuccess: () {
          widget.onBookingCreated();
          _checkOngoingBooking();
        },
      ),
    );
  }

  void _openDirectBookingSheet() {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk melakukan booking.'),
        ),
      );
      return;
    }
    if (_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak dapat mem-booking properti milik sendiri.'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DirectBookingSheet(
        kost: _kost,
        onCompleted: () {
          widget.onBookingCreated();
          _checkOngoingBooking();
        },
      ),
    );
  }

  Future<void> _openEditDescriptionDialog() async {
    final ctrl = TextEditingController(text: _kost.description);
    bool saving = false;
    String? errorMsg;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Cerita / Tentang ${_kost.categoryLabel}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ceritakan keunggulan, suasana lingkungan, akses sekitar, dan hal menarik untuk calon penyewa.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Tulis cerita tentang ${_kost.categoryLabel.toLowerCase()} Anda...',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final text = ctrl.text.trim();
                          if (text.isEmpty) {
                            setModalState(() {
                              errorMsg = 'Deskripsi tidak boleh kosong.';
                            });
                            return;
                          }
                          setModalState(() {
                            saving = true;
                            errorMsg = null;
                          });
                          try {
                            final updated = await ApiService.updateKost(
                              _kost.id,
                              {'description': text},
                            );
                            if (!mounted) return;
                            setState(() => _kost = updated);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deskripsi properti berhasil diperbarui.'),
                              ),
                            );
                          } catch (e) {
                            setModalState(() {
                              saving = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Deskripsi',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kost = _kost;
    final images = kost.images;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with Image Carousel
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Bagikan Properti',
                onPressed: _shareKost,
                icon: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.35),
                  child: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _isFav = !_isFav);
                  widget.onToggleFavorite();
                },
                icon: CircleAvatar(
                  backgroundColor: Colors.black.withOpacity(0.35),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _isFav ? Icons.favorite_rounded : Icons.favorite_border,
                      key: ValueKey<bool>(_isFav),
                      color: _isFav ? Colors.red.shade600 : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isEmpty
                  ? Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.bed, size: 64),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (idx) =>
                              setState(() => _currentImageIndex = idx),
                          itemBuilder: (context, idx) {
                            final img = Image.network(
                              images[idx],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.bed, size: 64),
                              ),
                            );
                            if (idx == 0) {
                              return Hero(
                                tag: 'kost_img_${kost.id}',
                                child: img,
                              );
                            }
                            return img;
                          },
                        ),
                        Positioned(
                          bottom: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1} / ${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kost.isDailyStay
                              ? const Color(0xFFE0F2FE)
                              : getKostTypeBgColor(kost.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kost.isDailyStay
                              ? '${kost.categoryLabel} • Harian'
                              : '${kost.categoryLabel} • ${kost.type}',
                          style: TextStyle(
                            color: kost.isDailyStay
                                ? const Color(0xFF0369A1)
                                : getKostTypeColor(kost.type),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (kost.isBoosted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 15,
                                color: Color(0xFFD97706),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Unggulan',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (kost.rating >= 4.5 && kost.reviewCount >= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: AppColors.primaryGreen,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Top Rated',
                                style: TextStyle(
                                  color: AppColors.darkGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kost.availableRooms > 0
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kost.availableRooms > 0
                              ? (kost.isDailyStay ||
                                      kost.propertyCategory != 'KOST'
                                  ? 'Tersedia ${kost.availableRooms} unit'
                                  : 'Sisa ${kost.availableRooms} kamar')
                              : (kost.isDailyStay ||
                                      kost.propertyCategory != 'KOST'
                                  ? 'Unit Penuh'
                                  : 'Kamar Penuh'),
                          style: TextStyle(
                            color: kost.availableRooms > 0
                                ? Colors.orange.shade900
                                : Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Kost Title
                  Text(
                    kost.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location & Rating
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${kost.district}, ${kost.city}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB300),
                        size: 19,
                      ),
                      const SizedBox(width: 3),
                      Builder(
                        builder: (context) {
                          final displayCount = _loadingReviews
                              ? kost.reviewCount
                              : _reviews.length;
                          final displayRating = _loadingReviews
                              ? kost.rating
                              : (_reviews.isEmpty
                                  ? 0.0
                                  : _reviews.fold<double>(
                                        0.0,
                                        (sum, r) => sum + r.overallRating,
                                      ) /
                                      _reviews.length);
                          return Text(
                            displayCount > 0
                                ? '${displayRating.toStringAsFixed(1)} ($displayCount ulasan)'
                                : 'Belum ada ulasan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kost.address,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (kost.nearbyLandmark.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          kost.isDailyStay
                              ? Icons.place_outlined
                              : Icons.school_outlined,
                          size: 15,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            kost.nearbyLandmark,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (kost.hasCoordinates) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showMapPreviewDialog(context),
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 17,
                            color: AppColors.primaryGreen,
                          ),
                          label: const Text(
                            'Lihat Lokasi di Peta',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: AppColors.primaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openInGoogleMaps,
                          icon: const Icon(
                            Icons.directions_outlined,
                            size: 17,
                            color: Color(0xFF1A73E8),
                          ),
                          label: const Text(
                            'Google Maps',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A73E8),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1A73E8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),

                  // Spesifikasi Properti
                  Text(
                    kost.isDailyStay
                        ? 'Spesifikasi ${kost.categoryLabel}'
                        : 'Spesifikasi Tipe Kamar',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SpecTile(
                        icon: Icons.straighten_rounded,
                        label: kost.isDailyStay ||
                                kost.propertyCategory != 'KOST'
                            ? 'Luas Bangunan'
                            : 'Luas Kamar',
                        value: kost.roomSize.trim().isNotEmpty
                            ? kost.roomSize
                            : '-',
                      ),
                      const SizedBox(width: 12),
                      if (kost.isDailyStay ||
                          kost.propertyCategory == 'KONTRAKAN')
                        _SpecTile(
                          icon: Icons.bed_rounded,
                          label: 'Kapasitas',
                          value:
                              '${kost.bedrooms} Kamar Tidur • ${kost.bathrooms} KM',
                        )
                      else if (kost.propertyCategory == 'APARTEMEN')
                        _SpecTile(
                          icon: Icons.apartment_rounded,
                          label: 'Tipe & Kondisi',
                          value: [
                            if (kost.unitType.trim().isNotEmpty) kost.unitType,
                            if (kost.furnishing.trim().isNotEmpty)
                              kost.furnishing,
                          ].isNotEmpty
                              ? [
                                  if (kost.unitType.trim().isNotEmpty)
                                    kost.unitType,
                                  if (kost.furnishing.trim().isNotEmpty)
                                    kost.furnishing,
                                ].join(' • ')
                              : '${kost.bedrooms} KT • ${kost.bathrooms} KM',
                        )
                      else
                        _SpecTile(
                          icon: Icons.bolt_rounded,
                          label: 'Listrik',
                          value: kost.electricityIncluded
                              ? 'Termasuk Listrik'
                              : 'Tidak Termasuk',
                        ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),

                  // Fasilitas Dalam / Kamar
                  Text(
                    kost.isDailyStay
                        ? 'Fasilitas Dalam ${kost.categoryLabel}'
                        : 'Fasilitas Kamar & Kamar Mandi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (kost.roomFacilities.isEmpty)
                    Text(
                      'Pemilik belum mencantumkan fasilitas dalam.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: kost.roomFacilities
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  getFacilityIcon(f),
                                  size: 17,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  f,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),

                  // Fasilitas Bersama
                  const Text(
                    'Fasilitas Umum / Bersama',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (kost.publicFacilities.isEmpty)
                    Text(
                      'Pemilik belum mencantumkan fasilitas umum.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: kost.publicFacilities
                        .map(
                          (f) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  getFacilityIcon(f),
                                  size: 17,
                                  color: Colors.blueGrey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  f,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),

                  // Peraturan Properti
                  Text(
                    kost.isDailyStay
                        ? 'Peraturan Menginap'
                        : (kost.propertyCategory == 'KOST'
                            ? 'Peraturan Selama Kos'
                            : 'Peraturan ${kost.categoryLabel}'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (kost.rules.isEmpty)
                    Text(
                      'Tidak ada peraturan khusus yang dicantumkan pemilik.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    ...kost.rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),

                  // Cerita Pemilik / Deskripsi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Tentang ${kost.categoryLabel} Ini',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_isOwner)
                        TextButton.icon(
                          onPressed: _openEditDescriptionDialog,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kost.description.trim().isNotEmpty
                        ? kost.description
                        : 'Pemilik belum menuliskan cerita atau deskripsi untuk properti ini.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: kost.description.trim().isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: kost.description.trim().isEmpty
                          ? Colors.grey.shade600
                          : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Owner Card
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OwnerProfileScreen(
                            ownerId: kost.ownerId,
                            initialOwnerName: _ownerProfile?.name ?? kost.ownerName,
                            sourceKost: kost,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.lightGreenBg,
                            backgroundImage:
                                (_ownerProfile?.avatarUrl.trim().isNotEmpty ??
                                        false)
                                    ? NetworkImage(_ownerProfile!.avatarUrl)
                                    : null,
                            child: (_ownerProfile?.avatarUrl.trim().isEmpty ??
                                    true)
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primaryGreen,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dikelola oleh ${(_ownerProfile?.name.trim().isNotEmpty ?? false) ? _ownerProfile!.name : kost.ownerName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  (_ownerProfile?.bio.trim().isNotEmpty ?? false)
                                      ? _ownerProfile!.bio.trim()
                                      : ((_ownerProfile?.isVerifiedAccount ?? kost.isVerified)
                                          ? 'Pemilik Terverifikasi • Lihat profil & postingan'
                                          : 'Pemilik Properti • Lihat profil & postingan'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (kost.showOwnerWhatsapp &&
                      kost.ownerPhone.trim().isNotEmpty &&
                      !_isOwner) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openWhatsAppOwner,
                        icon: const Icon(Icons.chat_rounded, size: 19),
                        label: const Text(
                          'Chat Pemilik via WhatsApp',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Verified Reviews Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kost.isDailyStay ? 'Ulasan Tamu' : 'Ulasan Penghuni',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _openWriteReviewDialog,
                        icon: const Icon(Icons.rate_review_outlined, size: 17),
                        label: const Text('Tulis Ulasan'),
                      ),
                    ],
                  ),
                  if (_loadingReviews)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  else if (_reviews.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'Belum ada ulasan tertulis. Jadilah yang pertama memberikan ulasan!',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  else
                    ..._reviews.map(
                      (rev) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
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
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: AppColors.lightGreenBg,
                                  child: Text(
                                    rev.userName.isNotEmpty
                                        ? rev.userName[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rev.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  rev.overallRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rev.comment,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (rev.ownerReply != null &&
                                rev.ownerReply!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGreenBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primaryGreen
                                        .withOpacity(0.25),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.reply_rounded,
                                          size: 14,
                                          color: AppColors.darkGreen,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Balasan Pemilik',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.darkGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rev.ownerReply!,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_isOwner ||
                                (AuthService.currentUser?.canApproveProperties ??
                                    false) ||
                                AuthService.currentUser?.id != rev.userId) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (AuthService.currentUser?.id != rev.userId)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () =>
                                          _openReportReviewDialog(rev),
                                      icon: Icon(
                                        Icons.flag_outlined,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      label: Text(
                                        'Laporkan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  if (_isOwner ||
                                      (AuthService.currentUser
                                              ?.canApproveProperties ??
                                          false)) ...[
                                    const SizedBox(width: 6),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () =>
                                          _openReplyReviewDialog(rev),
                                      icon: const Icon(
                                        Icons.reply_rounded,
                                        size: 15,
                                        color: AppColors.primaryGreen,
                                      ),
                                      label: Text(
                                        (rev.ownerReply != null &&
                                                rev.ownerReply!
                                                    .trim()
                                                    .isNotEmpty)
                                            ? 'Edit Balasan'
                                            : 'Balas Ulasan',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Sticky Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kost.originalPrice != null &&
                        kost.originalPrice! > kost.pricePerMonth)
                      Text(
                        formatRupiah(kost.originalPrice!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      formatRupiah(kost.displayPrice),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Text(
                      kost.displayPriceFullUnit,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 17,
                        color: AppColors.darkGreen,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Properti Milik Anda',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _openChatScreen,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text(
                    'Tanya',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                      if (_ongoingBooking == null &&
                          _kost.allowDirectBooking &&
                          _kost.availableRooms > 0) ...[
                        Expanded(
                          flex: 4,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openBookingSheet,
                            child: const Text(
                              'Survei',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openDirectBookingSheet,
                            child: const Text(
                              'Booking Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ] else if (_ongoingBooking == null &&
                          _kost.allowDirectBooking &&
                          _kost.availableRooms <= 0)
                        Expanded(
                          flex: 4,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: null,
                            child: const Text(
                              'Kamar Penuh',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          flex: 4,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ongoingBooking != null
                                  ? Colors.grey.shade400
                                  : AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _ongoingBooking != null
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Anda sudah memiliki pengajuan untuk properti ini (${_ongoingBooking!.status}).',
                                        ),
                                      ),
                                    );
                                  }
                                : _openBookingSheet,
                            child: Text(
                              _ongoingBooking != null
                                  ? 'Sudah Diajukan'
                                  : 'Ajukan Survei',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMapPreviewDialog(BuildContext context) {
    final kost = _kost;
    if (!kost.hasCoordinates) return;
    final point = LatLng(kost.latitude!, kost.longitude!);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 380,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        kost.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15.5,
                    minZoom: 5,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapboxConfig.tileUrlTemplate,
                      tileSize: 512,
                      zoomOffset: -1,
                      panBuffer: 0,
                      keepBuffer: 1,
                      tileProvider: CachedMapboxTileProvider.instance,
                      userAgentPackageName: 'com.keyloka.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_pin,
                            color: AppColors.primaryGreen,
                            size: 42,
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
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpecTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
}
