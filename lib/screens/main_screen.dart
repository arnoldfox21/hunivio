import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/kost.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';
import '../widgets/animated_vectors.dart';
import '../widgets/app_user_guide_overlay.dart';
import '../widgets/kost_card.dart';
import '../widgets/location_autocomplete_field.dart';
import '../widgets/kost_map_search_view.dart';
import '../widgets/facility_checkbox_group.dart';
import 'auth_profile_tab.dart';
import 'chat_inbox_screen.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';
import 'kost_group_chat_screen.dart';
import 'kost_location_picker_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedTabIndex = 0;

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _exploreScrollCtrl = ScrollController();
  final GlobalKey _guideSearchKey = GlobalKey();
  final GlobalKey _guideFilterKey = GlobalKey();
  final GlobalKey _guideMapToggleKey = GlobalKey();
  final GlobalKey _guideChatKey = GlobalKey();
  final GlobalKey _guideProfileBtnKey = GlobalKey();
  final GlobalKey _guideNavFavKey = GlobalKey();
  final GlobalKey _guideNavSewaKey = GlobalKey();
  Timer? _searchDebounce;
  Timer? _userGuideTimer;
  String _selectedCategory = 'SEMUA'; // 'SEMUA' | 'KOST' | 'APARTEMEN' | 'KONTRAKAN'
  String _selectedCity = 'Semua Kota';
  String _selectedType = 'Semua';
  String? _selectedFacility;
  int? _minPrice;
  int? _maxPrice;
  bool _onlyAvailable = false;
  String _sortBy = 'recommended';
  bool _isMapMode = false;

  // Data (Dynamic from PostgreSQL DB)
  List<Kost> _kosts = [];
  List<Kost> _mapKosts = [];
  List<Kost> _favoriteKosts = [];
  List<Booking> _bookings = [];
  bool _loadingKosts = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalKosts = 0;
  bool _loadingBookings = false;
  String? _errorMsg;

  List<String> _cities = ['Semua Kota'];
  List<String> _kostTypes = ['Semua'];
  List<String> _facilityChips = [];

  @override
  void initState() {
    super.initState();
    _exploreScrollCtrl.addListener(_onExploreScroll);
    AuthService.currentUserNotifier.addListener(_onAuthStateChanged);
    _loadDynamicFilters();
    _loadFavorites();
    _loadKosts();
    _loadBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userGuideTimer = Timer(const Duration(milliseconds: 600), () {
        _maybeShowFirstInstallUserGuide();
      });
    });
  }

  Future<void> _maybeShowFirstInstallUserGuide() async {
    if (!mounted || _selectedTabIndex != 0) return;
    await AppUserGuideOverlay.showIfFirstInstall(context, [
      UserGuideStep(
        targetKey: _guideSearchKey,
        icon: Icons.search_rounded,
        title: 'Kolom Pencarian Cepat',
        description:
            'Ketik nama kost, kontrakan, apartemen, kampus, atau area yang ingin Anda cari.',
      ),
      UserGuideStep(
        targetKey: _guideFilterKey,
        icon: Icons.tune_rounded,
        title: 'Filter Harga & Ketersediaan',
        description:
            'Atur batas harga sewa minimum/maksimum dan tampilkan hanya unit yang masih tersedia.',
      ),
      UserGuideStep(
        targetKey: _guideMapToggleKey,
        icon: Icons.map_rounded,
        title: 'Beralih Mode Peta / Daftar',
        description:
            'Tekan tombol ini untuk melihat sebaran lokasi properti di peta interaktif atau daftar.',
      ),
      UserGuideStep(
        targetKey: _guideChatKey,
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Kotak Pesan & Grup',
        description:
            'Chat langsung dengan pemilik/penyewa atau bergabung dengan grup penghuni properti.',
        borderRadius: 20,
      ),
      UserGuideStep(
        targetKey: _guideProfileBtnKey,
        icon: Icons.account_circle_outlined,
        title: 'Profil & Masuk Akun Google',
        description:
            'Masuk dengan Google, ubah profil Anda, atau kelola properti jika Anda mendaftar sebagai pemilik.',
        borderRadius: 20,
      ),
      UserGuideStep(
        targetKey: _guideNavFavKey,
        icon: Icons.favorite_rounded,
        title: 'Menu Favorit',
        description:
            'Semua properti yang Anda tandai dengan ikon hati tersimpan di sini agar mudah dibandingkan.',
        borderRadius: 16,
      ),
      UserGuideStep(
        targetKey: _guideNavSewaKey,
        icon: Icons.receipt_long_rounded,
        title: 'Menu Sewa Saya',
        description:
            'Pantau status pengajuan sewa yang Anda kirim dan riwayat persetujuan dari pemilik.',
        borderRadius: 16,
      ),
    ]);
  }

  void _onAuthStateChanged() {
    if (mounted) _loadBookings();
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onAuthStateChanged);
    _searchDebounce?.cancel();
    _userGuideTimer?.cancel();
    _exploreScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onExploreScroll() {
    if (!_exploreScrollCtrl.hasClients || _loadingMore || !_hasMore) return;
    final pos = _exploreScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _loadMoreKosts();
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadKosts();
    });
  }

  Future<void> _loadDynamicFilters() async {
    try {
      final filters = await ApiService.fetchFilters();
      if (!mounted) return;
      setState(() {
        final dbCities = filters['cities'] ?? [];
        _cities = ['Semua Kota', ...dbCities];
        if (!_cities.contains(_selectedCity)) {
          _selectedCity = 'Semua Kota';
        }

        final dbTypes = filters['types'] ?? [];
        _kostTypes = ['Semua', ...dbTypes];

        final dbFacilities = filters['facilities'] ?? [];
        _facilityChips = dbFacilities;
      });
    } catch (_) {}
  }

  Future<void> _loadFavorites() async {
    try {
      final favRes = await ApiService.fetchKostsPaginated(
        onlyFavorite: true,
        page: 1,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _favoriteKosts = favRes.data;
      });
    } catch (_) {}
  }

  Future<void> _loadKosts() async {
    setState(() {
      _loadingKosts = true;
      _errorMsg = null;
      _currentPage = 1;
      _hasMore = true;
    });
    try {
      final result = await ApiService.fetchKostsPaginated(
        search: _searchCtrl.text,
        propertyCategory: _selectedCategory,
        type: _selectedType,
        city: _selectedCity,
        facility: _selectedFacility,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        onlyAvailable: _onlyAvailable,
        sortBy: _sortBy,
        page: 1,
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _kosts = result.data;
          _totalKosts = result.total;
          _hasMore = result.hasMore;
          _loadingKosts = false;
        });
      }
      if (_isMapMode) {
        _loadMapPoints();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _loadingKosts = false;
        });
      }
    }
  }

  Future<void> _loadMoreKosts() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await ApiService.fetchKostsPaginated(
        search: _searchCtrl.text,
        propertyCategory: _selectedCategory,
        type: _selectedType,
        city: _selectedCity,
        facility: _selectedFacility,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        onlyAvailable: _onlyAvailable,
        sortBy: _sortBy,
        page: nextPage,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _currentPage = nextPage;
        _kosts.addAll(result.data);
        _totalKosts = result.total;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMapPoints() async {
    try {
      final pts = await ApiService.fetchMapPoints(
        propertyCategory: _selectedCategory,
        type: _selectedType,
        city: _selectedCity,
      );
      if (mounted) {
        setState(() => _mapKosts = pts);
      }
    } catch (_) {}
  }

  Future<void> _loadBookings() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _bookings = [];
          _loadingBookings = false;
        });
      }
      return;
    }
    setState(() => _loadingBookings = true);
    try {
      final list = await ApiService.fetchBookings(userId: user.id);
      if (mounted) {
        setState(() {
          _bookings = list;
          _loadingBookings = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingBookings = false);
      }
    }
  }

  Future<void> _toggleFavorite(int id) async {
    final wasFav = _isFavorite(id);
    final nextFav = !wasFav;
    Kost? targetKost;
    for (final k in _kosts) {
      if (k.id == id) {
        targetKost = k;
        break;
      }
    }
    targetKost ??= _favoriteKosts.cast<Kost?>().firstWhere(
          (k) => k?.id == id,
          orElse: () => null,
        );

    setState(() {
      _kosts = _kosts
          .map((k) => k.id == id ? k.copyWith(isFavorite: nextFav) : k)
          .toList();
      if (nextFav) {
        if (targetKost != null && !_favoriteKosts.any((k) => k.id == id)) {
          _favoriteKosts = [
            targetKost.copyWith(isFavorite: true),
            ..._favoriteKosts,
          ];
        }
      } else {
        _favoriteKosts.removeWhere((k) => k.id == id);
      }
    });

    try {
      final updated = await ApiService.toggleFavorite(id);
      if (!mounted) return;
      setState(() {
        _kosts = _kosts.map((k) => k.id == id ? updated : k).toList();
        if (updated.isFavorite) {
          final idx = _favoriteKosts.indexWhere((k) => k.id == id);
          if (idx >= 0) {
            _favoriteKosts[idx] = updated;
          } else {
            _favoriteKosts = [updated, ..._favoriteKosts];
          }
        } else {
          _favoriteKosts.removeWhere((k) => k.id == id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Revert optimistic update on failure
      setState(() {
        _kosts = _kosts
            .map((k) => k.id == id ? k.copyWith(isFavorite: wasFav) : k)
            .toList();
        if (wasFav && targetKost != null && !_favoriteKosts.any((k) => k.id == id)) {
          _favoriteKosts = [
            targetKost.copyWith(isFavorite: true),
            ..._favoriteKosts,
          ];
        } else if (!wasFav) {
          _favoriteKosts.removeWhere((k) => k.id == id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal mengubah status favorit: $e'),
        ),
      );
    }
  }

  bool _isFavorite(int id) {
    final idx = _kosts.indexWhere((k) => k.id == id);
    if (idx >= 0) return _kosts[idx].isFavorite;
    return _favoriteKosts.any((k) => k.id == id);
  }

  void _openKostDetail(Kost kost) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KostDetailScreen(
          kost: kost,
          isFavorite: _isFavorite(kost.id),
          onToggleFavorite: () => _toggleFavorite(kost.id),
          onBookingCreated: () {
            _loadBookings();
            _loadKosts();
          },
        ),
      ),
    );
  }

  void _showCreateKostSheet() {
    final currentUser = AuthService.currentUser;
    if (currentUser == null || !currentUser.canManageKost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fitur Tambah Properti hanya tersedia untuk Administrator, Staff, dan Pemilik Kost.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final districtCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final roomsCtrl = TextEditingController(text: '5');
    final roomSizeCtrl = TextEditingController(text: '3 x 4 m');
    final ownerNameCtrl = TextEditingController(text: currentUser.name);
    final ownerPhoneCtrl = TextEditingController(text: currentUser.phone);
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final rulesCtrl = TextEditingController();
    List<String> masterRoomFacilities =
        List.from(ApiService.defaultRoomFacilities);
    List<String> masterPublicFacilities =
        List.from(ApiService.defaultPublicFacilities);
    final Set<String> selectedRoomFacilities = {};
    final Set<String> selectedPublicFacilities = {};
    bool loadedMasterFacilities = false;
    final imagePicker = ImagePicker();
    final List<XFile> pickedImages = [];
    final List<String> imageUrls = [];
    String selectedType = 'Campur';
    bool electricityIncluded = false;
    bool isSinggahsini = true;
    bool submitting = false;
    LatLng? pickedLocation;
    bool loadingCurrentGps = false;
    bool loadingAddress = false;

    Future<void> applyPinLocation(
      LatLng point,
      void Function(void Function()) setModalState,
      BuildContext modalContext,
    ) async {
      if (!mounted || !modalContext.mounted) return;
      setModalState(() {
        pickedLocation = point;
        loadingAddress = true;
      });
      try {
        final geo = await LocationHelper.reverseGeocode(point);
        if (!mounted || !modalContext.mounted) return;
        setModalState(() {
          loadingAddress = false;
          if (geo != null) {
            if (geo.city.isNotEmpty) cityCtrl.text = geo.city;
            if (geo.district.isNotEmpty) districtCtrl.text = geo.district;
            if (geo.address.isNotEmpty) addressCtrl.text = geo.address;
          }
        });
      } catch (_) {
        if (mounted && modalContext.mounted) {
          setModalState(() => loadingAddress = false);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 18,
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
                          'Tambah Properti Baru',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pin_drop_rounded,
                              size: 18,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Pin Lokasi Properti di Peta',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (pickedLocation != null)
                              GestureDetector(
                                onTap: () => setModalState(
                                  () => pickedLocation = null,
                                ),
                                child: Text(
                                  'Hapus',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loadingAddress
                              ? 'Mengambil kota, kecamatan, dan alamat otomatis...'
                              : pickedLocation != null
                                  ? 'Koordinat terpilih: ${pickedLocation!.latitude.toStringAsFixed(6)}, ${pickedLocation!.longitude.toStringAsFixed(6)}'
                                  : 'Tandai di peta untuk mengisi kota, kecamatan, dan alamat otomatis.',
                          style: TextStyle(
                            fontSize: 12,
                            color: pickedLocation != null
                                ? AppColors.darkGreen
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final result =
                                      await Navigator.of(ctx).push<LatLng>(
                                    MaterialPageRoute(
                                      builder: (_) => KostLocationPickerScreen(
                                        initialLocation: pickedLocation,
                                      ),
                                    ),
                                  );
                                  if (result != null && ctx.mounted) {
                                    await applyPinLocation(
                                      result,
                                      setModalState,
                                      ctx,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.map_outlined,
                                  size: 17,
                                ),
                                label: Text(
                                  pickedLocation != null
                                      ? 'Ubah Pin'
                                      : 'Pilih di Peta',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: loadingCurrentGps
                                    ? null
                                    : () async {
                                        setModalState(
                                          () => loadingCurrentGps = true,
                                        );
                                        final res = await LocationHelper
                                            .getCurrentLocation();
                                        if (!mounted || !ctx.mounted) return;
                                        setModalState(() {
                                          loadingCurrentGps = false;
                                        });
                                        if (res.isUserLocation) {
                                          await applyPinLocation(
                                            res.location,
                                            setModalState,
                                            ctx,
                                          );
                                        }
                                        if (res.message != null && ctx.mounted) {
                                          ScaffoldMessenger.of(ctx)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(res.message!),
                                            ),
                                          );
                                        }
                                      },
                                icon: loadingCurrentGps
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        size: 17,
                                      ),
                                label: const Text('Lokasi Saya'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Tipe Hunian',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Putri',
                              child: Text('Putri'),
                            ),
                            DropdownMenuItem(
                              value: 'Putra',
                              child: Text('Putra'),
                            ),
                            DropdownMenuItem(
                              value: 'Campur',
                              child: Text('Campur'),
                            ),
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
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Wajib diisi'
                              : null,
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
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga / Bulan (Rp)',
                            hintText: '1500000',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: roomsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sisa Kamar',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: roomSizeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ukuran Kamar',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ownerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama Pemilik',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: ownerPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'No. WA Pemilik',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
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
                      labelText: 'Peraturan Properti (pisahkan dengan koma)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Foto Kost',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final files =
                                      await imagePicker.pickMultiImage(
                                    imageQuality: 80,
                                    maxWidth: 1280,
                                  );
                                  if (files.isNotEmpty) {
                                    setModalState(() {
                                      pickedImages.addAll(files);
                                    });
                                  }
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeri'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final file = await imagePicker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 80,
                                    maxWidth: 1280,
                                  );
                                  if (file != null) {
                                    setModalState(() {
                                      pickedImages.add(file);
                                    });
                                  }
                                },
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Kamera'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: imageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Atau tambah URL Foto Kost',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Tambah URL Foto',
                        onPressed: submitting
                            ? null
                            : () {
                                final url = imageCtrl.text.trim();
                                if (url.isNotEmpty &&
                                    !imageUrls.contains(url)) {
                                  setModalState(() {
                                    imageUrls.add(url);
                                    imageCtrl.clear();
                                  });
                                }
                              },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  if (pickedImages.isNotEmpty || imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 86,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...pickedImages.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final file = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(file.path),
                                      width: 86,
                                      height: 86,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: submitting
                                          ? null
                                          : () => setModalState(
                                              () => pickedImages.removeAt(idx),
                                            ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          ...imageUrls.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final url = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      url,
                                      width: 86,
                                      height: 86,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 86,
                                        height: 86,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: submitting
                                          ? null
                                          : () => setModalState(
                                              () => imageUrls.removeAt(idx),
                                            ),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi Kost',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Termasuk Listrik'),
                    value: electricityIncluded,
                    onChanged: (v) =>
                        setModalState(() => electricityIncluded = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Badge HuniVio Pilihan'),
                    value: isSinggahsini,
                    onChanged: (v) => setModalState(() => isSinggahsini = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => submitting = true);
                              try {
                                final navigator = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                final facilities =
                                    selectedRoomFacilities.toList();
                                final publicFacilities =
                                    selectedPublicFacilities.toList();
                                final rules = rulesCtrl.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                final rooms =
                                    int.tryParse(roomsCtrl.text.trim()) ?? 1;
                                final List<String> finalImages = [
                                  ...imageUrls,
                                ];
                                final typedUrl = imageCtrl.text.trim();
                                if (typedUrl.isNotEmpty &&
                                    !finalImages.contains(typedUrl)) {
                                  finalImages.add(typedUrl);
                                }
                                for (final picked in pickedImages) {
                                  final uploadedUrl =
                                      await ApiService.uploadKostImage(
                                    File(picked.path),
                                  );
                                  finalImages.add(uploadedUrl);
                                }
                                await ApiService.createKost({
                                  'name': nameCtrl.text.trim(),
                                  'type': selectedType,
                                  'city': cityCtrl.text.trim(),
                                  'district': districtCtrl.text.trim(),
                                  'address': addressCtrl.text.trim(),
                                  'nearbyLandmark': landmarkCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'pricePerMonth':
                                      int.parse(priceCtrl.text.trim()),
                                  'availableRooms': rooms,
                                  'totalRooms': rooms,
                                  'roomSize': roomSizeCtrl.text.trim(),
                                  'electricityIncluded': electricityIncluded,
                                  'isSinggahsini': isSinggahsini,
                                  'isInstantBooking': true,
                                  'roomFacilities': facilities,
                                  'publicFacilities': publicFacilities,
                                  'rules': rules,
                                  'images': finalImages,
                                  'ownerName': ownerNameCtrl.text.trim(),
                                  'ownerPhone': ownerPhoneCtrl.text.trim(),
                                  'ownerId': currentUser.id,
                                  if (pickedLocation != null)
                                    'latitude': pickedLocation!.latitude,
                                  if (pickedLocation != null)
                                    'longitude': pickedLocation!.longitude,
                                });
                                if (!mounted) return;
                                navigator.pop();
                                await _loadKosts();
                                final autoApproved =
                                    currentUser.canApproveProperties;
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: autoApproved
                                        ? AppColors.primaryGreen
                                        : const Color(0xFFD97706),
                                    content: Text(
                                      autoApproved
                                          ? 'Properti baru berhasil ditambahkan & langsung disetujui!'
                                          : 'Properti berhasil diajukan! Menunggu persetujuan Administrator/Staff.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => submitting = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade700,
                                    content: Text('Gagal menyimpan properti: $e'),
                                  ),
                                );
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Kost',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  void _showApiEndpointDialog() {
    String selectedUrl = ApiService.baseUrl;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Endpoint API',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEndpointOption(
                    title: 'Lokal (Saat Ini)',
                    subtitle: ApiService.localBaseUrl,
                    selected: selectedUrl == ApiService.localBaseUrl,
                    onTap: () => setDialogState(
                      () => selectedUrl = ApiService.localBaseUrl,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildEndpointOption(
                    title: 'Online (Vercel)',
                    subtitle: ApiService.onlineBaseUrl,
                    selected: selectedUrl == ApiService.onlineBaseUrl,
                    onTap: () => setDialogState(
                      () => selectedUrl = ApiService.onlineBaseUrl,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final changed = selectedUrl != ApiService.baseUrl;
                    ApiService.setBaseUrl(selectedUrl);
                    Navigator.of(dialogContext).pop();
                    if (changed) {
                      _loadKosts();
                      _loadBookings();
                    }
                    final label = ApiService.isOnline
                        ? 'Online (hunivio-api.vercel.app)'
                        : 'Lokal (192.168.18.12:3001)';
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primaryGreen,
                        content: Text('Endpoint API aktif: $label'),
                      ),
                    );
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEndpointOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGreenBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primaryGreen : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: selected ? AppColors.darkGreen : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEF2F6)),
        ),
        title: GestureDetector(
          onLongPress: _showApiEndpointDialog,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/hunivio_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HuniVio',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    'Cari & Sewa Kost Terpercaya',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.totalUnreadCount,
            builder: (context, unread, _) {
              return IconButton(
                key: _guideChatKey,
                tooltip: 'Kotak Pesan',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatInboxScreen()),
                  );
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  backgroundColor: AppColors.primaryGreen,
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<UserProfile?>(
            valueListenable: AuthService.currentUserNotifier,
            builder: (context, user, _) {
              if (user == null || !user.canManageKost) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Tambah Properti',
                onPressed: _showCreateKostSheet,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primaryGreen,
                ),
              );
            },
          ),
          ValueListenableBuilder<UserProfile?>(
            valueListenable: AuthService.currentUserNotifier,
            builder: (context, user, _) {
              final fallbackAvatar = user != null
                  ? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(user.name.isNotEmpty ? user.name : 'User')}&background=1BAA56&color=ffffff&size=128&bold=true&format=png'
                  : '';
              final avatarUrl = user != null
                  ? (user.avatarUrl.trim().isNotEmpty
                      ? user.avatarUrl.trim()
                      : fallbackAvatar)
                  : '';
              return IconButton(
                key: _guideProfileBtnKey,
                tooltip: user != null
                    ? 'Akun: ${user.name}'
                    : 'Masuk / Daftar via Google',
                onPressed: () {
                  setState(() => _selectedTabIndex = 3);
                },
                icon: user != null
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightGreenBg,
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            avatarUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.account_circle_outlined,
                        color: Colors.blueGrey,
                      ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildExploreTab(),
          _buildFavoritesTab(),
          _buildBookingsTab(),
          const AuthProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (idx) {
            setState(() => _selectedTabIndex = idx);
            if (idx == 1) _loadDynamicFilters();
            if (idx == 2) _loadBookings();
          },
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 68,
          indicatorColor: AppColors.lightGreenBg,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primaryGreen,
            ),
            label: 'Cari Kost',
          ),
          NavigationDestination(
            key: _guideNavFavKey,
            icon: Badge(
              isLabelVisible: _favoriteKosts.isNotEmpty,
              label: Text('${_favoriteKosts.length}'),
              child: const Icon(Icons.favorite_border_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: _favoriteKosts.isNotEmpty,
              label: Text('${_favoriteKosts.length}'),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            label: 'Favorit',
          ),
          NavigationDestination(
            key: _guideNavSewaKey,
            icon: Badge(
              isLabelVisible: _bookings.isNotEmpty,
              label: Text('${_bookings.length}'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _bookings.isNotEmpty,
              label: Text('${_bookings.length}'),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            label: 'Sewa Saya',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.primaryGreen,
            ),
            label: 'Akun',
          ),
        ],
        ),
      ),
    );
  }

  void _showAdvancedFilterSheet() {
    RangeValues priceRange = RangeValues(
      (_minPrice ?? 500000).toDouble().clamp(500000, 6000000),
      (_maxPrice ?? 6000000).toDouble().clamp(500000, 6000000),
    );
    bool onlyAvail = _onlyAvailable;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Cerdas',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Rentang Harga / Bulan: ${formatRupiah(priceRange.start.round())} - ${formatRupiah(priceRange.end.round())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              RangeSlider(
                values: priceRange,
                min: 500000,
                max: 6000000,
                divisions: 22,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) => setModalState(() => priceRange = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Hanya tampilkan yang tersedia',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                activeColor: AppColors.primaryGreen,
                value: onlyAvail,
                onChanged: (v) => setModalState(() => onlyAvail = v),
              ),
              const SizedBox(height: 6),
              const Text(
                'Shortcut Kampus & Area Malang',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: ['UB', 'UM', 'UIN', 'Polinema', 'UMM', 'Ijen', 'Sawojajar']
                    .map(
                      (tag) => ActionChip(
                        label: Text(tag),
                        backgroundColor: AppColors.lightGreenBg,
                        labelStyle: const TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onPressed: () {
                          _searchCtrl.text = tag;
                          Navigator.of(ctx).pop();
                          _loadKosts();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _minPrice = priceRange.start.round() > 500000
                          ? priceRange.start.round()
                          : null;
                      _maxPrice = priceRange.end.round() < 6000000
                          ? priceRange.end.round()
                          : null;
                      _onlyAvailable = onlyAvail;
                    });
                    Navigator.of(ctx).pop();
                    _loadKosts();
                  },
                  child: const Text(
                    'Terapkan Filter',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchFilterPanel() {
    final hasActiveFilter = _searchCtrl.text.trim().isNotEmpty ||
        _selectedCategory != 'SEMUA' ||
        _selectedCity != 'Semua Kota' ||
        _selectedType != 'Semua' ||
        _selectedFacility != null ||
        _minPrice != null ||
        _maxPrice != null ||
        _onlyAvailable;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF2F6), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar + Map/List Toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  key: _guideSearchKey,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5EAF0)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _loadKosts(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari nama kost, kampus, atau area...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGreen,
                        size: 21,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadKosts();
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            )
                          : IconButton(
                              onPressed: _loadKosts,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: _guideFilterKey,
                tooltip: 'Filter Harga & Kampus',
                style: IconButton.styleFrom(
                  backgroundColor: (_minPrice != null ||
                          _maxPrice != null ||
                          _onlyAvailable)
                      ? AppColors.primaryGreen
                      : const Color(0xFFF3F6F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _showAdvancedFilterSheet,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: (_minPrice != null ||
                          _maxPrice != null ||
                          _onlyAvailable)
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                key: _guideMapToggleKey,
                color: _isMapMode
                    ? AppColors.primaryGreen
                    : AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _isMapMode = !_isMapMode);
                    if (_isMapMode) {
                      _loadMapPoints();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isMapMode
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMapMode
                              ? Icons.view_list_rounded
                              : Icons.map_rounded,
                          size: 19,
                          color: _isMapMode
                              ? Colors.white
                              : AppColors.darkGreen,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isMapMode ? 'Daftar' : 'Peta',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _isMapMode
                                ? Colors.white
                                : AppColors.darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Multi-Property Category Strip (Semua, Kost, Apartemen, Kontrakan)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                ('SEMUA', 'Semua Properti', Icons.apps_rounded),
                ('KOST', 'Kost', Icons.bed_rounded),
                ('APARTEMEN', 'Apartemen', Icons.apartment_rounded),
                ('KONTRAKAN', 'Kontrakan', Icons.home_rounded),
              ].map((item) {
                final code = item.$1;
                final label = item.$2;
                final icon = item.$3;
                final selected = _selectedCategory == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: selected ? Colors.white : AppColors.primaryGreen,
                    ),
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primaryGreen,
                    backgroundColor: AppColors.lightGreenBg.withOpacity(0.55),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primaryGreen
                          : AppColors.primaryGreen.withOpacity(0.2),
                    ),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = code);
                      _loadKosts();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // City Horizontal Chips
          SizedBox(
            height: 35,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _cities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, idx) {
                final city = _cities[idx];
                final selected = _selectedCity == city;
                return ChoiceChip(
                  label: Text(city),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primaryGreen,
                  backgroundColor: const Color(0xFFF3F6F9),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primaryGreen
                        : const Color(0xFFE5EAF0),
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCity = city);
                    _loadKosts();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Kost Type + Facility + Reset Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (hasActiveFilter)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(
                        Icons.refresh_rounded,
                        size: 15,
                        color: AppColors.discountRed,
                      ),
                      label: const Text('Reset'),
                      backgroundColor: const Color(0xFFFFEBEE),
                      side: BorderSide(color: Colors.red.shade200),
                      shape: const StadiumBorder(),
                      labelStyle: const TextStyle(
                        color: AppColors.discountRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedCategory = 'SEMUA';
                          _selectedCity = 'Semua Kota';
                          _selectedType = 'Semua';
                          _selectedFacility = null;
                          _minPrice = null;
                          _maxPrice = null;
                          _onlyAvailable = false;
                        });
                        _loadKosts();
                      },
                    ),
                  ),
                // Gender Type Segmented Pills
                ..._kostTypes.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        type == 'Semua' ? 'Semua Tipe' : 'Kost $type',
                      ),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppColors.lightGreenBg,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.darkGreen
                            : Colors.grey.shade800,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedType = type);
                        _loadKosts();
                      },
                    ),
                  );
                }),
                const SizedBox(width: 2),
                // Facility chips
                ..._facilityChips.map((fac) {
                  final isSelected = _selectedFacility == fac;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(fac),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: AppColors.lightGreenBg,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.darkGreen
                            : Colors.grey.shade700,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedFacility = isSelected ? null : fac;
                        });
                        _loadKosts();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab() {
    if (_isMapMode) {
      return Column(
        children: [
          _buildTopSearchFilterPanel(),
          Expanded(
            child: KostMapSearchView(
              kosts: _mapKosts.isNotEmpty ? _mapKosts : _kosts,
              onOpenDetail: _openKostDetail,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadKosts,
      child: CustomScrollView(
        controller: _exploreScrollCtrl,
        slivers: [
          // Top Search & Filter Panel
          SliverToBoxAdapter(
            child: _buildTopSearchFilterPanel(),
          ),

          // Promo Banner + Sort Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1BAA56), Color(0xFF0A6832)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Promo Anak Kost Spesial!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Diskon sewa bulan pertama s/d 20% di kost pilihan terverifikasi.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_offer_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Ditemukan ${_totalKosts > 0 ? _totalKosts : _kosts.length} properti tersedia',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'recommended',
                              child: Text('Urutkan: Rekomendasi'),
                            ),
                            DropdownMenuItem(
                              value: 'price_asc',
                              child: Text('Harga Terendah'),
                            ),
                            DropdownMenuItem(
                              value: 'price_desc',
                              child: Text('Harga Tertinggi'),
                            ),
                            DropdownMenuItem(
                              value: 'rating_desc',
                              child: Text('Rating Tertinggi'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              _loadKosts();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Kost List Body
          if (_loadingKosts)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (_errorMsg != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Gagal Memuat Data Kost',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Periksa koneksi internet Anda lalu coba kembali.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _loadKosts,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_kosts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 54,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tidak ada kost yang sesuai filter',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _selectedCity = 'Semua Kota';
                          _selectedType = 'Semua';
                          _selectedFacility = null;
                          _sortBy = 'recommended';
                        });
                        _loadKosts();
                      },
                      child: const Text('Reset Semua Filter'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _kosts.length) {
                      if (_loadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Memuat properti lainnya...',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Semua $_totalKosts properti telah ditampilkan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }
                    final kost = _kosts[index];
                    return StaggeredEntrance(
                      index: index,
                      child: KostCard(
                        kost: kost,
                        isFavorite: _isFavorite(kost.id),
                        onTap: () => _openKostDetail(kost),
                        onToggleFavorite: () => _toggleFavorite(kost.id),
                      ),
                    );
                  },
                  childCount: _kosts.length +
                      (_loadingMore || (!_hasMore && _kosts.isNotEmpty)
                          ? 1
                          : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final favKosts = _favoriteKosts;
    if (favKosts.isEmpty) {
      return const AnimatedVectorEmptyState(
        icon: Icons.favorite_rounded,
        title: 'Belum ada Kost Favorit',
        subtitle:
            'Tekan ikon hati pada daftar hunian untuk menyimpannya di sini.',
        accentColor: AppColors.putriPink,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favKosts.length,
      itemBuilder: (context, idx) {
        final kost = favKosts[idx];
        return KostCard(
          kost: kost,
          isFavorite: true,
          onTap: () => _openKostDetail(kost),
          onToggleFavorite: () => _toggleFavorite(kost.id),
        );
      },
    );
  }

  Widget _buildBookingsTab() {
    final user = AuthService.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'Masuk untuk Melihat Pengajuan Sewa',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Silakan masuk di tab Profil agar riwayat sewa dan survei Anda tampil sesuai akun.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    if (_loadingBookings) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Pengajuan Sewa',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih kost dan klik "Ajukan Sewa" untuk menyewa kamar.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, idx) {
          final b = _bookings[idx];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (b.status == 'DIBATALKAN' ||
                                  b.status == 'DITOLAK')
                              ? const Color(0xFFFEE2E2)
                              : AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b.status,
                          style: TextStyle(
                            color: (b.status == 'DIBATALKAN' ||
                                    b.status == 'DITOLAK')
                                ? AppColors.discountRed
                                : AppColors.darkGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Mulai: ${b.startDate} (${b.durationMonths} bln)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    b.kost?.name ?? 'Kost #${b.kostId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Penyewa: ${b.tenantName} (${b.tenantPhone})',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (b.notes != null && b.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan: ${b.notes}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const Divider(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.isSurvey
                                  ? 'Jadwal Survei: ${b.surveyDateTime}'
                                  : 'Estimasi Biaya Sewa',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Transaksi diselesaikan langsung dengan pemilik di luar aplikasi',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!b.isSurvey) ...[
                        const SizedBox(width: 10),
                        Text(
                          formatRupiah(b.totalPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (b.kost != null ||
                      (b.status != 'DIBATALKAN' && b.status != 'DITOLAK')) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (b.status != 'DIBATALKAN' && b.status != 'DITOLAK')
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.discountRed,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              onPressed: () => _confirmCancelBooking(b),
                              icon: const Icon(Icons.close_rounded, size: 17),
                              label: const Text(
                                'Batalkan',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        if (b.status != 'DIBATALKAN' &&
                            b.status != 'DITOLAK' &&
                            b.kost != null)
                          const SizedBox(width: 10),
                        if (b.kost != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => KostChatScreen(kost: b.kost!),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_rounded, size: 17),
                              label: const Text(
                                'Chat Pemilik',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (!b.isSurvey &&
                      (b.status == 'DISETUJUI' ||
                          b.status == 'APPROVED' ||
                          b.status == 'AKTIF')) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KostGroupChatScreen(
                                kostId: b.kostId,
                                kostName: b.kost?.name ?? 'Grup Penghuni',
                                kostImage: b.kost?.images.isNotEmpty == true
                                    ? b.kost!.images.first
                                    : '',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.groups_rounded, size: 18),
                        label: const Text(
                          'Grup Penghuni Kost',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmCancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Batalkan Pengajuan?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Yakin ingin membatalkan pengajuan untuk ${booking.kost?.name ?? 'properti ini'}?',
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
        userId: AuthService.currentUser?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.primaryGreen,
          content: Text('Pengajuan berhasil dibatalkan.'),
        ),
      );
      _loadBookings();
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
}
