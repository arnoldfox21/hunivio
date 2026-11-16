import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/mapbox_service.dart';
import '../utils/formatters.dart';
import '../widgets/facility_checkbox_group.dart';
import '../widgets/location_autocomplete_field.dart';
import 'kost_location_picker_screen.dart';
import 'owner_wallet_screen.dart';

class AddPropertyWizardScreen extends StatefulWidget {
  final UserProfile currentUser;

  const AddPropertyWizardScreen({super.key, required this.currentUser});

  @override
  State<AddPropertyWizardScreen> createState() =>
      _AddPropertyWizardScreenState();
}

class _AddPropertyWizardScreenState extends State<AddPropertyWizardScreen> {
  static const int _totalSteps = 4;

  final List<GlobalKey<FormState>> _stepFormKeys = List.generate(
    _totalSteps,
    (_) => GlobalKey<FormState>(),
  );

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _roomsCtrl = TextEditingController(text: '5');
  final TextEditingController _roomSizeCtrl = TextEditingController(
    text: '3 x 4 m',
  );
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _districtCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _landmarkCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _rulesCtrl = TextEditingController();
  final TextEditingController _imageCtrl = TextEditingController();
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _ownerPhoneCtrl;

  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _pickedImages = [];
  final List<String> _imageUrls = [];

  List<String> _masterRoomFacilities =
      List.from(ApiService.defaultRoomFacilities);
  List<String> _masterPublicFacilities =
      List.from(ApiService.defaultPublicFacilities);
  final Set<String> _selectedRoomFacilities = {};
  final Set<String> _selectedPublicFacilities = {};

  int _currentStep = 0;
  String _selectedCategory = 'KOST';
  String _selectedDailyUnitType = 'Villa';
  String _selectedType = 'Campur';
  bool _electricityIncluded = false;
  bool _submitting = false;
  bool _loadingCurrentGps = false;
  bool _loadingAddress = false;
  LatLng? _pickedLocation;

  static const List<({
    String code,
    String title,
    String subtitle,
    IconData icon,
  })> _categoryOptions = [
    (
      code: 'KOST',
      title: 'Kost',
      subtitle: 'Sewa bulanan / tahunan',
      icon: Icons.bed_rounded,
    ),
    (
      code: 'APARTEMEN',
      title: 'Apartemen',
      subtitle: 'Unit studio / 1BR / 2BR',
      icon: Icons.apartment_rounded,
    ),
    (
      code: 'KONTRAKAN',
      title: 'Kontrakan',
      subtitle: 'Rumah petak / keluarga',
      icon: Icons.home_rounded,
    ),
    (
      code: 'HUNIAN_HARIAN',
      title: 'Hunian Harian',
      subtitle: 'Villa & Homestay / malam',
      icon: Icons.villa_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ownerNameCtrl = TextEditingController(text: widget.currentUser.name);
    _ownerPhoneCtrl = TextEditingController(text: widget.currentUser.phone);
    _loadMasterFacilities();
  }

  Future<void> _loadMasterFacilities() async {
    try {
      final data = await ApiService.fetchMasterFacilities();
      if (!mounted) return;
      setState(() {
        _masterRoomFacilities = data['room'] ?? _masterRoomFacilities;
        _masterPublicFacilities = data['public'] ?? _masterPublicFacilities;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _roomsCtrl.dispose();
    _roomSizeCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _descCtrl.dispose();
    _rulesCtrl.dispose();
    _imageCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    super.dispose();
  }

  bool get _isDailyStay => _selectedCategory == 'HUNIAN_HARIAN';

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Kategori & Tarif';
      case 1:
        return 'Lokasi & Titik Peta';
      case 2:
        return 'Foto, Fasilitas & Deskripsi';
      default:
        return 'Kontak & Tinjauan Akhir';
    }
  }

  Future<void> _applyPinLocation(LatLng point) async {
    setState(() {
      _pickedLocation = point;
      _loadingAddress = true;
    });
    try {
      final geo = await LocationHelper.reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _loadingAddress = false;
        if (geo != null) {
          if (geo.city.isNotEmpty) _cityCtrl.text = geo.city;
          if (geo.district.isNotEmpty) _districtCtrl.text = geo.district;
          if (geo.address.isNotEmpty) _addressCtrl.text = geo.address;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _nextStep() {
    final form = _stepFormKeys[_currentStep].currentState;
    if (form != null && !form.validate()) {
      return;
    }

    if (_currentStep == 2) {
      final hasTypedUrl = _imageCtrl.text.trim().isNotEmpty;
      if (_pickedImages.isEmpty && _imageUrls.isEmpty && !hasTypedUrl) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: const Text(
              'Tambahkan minimal 1 foto properti agar lebih menarik bagi calon penyewa.',
            ),
          ),
        );
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitProperty();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _submitProperty() async {
    final form = _stepFormKeys[3].currentState;
    if (form != null && !form.validate()) return;

    setState(() => _submitting = true);
    try {
      List<String> splitCsv(String raw) => raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final parsedPrice = int.parse(_priceCtrl.text.trim());
      final rooms = int.tryParse(_roomsCtrl.text.trim()) ?? 1;
      final List<String> finalImages = [..._imageUrls];
      final typedUrl = _imageCtrl.text.trim();
      if (typedUrl.isNotEmpty && !finalImages.contains(typedUrl)) {
        finalImages.add(typedUrl);
      }
      for (final picked in _pickedImages) {
        final uploadedUrl = await ApiService.uploadKostImage(File(picked.path));
        finalImages.add(uploadedUrl);
      }

      await ApiService.createKost({
        'propertyCategory': _selectedCategory,
        if (_isDailyStay) 'unitType': _selectedDailyUnitType,
        'name': _nameCtrl.text.trim(),
        'type': _isDailyStay ? 'Campur' : _selectedType,
        'city': _cityCtrl.text.trim(),
        'district': _districtCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'nearbyLandmark': _landmarkCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'pricePerMonth': _isDailyStay ? 0 : parsedPrice,
        if (_isDailyStay) 'pricePerDay': parsedPrice,
        'availableRooms': rooms,
        'roomSize': _roomSizeCtrl.text.trim(),
        'electricityIncluded': _isDailyStay ? true : _electricityIncluded,
        'isSinggahsini': false,
        'isInstantBooking': true,
        'roomFacilities': _selectedRoomFacilities.toList(),
        'publicFacilities': _selectedPublicFacilities.toList(),
        'rules': splitCsv(_rulesCtrl.text),
        'images': finalImages,
        'ownerName': _ownerNameCtrl.text.trim(),
        'ownerPhone': _ownerPhoneCtrl.text.trim(),
        'ownerId': widget.currentUser.id,
        if (_pickedLocation != null) 'latitude': _pickedLocation!.latitude,
        if (_pickedLocation != null) 'longitude': _pickedLocation!.longitude,
      });

      if (!mounted) return;
      final autoApproved = widget.currentUser.canApproveProperties;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              autoApproved ? AppColors.primaryGreen : const Color(0xFFD97706),
          content: Text(
            autoApproved
                ? 'Properti baru berhasil ditambahkan & langsung disetujui!'
                : 'Properti berhasil diajukan! Menunggu persetujuan Administrator/Staff.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      final isCreditShortage = msg.toLowerCase().contains('saldo kredit');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(isCreditShortage ? msg : 'Gagal menyimpan properti: $msg'),
          action: isCreditShortage
              ? SnackBarAction(
                  label: 'Top-Up',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            OwnerWalletScreen(user: widget.currentUser),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    }
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.darkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1CategoryAndPrice() {
    return Form(
      key: _stepFormKeys[0],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          _buildGuideCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Panduan Langkah 1',
            description:
                'Pilih kategori yang sesuai agar properti tampil di tab yang tepat. Untuk Villa atau Homestay harian, gunakan kategori Hunian Harian dengan tarif per malam.',
          ),
          const Text(
            'Pilih Kategori Properti',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: _categoryOptions.map((cat) {
              final selected = _selectedCategory == cat.code;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedCategory = cat.code),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.lightGreenBg : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryGreen
                          : const Color(0xFFE2E8F0),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat.icon,
                        size: 20,
                        color: selected
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: selected
                                    ? AppColors.darkGreen
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              cat.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
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
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (_isDailyStay) ...[
            const Text(
              'Jenis Hunian Harian',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Villa', 'Homestay'].map((sub) {
                final selected = _selectedDailyUnitType == sub;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: sub == 'Villa' ? 8 : 0),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(sub, textAlign: TextAlign.center),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: const Color(0xFF0369A1),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedDailyUnitType = sub),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const Text(
              'Tipe Penghuni',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Putri', 'Putra', 'Campur'].map((t) {
                final selected = _selectedType == t;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t != 'Campur' ? 8 : 0),
                    child: ChoiceChip(
                      label: SizedBox(
                        width: double.infinity,
                        child: Text(t, textAlign: TextAlign.center),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _selectedType = t),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Properti',
              hintText: _isDailyStay
                  ? 'Contoh: Villa Puncak Dieng / Homestay Ijen'
                  : 'Contoh: Kost Griya Melati Suhat',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Nama properti wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText:
                  _isDailyStay ? 'Harga / Malam (Rp)' : 'Harga / Bulan (Rp)',
              hintText: _isDailyStay ? '350000' : '1500000',
              helperText: _isDailyStay
                  ? 'Masukkan tarif menginap per malam tanpa titik/koma'
                  : 'Masukkan tarif sewa per bulan tanpa titik/koma',
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final val = int.tryParse((v ?? '').trim());
              if (val == null || val <= 0) {
                return 'Masukkan nominal harga yang valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _roomsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        _isDailyStay ? 'Unit / Kamar Tersedia' : 'Sisa Kamar',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      int.tryParse((v ?? '').trim()) == null ? 'Angka' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _roomSizeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ukuran / Luas',
                    hintText: 'Misal: 3 x 4 m',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Location() {
    return Form(
      key: _stepFormKeys[1],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          _buildGuideCard(
            icon: Icons.pin_drop_outlined,
            title: 'Panduan Langkah 2',
            description:
                'Tandai titik lokasi di peta terlebih dahulu untuk mengisi Kota, Kecamatan, dan Alamat secara otomatis, lalu lengkapi patokan terdekat.',
          ),
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
                      color: AppColors.primaryGreen,
                      size: 18,
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
                    if (_pickedLocation != null)
                      GestureDetector(
                        onTap: () => setState(() => _pickedLocation = null),
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
                  _loadingAddress
                      ? 'Mengambil kota, kecamatan, dan alamat otomatis...'
                      : _pickedLocation != null
                          ? 'Koordinat terpilih: ${_pickedLocation!.latitude.toStringAsFixed(6)}, ${_pickedLocation!.longitude.toStringAsFixed(6)}'
                          : 'Tandai di peta agar properti Anda mudah ditemukan di Mode Peta.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _pickedLocation != null
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
                              await Navigator.of(context).push<LatLng>(
                            MaterialPageRoute(
                              builder: (_) => KostLocationPickerScreen(
                                initialLocation: _pickedLocation,
                              ),
                            ),
                          );
                          if (result != null && mounted) {
                            await _applyPinLocation(result);
                          }
                        },
                        icon: const Icon(Icons.map_outlined, size: 17),
                        label: Text(
                          _pickedLocation == null ? 'Pilih Peta' : 'Ubah Peta',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadingCurrentGps
                            ? null
                            : () async {
                                setState(() => _loadingCurrentGps = true);
                                final res =
                                    await LocationHelper.getCurrentLocation();
                                if (!mounted) return;
                                setState(() => _loadingCurrentGps = false);
                                if (res.isUserLocation) {
                                  await _applyPinLocation(res.location);
                                }
                                if (res.message != null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(res.message!)),
                                  );
                                }
                              },
                        icon: _loadingCurrentGps
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 17),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LocationAutocompleteField(
                  controller: _cityCtrl,
                  type: LocationAutocompleteType.city,
                  labelText: 'Kota / Kabupaten',
                  hintText: 'Misal: Kota Malang',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LocationAutocompleteField(
                  controller: _districtCtrl,
                  cityController: _cityCtrl,
                  type: LocationAutocompleteType.district,
                  labelText: 'Kecamatan / Area',
                  hintText: 'Misal: Lowokwaru',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Alamat Lengkap',
              hintText: 'Nama jalan, nomor rumah, RT/RW',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Alamat wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _landmarkCtrl,
            decoration: const InputDecoration(
              labelText: 'Patokan / Kampus Terdekat (opsional)',
              hintText: 'Misal: 5 menit dari UB / Alun-alun',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3PhotosAndFacilities() {
    return Form(
      key: _stepFormKeys[2],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          _buildGuideCard(
            icon: Icons.photo_camera_outlined,
            title: 'Panduan Langkah 3',
            description:
                'Unggah minimal 1 foto properti yang jelas (tampak depan atau interior). Lengkapi juga fasilitas serta deskripsi agar calon penyewa yakin.',
          ),
          const Text(
            'Foto Properti (Minimal 1 Foto)',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final files = await _imagePicker.pickMultiImage(
                            imageQuality: 80,
                            maxWidth: 1280,
                          );
                          if (!mounted) return;
                          if (files.isNotEmpty) {
                            setState(() => _pickedImages.addAll(files));
                          }
                        },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final file = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 80,
                            maxWidth: 1280,
                          );
                          if (!mounted) return;
                          if (file != null) {
                            setState(() => _pickedImages.add(file));
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
                  controller: _imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Atau tambah URL Foto',
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
                onPressed: _submitting
                    ? null
                    : () {
                        final url = _imageCtrl.text.trim();
                        if (url.isNotEmpty && !_imageUrls.contains(url)) {
                          setState(() {
                            _imageUrls.add(url);
                            _imageCtrl.clear();
                          });
                        }
                      },
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (_pickedImages.isNotEmpty || _imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._pickedImages.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(entry.value.path),
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _pickedImages.removeAt(entry.key),
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
                  ..._imageUrls.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              entry.value,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 86,
                                height: 86,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _imageUrls.removeAt(entry.key),
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
          const SizedBox(height: 14),
          FacilityCheckboxGroup(
            title: 'Fasilitas Kamar / Unit',
            options: _masterRoomFacilities,
            selected: _selectedRoomFacilities,
            onToggle: (item) {
              setState(() {
                if (!_selectedRoomFacilities.remove(item)) {
                  _selectedRoomFacilities.add(item);
                }
              });
            },
          ),
          const SizedBox(height: 10),
          FacilityCheckboxGroup(
            title: 'Fasilitas Umum & Lingkungan',
            options: _masterPublicFacilities,
            selected: _selectedPublicFacilities,
            onToggle: (item) {
              setState(() {
                if (!_selectedPublicFacilities.remove(item)) {
                  _selectedPublicFacilities.add(item);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Deskripsi Properti',
              hintText:
                  'Ceritakan keunggulan properti, suasana lingkungan, dan akses sekitar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rulesCtrl,
            decoration: const InputDecoration(
              labelText: 'Peraturan (pisahkan dengan koma, opsional)',
              hintText: 'Contoh: Jam malam 22:00, Dilarang merokok di kamar',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4ContactAndSummary() {
    final parsedPrice = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final photoCount = _pickedImages.length +
        _imageUrls.length +
        (_imageCtrl.text.trim().isNotEmpty ? 1 : 0);
    final facilityCount =
        _selectedRoomFacilities.length + _selectedPublicFacilities.length;
    final categoryLabel = _isDailyStay
        ? '$_selectedDailyUnitType (Hunian Harian)'
        : '${_categoryOptions.firstWhere((e) => e.code == _selectedCategory).title} • $_selectedType';

    return Form(
      key: _stepFormKeys[3],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          _buildGuideCard(
            icon: Icons.verified_outlined,
            title: 'Panduan Langkah 4',
            description:
                'Pastikan nama dan nomor WhatsApp aktif agar calon penyewa dapat menghubungi Anda. Periksa kembali ringkasan properti di bawah sebelum dikirim.',
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ownerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pemilik',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _ownerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. WA Pemilik',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isDailyStay)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryGreen,
              title: const Text('Harga sudah termasuk listrik'),
              value: _electricityIncluded,
              onChanged: (v) => setState(() => _electricityIncluded = v),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Properti',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Divider(height: 18),
                _summaryRow('Nama', _nameCtrl.text.trim()),
                _summaryRow('Kategori', categoryLabel),
                _summaryRow(
                  'Tarif',
                  '${formatRupiah(parsedPrice)} ${_isDailyStay ? '/ malam' : '/ bulan'}',
                ),
                _summaryRow(
                  'Lokasi',
                  '${_districtCtrl.text.trim()}, ${_cityCtrl.text.trim()}',
                ),
                _summaryRow('Alamat', _addressCtrl.text.trim()),
                _summaryRow(
                  'Ketersediaan',
                  '${_roomsCtrl.text.trim()} unit/kamar',
                ),
                _summaryRow('Foto & Fasilitas', '$photoCount foto • $facilityCount fasilitas'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;
    final submitLabel = widget.currentUser.canApproveProperties
        ? 'Publikasikan Properti'
        : 'Ajukan Properti';

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _submitting ? null : _prevStep,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah Properti • Langkah ${_currentStep + 1}/$_totalSteps',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              _stepTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: const Color(0xFFE2E8F0),
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentStep,
        children: [
          _buildStep1CategoryAndPrice(),
          _buildStep2Location(),
          _buildStep3PhotosAndFacilities(),
          _buildStep4ContactAndSummary(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (_currentStep > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _prevStep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == _totalSteps - 1
                              ? submitLabel
                              : 'Lanjut',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
