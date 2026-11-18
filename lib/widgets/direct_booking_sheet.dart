import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/kost.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';

class DirectBookingSheet extends StatefulWidget {
  final Kost kost;
  final VoidCallback onCompleted;

  const DirectBookingSheet({
    super.key,
    required this.kost,
    required this.onCompleted,
  });

  @override
  State<DirectBookingSheet> createState() => _DirectBookingSheetState();
}

class _DirectBookingSheetState extends State<DirectBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  int _durationCount = 1;
  String _paymentScheme = 'FULL';
  bool _usePoints = false;
  bool _showFeeInfo = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _unitPrice => widget.kost.displayPrice;
  String get _unitLabel => widget.kost.isDailyStay
      ? 'hari'
      : widget.kost.isYearlyStay
          ? 'tahun'
          : 'bulan';
  int get _maxDuration => widget.kost.isDailyStay
      ? 30
      : widget.kost.isYearlyStay
          ? 5
          : 12;
  int get _baseTotalAmount => _unitPrice * _durationCount;
  bool get _canUseDp =>
      !widget.kost.isDailyStay &&
      (_durationCount > 1 || widget.kost.isYearlyStay);
  String get _effectiveScheme =>
      (_canUseDp && _paymentScheme == 'DP') ? 'DP' : 'FULL';
  int get _payableRent =>
      _effectiveScheme == 'DP' ? (_baseTotalAmount * 0.3).round() : _baseTotalAmount;
  int get _remainingRent =>
      (_baseTotalAmount - _payableRent).clamp(0, _baseTotalAmount);
  int get _availablePoints => AuthService.currentUser?.pointsBalance ?? 0;

  int get _pointsUsedCount {
    if (!_usePoints || _availablePoints <= 0) return 0;
    final platformFee = (_payableRent * 5 / 100).round();
    final maxDiscount = (platformFee * 0.5).floor();
    final pointCapByPayable = (_payableRent - 1000).clamp(0, _payableRent);
    final allowedDiscount =
        maxDiscount < pointCapByPayable ? maxDiscount : pointCapByPayable;
    final maxPoints = allowedDiscount ~/ 50;
    return _availablePoints < maxPoints ? _availablePoints : maxPoints;
  }

  int get _pointsDiscount => _pointsUsedCount * 50;
  int get _netRentPayNow =>
      (_payableRent - _pointsDiscount).clamp(1000, _payableRent < 1000 ? 1000 : _payableRent);
  int get _totalAmount => _netRentPayNow;
  int get _estimatedEarnedPoints => _netRentPayNow ~/ 10000;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final dateStr =
          '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';

      final booking = await ApiService.createDirectBooking(
        kostId: widget.kost.id,
        tenantName: _nameCtrl.text.trim(),
        tenantPhone: _phoneCtrl.text.trim(),
        startDate: dateStr,
        durationCount: _durationCount,
        notes: _notesCtrl.text.trim(),
        usePoints: _usePoints,
        paymentScheme: _effectiveScheme,
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      final paymentUrl = booking.paymentUrl ?? '';
      if (paymentUrl.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DirectBookingSnapWebViewScreen(
              paymentUrl: paymentUrl,
              title: 'Pembayaran Booking',
            ),
          ),
        );
        if (!mounted) return;
        final synced = await ApiService.syncDirectBookingPayment(booking.id);
        await AuthService.verifyActiveSession();
        if (!mounted) return;
        final isPaid = synced.paymentStatus.toUpperCase() == 'PAID';
        Navigator.of(context).pop();
        widget.onCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                isPaid ? AppColors.primaryGreen : AppColors.warningOrange,
            content: Text(
              isPaid
                  ? 'Booking berhasil dibayar! Dana aman di Escrow Keyloka hingga Anda konfirmasi check-in.'
                  : 'Booking tersimpan (status: ${synced.status}). Anda dapat melanjutkan pembayaran di menu Sewa Saya.',
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
        widget.onCompleted();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.discountRed,
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Langsung & Aman',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.kost.name,
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
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dilindungi Escrow Keyloka: pembayaran ditahan aman dan baru diteruskan ke pemilik setelah Anda konfirmasi check-in.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Penyewa',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp Aktif',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 8) ? 'Nomor tidak valid' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Check-In',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Durasi ($_unitLabel)',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: _durationCount > 1
                                ? () => setState(() => _durationCount--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_durationCount $_unitLabel',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: _durationCount < _maxDuration
                                ? () => setState(() => _durationCount++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan (Opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_canUseDp) ...[
                const SizedBox(height: 12),
                const Text(
                  'Skema Pembayaran',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _submitting
                            ? null
                            : () => setState(() => _paymentScheme = 'FULL'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _effectiveScheme == 'FULL'
                                ? AppColors.primaryGreen.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _effectiveScheme == 'FULL'
                                  ? AppColors.primaryGreen
                                  : AppColors.cardBorder,
                              width: _effectiveScheme == 'FULL' ? 1.5 : 1,
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bayar Penuh (100%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Langsung lunas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _submitting
                            ? null
                            : () => setState(() => _paymentScheme = 'DP'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _effectiveScheme == 'DP'
                                ? AppColors.primaryGreen.withOpacity(0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _effectiveScheme == 'DP'
                                  ? AppColors.primaryGreen
                                  : AppColors.cardBorder,
                              width: _effectiveScheme == 'DP' ? 1.5 : 1,
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DP 30% (Booking Fee)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sisa saat check-in',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_availablePoints > 0) ...[
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryGreen,
                  title: Text(
                    'Gunakan Poin Keyloka ($_availablePoints poin)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _pointsDiscount > 0
                        ? 'Potongan ${formatRupiah(_pointsDiscount)} ($_pointsUsedCount poin)'
                        : '1 poin = Rp50 (maks. 2,5% dari tagihan sewa)',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  value: _usePoints,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _usePoints = v),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal Sewa ($_durationCount $_unitLabel)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          formatRupiah(_baseTotalAmount),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_effectiveScheme == 'DP') ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tagihan DP Sekarang (30%)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            formatRupiah(_payableRent),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sisa Pelunasan (saat Check-In)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            formatRupiah(_remainingRent),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_pointsDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Potongan Poin Loyalti',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '-${formatRupiah(_pointsDiscount)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _showFeeInfo = !_showFeeInfo),
                          child: const Row(
                            children: [
                              Text(
                                'Biaya Layanan & Transaksi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Gratis',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    if (_showFeeInfo) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Text(
                          'Gratis biaya layanan untuk penyewa. Seluruh biaya pemrosesan pembayaran & perlindungan Escrow ditanggung oleh pemilik properti.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _effectiveScheme == 'DP'
                              ? 'Total Bayar DP'
                              : 'Total Bayar Sekarang',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          formatRupiah(_totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    if (_estimatedEarnedPoints > 0) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Bonus setelah check-in: +$_estimatedEarnedPoints Poin',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.primaryGreen,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dilindungi Escrow: Dana ditahan aman dan baru diteruskan ke pemilik setelah Anda konfirmasi Check-In.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.kost.depositAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 15,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Info Deposit Keamanan: ${formatRupiah(widget.kost.depositAmount)} dibayar terpisah saat Check-In dan dikembalikan saat Check-Out jika tidak ada kerusakan.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.bolt_outlined,
                          size: 15,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.kost.electricityIncluded
                                ? 'Listrik: Sudah termasuk dalam harga sewa.'
                                : 'Listrik: Belum termasuk harga sewa (dibayar terpisah sesuai pemakaian/token).',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
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
                          'Bayar & Booking (${formatRupiah(_totalAmount)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
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

class DirectBookingSnapWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String title;

  const DirectBookingSnapWebViewScreen({
    super.key,
    required this.paymentUrl,
    this.title = 'Pembayaran Midtrans',
  });

  @override
  State<DirectBookingSnapWebViewScreen> createState() =>
      _DirectBookingSnapWebViewScreenState();
}

class _DirectBookingSnapWebViewScreenState
    extends State<DirectBookingSnapWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  bool _isFinishRedirectUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if ((host == 'keyloka.app' || host.endsWith('.keyloka.app')) &&
        uri.path.startsWith('/payment/finish')) {
      return true;
    }
    if (host == 'example.com' || host.endsWith('.example.com')) {
      final txStatus =
          (uri.queryParameters['transaction_status'] ?? '').toLowerCase();
      return txStatus == 'settlement' || txStatus == 'capture';
    }
    return false;
  }

  void _closeIfNeeded() {
    if (!mounted || _closed) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isFinishRedirectUrl(request.url)) {
              _closeIfNeeded();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (_isFinishRedirectUrl(url)) {
              _closeIfNeeded();
              return;
            }
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Selesai',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              color: AppColors.primaryGreen,
              minHeight: 3,
            ),
        ],
      ),
    );
  }
}
