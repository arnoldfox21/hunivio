import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../widgets/animated_vectors.dart';
import '../widgets/location_autocomplete_field.dart';

class OnboardingWizardScreen extends StatefulWidget {
  final UserProfile user;

  const OnboardingWizardScreen({super.key, required this.user});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int _currentStep = 0;
  String _selectedRole = 'PENYEWA';
  String _selectedCategory = 'Kost';
  bool _submitting = false;

  static const _primaryGreen = Color(0xFF1BAA56);

  static const List<({String id, String title, String desc, IconData icon})>
      _categories = [
    (
      id: 'Kost',
      title: 'Kost',
      desc: 'Kamar kost harian, bulanan, atau tahunan (Putra/Putri/Campur)',
      icon: Icons.bed_rounded,
    ),
    (
      id: 'Kontrakan',
      title: 'Kontrakan / Rumah',
      desc: 'Rumah petak, paviliun, atau rumah tapak keluarga',
      icon: Icons.home_work_rounded,
    ),
    (
      id: 'Apartemen',
      title: 'Apartemen',
      desc: 'Unit studio, 1BR, hingga 2BR+ siap huni atau furnished',
      icon: Icons.apartment_rounded,
    ),
    (
      id: 'Hunian Harian',
      title: 'Villa & Homestay',
      desc: 'Penginapan harian atau staycation nyaman untuk liburan & keluarga',
      icon: Icons.villa_rounded,
    ),
    (
      id: 'Semua',
      title: 'Semua Jenis Hunian',
      desc: 'Tertarik atau mengelola lebih dari satu jenis properti',
      icon: Icons.grid_view_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cityController.text = widget.user.city;
    _phoneController.text = widget.user.phone;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await AuthService.completeOnboarding(
        role: _selectedRole,
        preferredCategory: _selectedCategory,
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _selectedRole == 'PEMILIK_KOST';
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop && _currentStep > 0 && !_submitting) {
          _goToStep(_currentStep - 1);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.black87),
                  onPressed:
                      _submitting ? null : () => _goToStep(_currentStep - 1),
                )
              : null,
          automaticallyImplyLeading: false,
          title: Text(
            'Langkah ${_currentStep + 1} dari 3',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    color: _primaryGreen,
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepRole(),
                    _buildStepCategory(isOwner: isOwner),
                    _buildStepDetails(isOwner: isOwner),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRole() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          'Selamat datang, ${widget.user.name.split(' ').first}!',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Anda ingin menggunakan Hunivio sebagai apa?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilihan ini menentukan tampilan menu dan fitur yang sesuai kebutuhan Anda.',
          style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 24),
        _RoleOptionCard(
          selected: _selectedRole == 'PENYEWA',
          icon: Icons.person_search_rounded,
          title: 'Penyewa / Pencari Hunian',
          subtitle:
              'Cari kost, kontrakan, atau apartemen, simpan favorit, dan chat langsung dengan pemilik.',
          badge: 'Cari Hunian',
          onTap: () => setState(() => _selectedRole = 'PENYEWA'),
        ),
        const SizedBox(height: 14),
        _RoleOptionCard(
          selected: _selectedRole == 'PEMILIK_KOST',
          icon: Icons.storefront_rounded,
          title: 'Pemilik Properti',
          subtitle:
              'Pasang iklan properti, kelola ketersediaan kamar, dan terima pengajuan sewa.',
          badge: 'Kelola Properti',
          onTap: () => setState(() => _selectedRole = 'PEMILIK_KOST'),
        ),
      ],
    );
  }

  Widget _buildStepCategory({required bool isOwner}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          isOwner ? 'Fokus Properti Anda' : 'Preferensi Hunian',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isOwner
              ? 'Jenis properti apa yang Anda kelola?'
              : 'Hunian apa yang sedang Anda cari?',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isOwner
              ? 'Kami akan menyiapkan template dan alur pengelolaan properti yang sesuai.'
              : 'Kami akan memprioritaskan rekomendasi properti yang paling relevan untuk Anda.',
          style: const TextStyle(
            fontSize: 13.5,
            color: Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        ..._categories.map((cat) {
          final isSelected = _selectedCategory == cat.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BouncyTap(
              onTap: () => setState(() => _selectedCategory = cat.id),
              pressedScale: 0.97,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryGreen.withOpacity(0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? _primaryGreen : Colors.grey.shade200,
                    width: isSelected ? 1.8 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryGreen
                            : _primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        cat.icon,
                        color: isSelected ? Colors.white : _primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cat.desc,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? _primaryGreen : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepDetails({required bool isOwner}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        const Text(
          'Hampir Selesai',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lengkapi info singkat Anda',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bersifat opsional dan bisa diubah kapan saja di halaman Edit Profil.',
          style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primaryGreen.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaryGreen.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(
                isOwner
                    ? Icons.storefront_rounded
                    : Icons.person_search_rounded,
                color: _primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${isOwner ? "Pemilik Properti" : "Penyewa"} • $_selectedCategory',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LocationAutocompleteField(
          controller: _cityController,
          type: LocationAutocompleteType.city,
          labelText: isOwner ? 'Kota Lokasi Properti' : 'Kota Tujuan / Domisili',
          hintText: 'Contoh: Jakarta Selatan, Kota Bandung, Kota Malang',
          prefixIcon: const Icon(Icons.location_city_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Nomor WhatsApp (Opsional)',
            hintText: 'Contoh: 081234567890',
            prefixIcon: const Icon(Icons.phone_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _submitting
              ? null
              : () {
                  if (isLastStep) {
                    _submit();
                  } else {
                    _goToStep(_currentStep + 1);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isLastStep ? 'Selesai & Mulai' : 'Lanjutkan',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  static const _primaryGreen = Color(0xFF1BAA56);

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? _primaryGreen.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _primaryGreen : Colors.grey.shade200,
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? _primaryGreen
                    : _primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : _primaryGreen,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? _primaryGreen : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? _primaryGreen.withOpacity(0.14)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? _primaryGreen : Colors.black54,
                      ),
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
