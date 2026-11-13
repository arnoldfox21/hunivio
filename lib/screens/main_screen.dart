import 'package:flutter/material.dart';
import '../models/kost.dart';
import '../models/booking.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../widgets/kost_card.dart';
import 'auth_profile_tab.dart';
import 'kost_detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedTabIndex = 0;

  // Filters
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCity = 'Semua Kota';
  String _selectedType = 'Semua';
  String? _selectedFacility;
  String _sortBy = 'recommended';

  // Data (Dynamic from PostgreSQL DB)
  List<Kost> _kosts = [];
  List<Kost> _favoriteKosts = [];
  List<Booking> _bookings = [];
  bool _loadingKosts = true;
  bool _loadingBookings = false;
  String? _errorMsg;

  List<String> _cities = ['Semua Kota'];
  List<String> _kostTypes = ['Semua'];
  List<String> _facilityChips = [];

  @override
  void initState() {
    super.initState();
    AuthService.restoreSilentSession();
    _loadDynamicFilters();
    _loadKosts();
    _loadBookings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicFilters() async {
    final filters = await ApiService.fetchFilters();
    final allKosts = await ApiService.fetchKosts();
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

      _favoriteKosts = allKosts.where((k) => k.isFavorite).toList();
    });
  }

  Future<void> _loadKosts() async {
    setState(() {
      _loadingKosts = true;
      _errorMsg = null;
    });
    try {
      final result = await ApiService.fetchKosts(
        search: _searchCtrl.text,
        type: _selectedType,
        city: _selectedCity,
        facility: _selectedFacility,
        sortBy: _sortBy,
      );
      if (mounted) {
        setState(() {
          _kosts = result;
          _loadingKosts = false;
        });
      }
      _loadDynamicFilters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _loadingKosts = false;
        });
      }
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final list = await ApiService.fetchBookings();
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
    try {
      await ApiService.toggleFavorite(id);
      await _loadKosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Gagal mengubah status favorit: $e'),
        ),
      );
    }
  }

  bool _isFavorite(int id) {
    return _favoriteKosts.any((k) => k.id == id) ||
        _kosts.any((k) => k.id == id && k.isFavorite);
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
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final districtCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final landmarkCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final roomsCtrl = TextEditingController(text: '5');
    final roomSizeCtrl = TextEditingController(text: '3 x 4 m');
    final ownerNameCtrl = TextEditingController();
    final ownerPhoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final facilitiesCtrl = TextEditingController();
    final publicFacilitiesCtrl = TextEditingController();
    final rulesCtrl = TextEditingController();
    String selectedType = 'Campur';
    bool electricityIncluded = false;
    bool isSinggahsini = true;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                          'Tambah Data Kost ke Database',
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
                      labelText: 'Nama Kost',
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
                            labelText: 'Tipe Kost',
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
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kota',
                            hintText: 'Misal: Bandung',
                            border: OutlineInputBorder(),
                          ),
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
                        child: TextFormField(
                          controller: districtCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Kecamatan / Area',
                            border: OutlineInputBorder(),
                          ),
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
                  TextFormField(
                    controller: facilitiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fasilitas Kamar (pisahkan dengan koma)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: publicFacilitiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fasilitas Umum (pisahkan dengan koma)',
                      border: OutlineInputBorder(),
                    ),
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
                    controller: imageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL Foto Kost',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                    title: const Text('Badge HuniGo Pilihan'),
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
                                final facilities = facilitiesCtrl.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                final publicFacilities = publicFacilitiesCtrl
                                    .text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                final rules = rulesCtrl.text
                                    .split(',')
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                final rooms =
                                    int.tryParse(roomsCtrl.text.trim()) ?? 1;
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
                                  'images': imageCtrl.text.trim().isNotEmpty
                                      ? [imageCtrl.text.trim()]
                                      : [],
                                  'ownerName': ownerNameCtrl.text.trim(),
                                  'ownerPhone': ownerPhoneCtrl.text.trim(),
                                });
                                if (!mounted) return;
                                navigator.pop();
                                await _loadKosts();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.primaryGreen,
                                    content: Text(
                                      'Kost baru berhasil disimpan ke PostgreSQL!',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setModalState(() => submitting = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade700,
                                    content: Text('Gagal menyimpan kost: $e'),
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
                              'Simpan ke Database',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HuniGo',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    color: AppColors.primaryGreen,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Cari & Sewa Kost Impian Mudah',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Data Kost ke DB',
            onPressed: _showCreateKostSheet,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primaryGreen,
            ),
          ),
          ValueListenableBuilder<UserProfile?>(
            valueListenable: AuthService.currentUserNotifier,
            builder: (context, user, _) {
              return IconButton(
                tooltip: user != null
                    ? 'Akun: ${user.name}'
                    : 'Masuk / Daftar via Google',
                onPressed: () {
                  setState(() => _selectedTabIndex = 3);
                },
                icon: user != null && user.avatarUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      )
                    : Icon(
                        user != null
                            ? Icons.account_circle_rounded
                            : Icons.account_circle_outlined,
                        color: user != null
                            ? AppColors.primaryGreen
                            : Colors.blueGrey,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedTabIndex = idx);
          if (idx == 1) _loadDynamicFilters();
          if (idx == 2) _loadBookings();
        },
        backgroundColor: Colors.white,
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
    );
  }

  Widget _buildExploreTab() {
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadKosts,
      child: CustomScrollView(
        slivers: [
          // Top Search & Filter Panel
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _loadKosts(),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama kost, kampus, atau area...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadKosts();
                              },
                              icon: const Icon(Icons.clear, size: 18),
                            )
                          : IconButton(
                              onPressed: _loadKosts,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // City Horizontal Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cities.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final city = _cities[idx];
                        final selected = _selectedCity == city;
                        return ChoiceChip(
                          label: Text(city),
                          selected: selected,
                          selectedColor: AppColors.primaryGreen,
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
                  const SizedBox(height: 10),

                  // Kost Type + Facility + Sort Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
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
                              selectedColor: AppColors.lightGreenBg,
                              checkmarkColor: AppColors.primaryGreen,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.darkGreen
                                    : Colors.grey.shade800,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedType = type);
                                _loadKosts();
                              },
                            ),
                          );
                        }),
                        const SizedBox(width: 4),
                        // Facility chips
                        ..._facilityChips.map((fac) {
                          final isSelected = _selectedFacility == fac;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(fac),
                              selected: isSelected,
                              selectedColor: AppColors.lightGreenBg,
                              checkmarkColor: AppColors.primaryGreen,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.darkGreen
                                    : Colors.grey.shade700,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
            ),
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
                      Text(
                        'Ditemukan ${_kosts.length} kost tersedia',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
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
                        'Belum Terhubung ke Server NestJS API',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pastikan server NestJS (hunigo-api) sudah berjalan di ${ApiService.baseUrl}.\n\nDetail: $_errorMsg',
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
                    final kost = _kosts[index];
                    return KostCard(
                      kost: kost,
                      isFavorite: _isFavorite(kost.id),
                      onTap: () => _openKostDetail(kost),
                      onToggleFavorite: () => _toggleFavorite(kost.id),
                    );
                  },
                  childCount: _kosts.length,
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada Kost Favorit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Tekan ikon hati pada daftar kost untuk menyimpan.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
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
                          color: AppColors.lightGreenBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b.status,
                          style: const TextStyle(
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        'Mulai: ${b.startDate} (${b.durationMonths} bln)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        formatRupiah(b.totalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primaryGreen,
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
