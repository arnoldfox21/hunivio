import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/booking.dart';
import '../models/kost.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';
import '../widgets/facility_checkbox_group.dart';
import '../widgets/location_autocomplete_field.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';
import 'kost_group_chat_screen.dart';
import 'kost_location_picker_screen.dart';

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
  List<Booking> _incomingBookings = [];
  bool _loading = true;
  bool _loadingPending = false;
  bool _loadingBookings = true;
  final Set<int> _processingApprovalIds = {};
  String? _error;

  bool get _canApprove => widget.user.canApproveProperties;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _canApprove ? 3 : 2, vsync: this);
    _loadProperties();
    _loadIncomingBookings();
    if (_canApprove) {
      _loadPendingProperties();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIncomingBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final list = await ApiService.fetchBookings(
        ownerId: widget.user.isAdministrator ? null : widget.user.id,
        all: widget.user.isAdministrator,
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
      final list = await ApiService.fetchKosts(approvalStatus: 'PENDING');
      if (!mounted) return;
      setState(() {
        _pendingKosts = list;
        _loadingPending = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPending = false);
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
      if (confirmed != true) return;
      reason = reasonCtrl.text.trim();
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

  void _openEditSheet(Kost kost) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: kost.name);
    final cityCtrl = TextEditingController(text: kost.city);
    final districtCtrl = TextEditingController(text: kost.district);
    final addressCtrl = TextEditingController(text: kost.address);
    final landmarkCtrl = TextEditingController(text: kost.nearbyLandmark);
    final priceCtrl = TextEditingController(text: kost.pricePerMonth.toString());
    final roomsCtrl = TextEditingController(text: kost.availableRooms.toString());
    final totalRoomsCtrl = TextEditingController(text: kost.totalRooms.toString());
    final roomSizeCtrl = TextEditingController(text: kost.roomSize);
    final descCtrl = TextEditingController(text: kost.description);
    List<String> masterRoomFacilities =
        List.from(ApiService.defaultRoomFacilities);
    List<String> masterPublicFacilities =
        List.from(ApiService.defaultPublicFacilities);
    final Set<String> selectedRoomFacilities = Set.from(kost.roomFacilities);
    final Set<String> selectedPublicFacilities =
        Set.from(kost.publicFacilities);
    bool loadedMasterFacilities = false;
    final rulesCtrl = TextEditingController(text: kost.rules.join(', '));

    String selectedCategory =
        ['KOST', 'APARTEMEN', 'KONTRAKAN'].contains(kost.propertyCategory)
            ? kost.propertyCategory
            : 'KOST';
    String selectedType =
        ['Putri', 'Putra', 'Campur'].contains(kost.type) ? kost.type : 'Campur';
    bool electricityIncluded = kost.electricityIncluded;
    bool isSinggahsini = kost.isSinggahsini;
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
          if (!loadedMasterFacilities) {
            loadedMasterFacilities = true;
            ApiService.fetchMasterFacilities().then((data) {
              if (!mounted) return;
              setModalState(() {
                masterRoomFacilities = data['room'] ?? masterRoomFacilities;
                masterPublicFacilities =
                    data['public'] ?? masterPublicFacilities;
              });
            });
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
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setModalState(() => selectedCategory = v);
                      }
                    },
                  ),
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
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Tipe',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Putri', child: Text('Putri')),
                            DropdownMenuItem(value: 'Putra', child: Text('Putra')),
                            DropdownMenuItem(value: 'Campur', child: Text('Campur')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setModalState(() => selectedType = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
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
                          decoration: const InputDecoration(
                            labelText: 'Harga / Bulan (Rp)',
                            border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: 'Kamar Tersedia',
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
                          controller: totalRoomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Kamar',
                            border: OutlineInputBorder(),
                          ),
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
                      labelText: 'Peraturan Kost (pisahkan dengan koma)',
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
                    title: const Text('Badge HuniVio Pilihan'),
                    activeColor: AppColors.primaryGreen,
                    value: isSinggahsini,
                    onChanged: (v) => setModalState(() => isSinggahsini = v),
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

                                await ApiService.updateKost(kost.id, {
                                  'propertyCategory': selectedCategory,
                                  'name': nameCtrl.text.trim(),
                                  'type': selectedType,
                                  'city': cityCtrl.text.trim(),
                                  'district': districtCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'nearbyLandmark': landmarkCtrl.text.trim(),
                                  'pricePerMonth':
                                      int.parse(priceCtrl.text.trim()),
                                  'availableRooms':
                                      int.parse(roomsCtrl.text.trim()),
                                  'totalRooms': int.tryParse(
                                          totalRoomsCtrl.text.trim()) ??
                                      kost.totalRooms,
                                  'roomSize': roomSizeCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'roomFacilities':
                                      selectedRoomFacilities.toList(),
                                  'publicFacilities':
                                      selectedPublicFacilities.toList(),
                                  'rules': splitCsv(rulesCtrl.text),
                                  'electricityIncluded': electricityIncluded,
                                  'isSinggahsini': isSinggahsini,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRooms =
        _kosts.fold<int>(0, (sum, k) => sum + k.totalRooms);
    final availableRooms =
        _kosts.fold<int>(0, (sum, k) => sum + k.availableRooms);
    final occupiedRooms = (totalRooms - availableRooms).clamp(0, totalRooms);
    final occupancyPct =
        totalRooms > 0 ? ((occupiedRooms / totalRooms) * 100).round() : 0;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Kelola Properti',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: _canApprove,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryGreen,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Properti (${_kosts.length})'),
            Tab(text: 'Pengajuan Masuk (${_incomingBookings.length})'),
            if (_canApprove) Tab(text: 'Approval (${_pendingKosts.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Dashboard Okupansi Strip
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
                  label: 'Okupansi',
                  value: '$occupancyPct%',
                  icon: Icons.pie_chart_rounded,
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
                        color: b.isSurvey
                            ? Colors.blue.shade50
                            : AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.isSurvey ? 'SURVEI' : 'SEWA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: b.isSurvey
                              ? Colors.blue.shade700
                              : AppColors.darkGreen,
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
                  b.isSurvey
                      ? 'Jadwal Survei: ${b.surveyDateTime}'
                      : 'Mulai: ${b.startDate} • ${b.durationMonths} bln • Estimasi ${formatRupiah(b.totalPrice)}',
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
              ],
            ),
          );
        },
      ),
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
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Sisa ${kost.availableRooms}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
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
                                                Text(
                                                  '${formatRupiah(kost.pricePerMonth)}/bln',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.primaryGreen,
                                                  ),
                                                ),
                                                const Spacer(),
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
                                                if (widget.user.isAdministrator ||
                                                    kost.ownerId ==
                                                        widget.user.id) ...[
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
    if (_pendingKosts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadPendingProperties,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'Tidak ada properti yang menunggu persetujuan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadPendingProperties,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingKosts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final kost = _pendingKosts[index];
          final isProcessing = _processingApprovalIds.contains(kost.id);
          final thumb = kost.images.isNotEmpty ? kost.images.first : '';
          return InkWell(
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
                              '${formatRupiah(kost.pricePerMonth)}/bln • ${kost.totalRooms} unit',
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
          );
        },
      ),
    );
  }
}
