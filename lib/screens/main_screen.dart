import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kost.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import '../widgets/animated_vectors.dart';
import '../widgets/app_user_guide_overlay.dart';
import '../widgets/kost_card.dart';
import '../widgets/kost_map_search_view.dart';
import 'add_property_wizard_screen.dart';
import 'auth_profile_tab.dart';
import 'chat_inbox_screen.dart';
import 'compare_kosts_screen.dart';
import 'kost_chat_screen.dart';
import 'kost_detail_screen.dart';
import 'kost_group_chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedTabIndex = 0;

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _favSearchCtrl = TextEditingController();
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
  String _stayDurationMode = 'LONG_TERM'; // 'LONG_TERM' | 'HUNIAN_HARIAN'
  String _selectedCategory = 'LONG_TERM'; // 'LONG_TERM' | 'KOST' | 'APARTEMEN' | 'KONTRAKAN' | 'HUNIAN_HARIAN'
  String _selectedDailySubType = 'Semua'; // 'Semua' | 'Villa' | 'Homestay'
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
  Set<int> _seenFavoriteIds = {};
  Set<String> _seenBookingKeys = {};
  bool _seenFavoritesLoaded = false;
  bool _seenBookingsLoaded = false;
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
  List<String> _searchHistory = [];
  static const String _searchHistoryPrefsKey = 'search_history_list';
  List<Kost> _recentlyViewedKosts = [];
  static const String _recentKostIdsPrefsKey = 'recently_viewed_kost_ids';
  bool _compareMode = false;
  final Set<int> _compareIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exploreScrollCtrl.addListener(_onExploreScroll);
    AuthService.currentUserNotifier.addListener(_onAuthStateChanged);
    _loadDynamicFilters();
    _loadSearchHistory();
    _loadRecentlyViewed();
    _loadSeenFavorites();
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
        icon: Icons.event_available_rounded,
        title: 'Menu Jadwal Survei',
        description:
            'Pantau jadwal survei properti yang Anda ajukan dan konfirmasi dari pemilik.',
        borderRadius: 16,
      ),
    ]);
  }

  void _onAuthStateChanged() {
    if (mounted) {
      _loadBookings();
      _loadFavorites();
      _loadKosts();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuthService.verifyActiveSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.currentUserNotifier.removeListener(_onAuthStateChanged);
    _searchDebounce?.cancel();
    _userGuideTimer?.cancel();
    _exploreScrollCtrl.dispose();
    _searchCtrl.dispose();
    _favSearchCtrl.dispose();
    super.dispose();
  }

  void _onExploreScroll() {
    if (!_exploreScrollCtrl.hasClients || _loadingMore || !_hasMore) return;
    final pos = _exploreScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _loadMoreKosts();
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_searchHistoryPrefsKey) ?? const [];
    if (!mounted) return;
    setState(() => _searchHistory = saved.take(10).toList());
  }

  Future<void> _saveSearchHistory(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.length < 2) return;
    final next = [
      q,
      ..._searchHistory.where((e) => e.toLowerCase() != q.toLowerCase()),
    ].take(10).toList();
    setState(() => _searchHistory = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryPrefsKey, next);
  }

  Future<void> _removeSearchHistoryItem(String query) async {
    final next = _searchHistory.where((e) => e != query).toList();
    setState(() => _searchHistory = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryPrefsKey, next);
  }

  Future<void> _clearSearchHistory() async {
    setState(() => _searchHistory = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryPrefsKey);
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (_searchCtrl.text.trim().isNotEmpty) {
        _saveSearchHistory(_searchCtrl.text);
      }
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

  static const String _seenFavoritesPrefsKey = 'seen_favorite_ids';
  static String _seenBookingsPrefsKey(int userId) => 'seen_bookings_$userId';
  static String _bookingSeenKey(Booking b) =>
      '${b.id}:${b.status}';

  int get _unseenFavoriteCount => _seenFavoritesLoaded
      ? _favoriteKosts.where((k) => !_seenFavoriteIds.contains(k.id)).length
      : 0;

  int get _unseenBookingCount => _seenBookingsLoaded
      ? _bookings
          .where((b) => !_seenBookingKeys.contains(_bookingSeenKey(b)))
          .length
      : 0;

  Future<void> _loadSeenFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_seenFavoritesPrefsKey) ?? const [];
    final ids = raw.map(int.tryParse).whereType<int>().toSet();
    if (!mounted) return;
    setState(() {
      _seenFavoriteIds = ids;
      _seenFavoritesLoaded = true;
      if (_selectedTabIndex == 1) {
        _seenFavoriteIds.addAll(_favoriteKosts.map((k) => k.id));
      }
    });
    if (_selectedTabIndex == 1 && _favoriteKosts.isNotEmpty) {
      await _persistSeenFavorites();
    }
  }

  Future<void> _persistSeenFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenFavoritesPrefsKey,
      _seenFavoriteIds.map((id) => id.toString()).toList(),
    );
  }

  void _markFavoritesSeen() {
    if (_favoriteKosts.isEmpty) return;
    final currentIds = _favoriteKosts.map((k) => k.id).toSet();
    if (_seenFavoriteIds.containsAll(currentIds)) return;
    setState(() {
      _seenFavoriteIds = {..._seenFavoriteIds, ...currentIds};
    });
    _persistSeenFavorites();
  }

  Future<void> _persistSeenBookings(int userId, Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenBookingsPrefsKey(userId), keys.toList());
  }

  void _markBookingsSeen() {
    final user = AuthService.currentUser;
    if (user == null || _bookings.isEmpty) return;
    final currentKeys = _bookings.map(_bookingSeenKey).toSet();
    if (_seenBookingKeys.containsAll(currentKeys)) return;
    setState(() {
      _seenBookingKeys = currentKeys;
      _seenBookingsLoaded = true;
    });
    _persistSeenBookings(user.id, currentKeys);
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
        if (_selectedTabIndex == 1) {
          _seenFavoriteIds = {
            ..._seenFavoriteIds,
            ...favRes.data.map((k) => k.id),
          };
        }
      });
      if (_selectedTabIndex == 1 && favRes.data.isNotEmpty) {
        await _persistSeenFavorites();
      }
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
        unitType:
            _stayDurationMode == 'HUNIAN_HARIAN' ? _selectedDailySubType : null,
        type: _stayDurationMode == 'HUNIAN_HARIAN' ? null : _selectedType,
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
        unitType:
            _stayDurationMode == 'HUNIAN_HARIAN' ? _selectedDailySubType : null,
        type: _stayDurationMode == 'HUNIAN_HARIAN' ? null : _selectedType,
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
        unitType:
            _stayDurationMode == 'HUNIAN_HARIAN' ? _selectedDailySubType : null,
        type: _stayDurationMode == 'HUNIAN_HARIAN' ? null : _selectedType,
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
          _seenBookingKeys = {};
          _seenBookingsLoaded = false;
          _loadingBookings = false;
        });
      }
      return;
    }
    setState(() => _loadingBookings = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys =
          (prefs.getStringList(_seenBookingsPrefsKey(user.id)) ?? const [])
              .toSet();
      final list = await ApiService.fetchBookings(userId: user.id);
      if (!mounted) return;
      final currentKeys = list.map(_bookingSeenKey).toSet();
      final nextSeen = _selectedTabIndex == 2
          ? currentKeys
          : savedKeys.intersection(currentKeys);
      setState(() {
        _bookings = list;
        _seenBookingKeys = nextSeen;
        _seenBookingsLoaded = true;
        _loadingBookings = false;
      });
      if (_selectedTabIndex == 2 || nextSeen.length != savedKeys.length) {
        await prefs.setStringList(
          _seenBookingsPrefsKey(user.id),
          nextSeen.toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingBookings = false);
      }
    }
  }

  Future<void> _loadRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final rawIds = prefs.getStringList(_recentKostIdsPrefsKey) ?? const [];
    final ids = rawIds.map(int.tryParse).whereType<int>().toList();
    if (ids.isEmpty) return;
    final loaded = <Kost>[];
    for (final id in ids.take(8)) {
      try {
        final k = await ApiService.fetchKostById(id);
        if (k != null) loaded.add(k);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _recentlyViewedKosts = loaded);
  }

  Future<void> _recordRecentlyViewed(Kost kost) async {
    final next = [
      kost,
      ..._recentlyViewedKosts.where((k) => k.id != kost.id),
    ].take(8).toList();
    if (mounted) {
      setState(() => _recentlyViewedKosts = next);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentKostIdsPrefsKey,
      next.map((k) => k.id.toString()).toList(),
    );
  }

  Future<void> _toggleFavorite(int id) async {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masuk terlebih dahulu untuk menyimpan favorit.'),
        ),
      );
      return;
    }
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
        if (_selectedTabIndex == 1) {
          _seenFavoriteIds.add(id);
        }
      } else {
        _favoriteKosts.removeWhere((k) => k.id == id);
        _seenFavoriteIds.remove(id);
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
          if (_selectedTabIndex == 1) {
            _seenFavoriteIds.add(id);
          }
        } else {
          _favoriteKosts.removeWhere((k) => k.id == id);
          _seenFavoriteIds.remove(id);
        }
      });
      await _persistSeenFavorites();
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
          if (_selectedTabIndex == 1) {
            _seenFavoriteIds.add(id);
          }
        } else if (!wasFav) {
          _favoriteKosts.removeWhere((k) => k.id == id);
          _seenFavoriteIds.remove(id);
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
    _recordRecentlyViewed(kost);
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

  Future<void> _showCreateKostSheet() async {
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

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPropertyWizardScreen(currentUser: currentUser),
      ),
    );
    if (created == true && mounted) {
      await _loadKosts();
    }
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
            if (idx == 1) {
              _markFavoritesSeen();
              _loadDynamicFilters();
            }
            if (idx == 2) {
              _markBookingsSeen();
              _loadBookings();
            }
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
              isLabelVisible: _unseenFavoriteCount > 0,
              label: Text('$_unseenFavoriteCount'),
              child: const Icon(Icons.favorite_border_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unseenFavoriteCount > 0,
              label: Text('$_unseenFavoriteCount'),
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
              isLabelVisible: _unseenBookingCount > 0,
              label: Text('$_unseenBookingCount'),
              child: const Icon(Icons.event_available_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unseenBookingCount > 0,
              label: Text('$_unseenBookingCount'),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            label: 'Survei',
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
    final isDaily = _stayDurationMode == 'HUNIAN_HARIAN';
    final double minSlider = isDaily ? 100000 : 500000;
    final double maxSlider = isDaily ? 5000000 : 6000000;
    final int divisions = isDaily ? 49 : 22;

    RangeValues priceRange = RangeValues(
      (_minPrice ?? minSlider.round()).toDouble().clamp(minSlider, maxSlider),
      (_maxPrice ?? maxSlider.round()).toDouble().clamp(minSlider, maxSlider),
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
                'Rentang Harga / ${isDaily ? 'Malam' : 'Bulan'}: ${formatRupiah(priceRange.start.round())} - ${formatRupiah(priceRange.end.round())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              RangeSlider(
                values: priceRange,
                min: minSlider,
                max: maxSlider,
                divisions: divisions,
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
                      _minPrice = priceRange.start.round() > minSlider.round()
                          ? priceRange.start.round()
                          : null;
                      _maxPrice = priceRange.end.round() < maxSlider.round()
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
        (_stayDurationMode == 'LONG_TERM'
            ? _selectedCategory != 'LONG_TERM'
            : _selectedDailySubType != 'Semua') ||
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
                    onSubmitted: (val) {
                      _saveSearchHistory(val);
                      _loadKosts();
                    },
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
                              onPressed: () {
                                _saveSearchHistory(_searchCtrl.text);
                                _loadKosts();
                              },
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
          if (_searchHistory.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Pencarian Terakhir',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _clearSearchHistory,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Hapus Semua',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _searchHistory.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final term = _searchHistory[idx];
                  return InputChip(
                    label: Text(
                      term,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: const Color(0xFFF3F6F9),
                    side: const BorderSide(color: Color(0xFFE5EAF0)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    deleteIcon: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    onDeleted: () => _removeSearchHistoryItem(term),
                    onPressed: () {
                      _searchCtrl.text = term;
                      _searchCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: term.length),
                      );
                      _saveSearchHistory(term);
                      _loadKosts();
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),

          // 2-Mode Segmented Switch: Jangka Panjang vs Hunian Harian
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_stayDurationMode == 'LONG_TERM') return;
                      setState(() {
                        _stayDurationMode = 'LONG_TERM';
                        _selectedCategory = 'LONG_TERM';
                        _selectedDailySubType = 'Semua';
                      });
                      _loadKosts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _stayDurationMode == 'LONG_TERM'
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _stayDurationMode == 'LONG_TERM'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: _stayDurationMode == 'LONG_TERM'
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Jangka Panjang',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _stayDurationMode == 'LONG_TERM'
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _stayDurationMode == 'LONG_TERM'
                                  ? AppColors.primaryGreen
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_stayDurationMode == 'HUNIAN_HARIAN') return;
                      setState(() {
                        _stayDurationMode = 'HUNIAN_HARIAN';
                        _selectedCategory = 'HUNIAN_HARIAN';
                        _selectedType = 'Semua';
                      });
                      _loadKosts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _stayDurationMode == 'HUNIAN_HARIAN'
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _stayDurationMode == 'HUNIAN_HARIAN'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.villa_rounded,
                            size: 15,
                            color: _stayDurationMode == 'HUNIAN_HARIAN'
                                ? const Color(0xFF0369A1)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Hunian Harian',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _stayDurationMode == 'HUNIAN_HARIAN'
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _stayDurationMode == 'HUNIAN_HARIAN'
                                  ? const Color(0xFF0369A1)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category / Sub-Type Strip
          SizedBox(
            height: 36,
            child: _stayDurationMode == 'LONG_TERM'
                ? ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      ('LONG_TERM', 'Semua', Icons.apps_rounded),
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
                            color:
                                selected ? Colors.white : AppColors.primaryGreen,
                          ),
                          label: Text(label),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: AppColors.primaryGreen,
                          backgroundColor:
                              AppColors.lightGreenBg.withOpacity(0.55),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryGreen
                                : AppColors.primaryGreen.withOpacity(0.2),
                          ),
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color:
                                selected ? Colors.white : AppColors.darkGreen,
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
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      ('Semua', 'Semua Harian', Icons.apps_rounded),
                      ('Villa', 'Villa', Icons.villa_rounded),
                      ('Homestay', 'Homestay', Icons.cottage_rounded),
                    ].map((item) {
                      final code = item.$1;
                      final label = item.$2;
                      final icon = item.$3;
                      final selected = _selectedDailySubType == code;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF0369A1),
                          ),
                          label: Text(label),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: const Color(0xFF0369A1),
                          backgroundColor: const Color(0xFFE0F2FE),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF0369A1)
                                : const Color(0xFFBAE6FD),
                          ),
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF0C4A6E),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedDailySubType = code);
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
                          _selectedCategory = _stayDurationMode == 'HUNIAN_HARIAN'
                              ? 'HUNIAN_HARIAN'
                              : 'LONG_TERM';
                          _selectedDailySubType = 'Semua';
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
                // Gender Type Segmented Pills (hanya untuk hunian jangka panjang)
                if (_stayDurationMode != 'HUNIAN_HARIAN')
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
          else ...[
            if (_recentlyViewedKosts.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 16,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Baru Saja Dilihat',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentlyViewedKosts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final rk = _recentlyViewedKosts[idx];
                          return InkWell(
                            onTap: () => _openKostDetail(rk),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 210,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: rk.images.isNotEmpty
                                        ? Image.network(
                                            rk.images.first,
                                            width: 64,
                                            height: 92,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 64,
                                              height: 92,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.bed_outlined,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 64,
                                            height: 92,
                                            color: Colors.grey.shade200,
                                            child:
                                                const Icon(Icons.bed_outlined),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          rk.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          rk.city,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatRupiah(rk.pricePerMonth),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
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
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
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

    final query = _favSearchCtrl.text.trim().toLowerCase();
    final filteredFavs = query.isEmpty
        ? favKosts
        : favKosts.where((k) {
            return k.name.toLowerCase().contains(query) ||
                k.city.toLowerCase().contains(query) ||
                k.district.toLowerCase().contains(query) ||
                k.address.toLowerCase().contains(query) ||
                k.type.toLowerCase().contains(query) ||
                k.propertyCategory.toLowerCase().contains(query) ||
                k.nearbyLandmark.toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5EAF0)),
                      ),
                      child: TextField(
                        controller: _favSearchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Cari di daftar favorit (nama, area, tipe)...',
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
                          suffixIcon: _favSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _favSearchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon:
                                      const Icon(Icons.close_rounded, size: 18),
                                )
                              : null,
                          filled: false,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  if (favKosts.length >= 2) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _compareMode
                            ? Colors.white
                            : AppColors.primaryGreen,
                        backgroundColor: _compareMode
                            ? AppColors.primaryGreen
                            : Colors.white,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _compareMode = !_compareMode;
                          if (!_compareMode) _compareIds.clear();
                        });
                      },
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: Text(
                        _compareMode ? 'Batal' : 'Bandingkan',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_compareMode) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pilih 2–3 properti (${_compareIds.length}/3 dipilih)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                      ),
                      onPressed: _compareIds.length >= 2
                          ? () {
                              final selected = favKosts
                                  .where((k) => _compareIds.contains(k.id))
                                  .toList();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CompareKostsScreen(kosts: selected),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        'Bandingkan (${_compareIds.length})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filteredFavs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Favorit tidak ditemukan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tidak ada properti favorit yang cocok dengan "${_favSearchCtrl.text.trim()}".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            _favSearchCtrl.clear();
                            setState(() {});
                          },
                          child: const Text('Reset Pencarian'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredFavs.length,
                  itemBuilder: (context, idx) {
                    final kost = filteredFavs[idx];
                    final selectedForCompare = _compareIds.contains(kost.id);
                    return Stack(
                      children: [
                        KostCard(
                          kost: kost,
                          isFavorite: true,
                          onTap: _compareMode
                              ? () {
                                  setState(() {
                                    if (selectedForCompare) {
                                      _compareIds.remove(kost.id);
                                    } else if (_compareIds.length < 3) {
                                      _compareIds.add(kost.id);
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Maksimal 3 properti untuk dibandingkan.',
                                          ),
                                        ),
                                      );
                                    }
                                  });
                                }
                              : () => _openKostDetail(kost),
                          onToggleFavorite: () => _toggleFavorite(kost.id),
                        ),
                        if (_compareMode)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Material(
                              color: selectedForCompare
                                  ? AppColors.primaryGreen
                                  : Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  selectedForCompare
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 18,
                                  color: selectedForCompare
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookingTimeline(String status) {
    final s = status.toUpperCase();
    int step = 0;
    if (s == 'DISETUJUI' || s == 'APPROVED' || s == 'AKTIF') step = 1;
    if (s == 'SELESAI') step = 2;

    const labels = ['Terkirim', 'Dikonfirmasi', 'Selesai'];
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 14),
              color: done ? AppColors.primaryGreen : Colors.grey.shade300,
            ),
          );
        }
        final idx = i ~/ 2;
        final active = idx <= step;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryGreen : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.circle,
                size: active ? 12 : 6,
                color: active ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[idx],
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.darkGreen : Colors.grey.shade500,
              ),
            ),
          ],
        );
      }),
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
                'Masuk untuk Melihat Jadwal Survei',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Silakan masuk di tab Profil agar riwayat survei Anda tampil sesuai akun.',
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
              Icons.event_available_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum Ada Jadwal Survei',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih properti dan klik "Ajukan Survei" untuk menjadwalkan kunjungan.',
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
                          'Tanggal: ${b.startDate}',
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
                    'Pengaju: ${b.tenantName} (${b.tenantPhone})',
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
                  if (b.status != 'DIBATALKAN' && b.status != 'DITOLAK') ...[
                    const SizedBox(height: 10),
                    _buildBookingTimeline(b.status),
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
                              'Jadwal Survei: ${b.surveyDateTime.isNotEmpty ? b.surveyDateTime : b.startDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Kesepakatan & transaksi diselesaikan langsung dengan pemilik di luar aplikasi',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  if (b.status == 'DISETUJUI' ||
                      b.status == 'APPROVED' ||
                      b.status == 'AKTIF') ...[
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
