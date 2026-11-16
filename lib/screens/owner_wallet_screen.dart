import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/user_profile.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';

class OwnerWalletScreen extends StatefulWidget {
  final UserProfile user;

  const OwnerWalletScreen({super.key, required this.user});

  @override
  State<OwnerWalletScreen> createState() => _OwnerWalletScreenState();
}

class _OwnerWalletScreenState extends State<OwnerWalletScreen> {
  static const List<int> _presetAmounts = [
    25000,
    50000,
    100000,
    250000,
    500000,
  ];

  final TextEditingController _amountController = TextEditingController(
    text: '50000',
  );

  int _selectedPreset = 50000;
  int _creditBalance = 0;
  int _payoutBalance = 0;
  List<WalletTransaction> _transactions = const [];
  List<Map<String, dynamic>> _payoutRequests = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _syncingOrderId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final currentUser = AuthService.currentUserNotifier.value ?? widget.user;
    _creditBalance = currentUser.creditBalance;
    _payoutBalance = currentUser.payoutBalance;
    _loadWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.fetchWalletSummary(),
        ApiService.fetchMyPayoutRequests(),
      ]);
      final summary = results[0] as WalletSummary;
      final payouts = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      final currentUser = AuthService.currentUserNotifier.value ?? widget.user;
      setState(() {
        _creditBalance = summary.creditBalance;
        _payoutBalance = currentUser.payoutBalance;
        _transactions = summary.transactions;
        _payoutRequests = payouts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int _parsedAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Future<void> _startTopup() async {
    final amount = _parsedAmount();
    if (amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.discountRed,
          content: Text('Minimal top-up adalah Rp10.000.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await ApiService.createWalletTopup(amount);
      if (!mounted) return;
      setState(() => _submitting = false);

      await _openSnapPayment(
        paymentUrl: created.paymentUrl,
        orderId: created.transaction.orderId,
      );
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

  Future<void> _openSnapPayment({
    required String paymentUrl,
    required String orderId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MidtransSnapWebViewScreen(
          paymentUrl: paymentUrl,
          orderId: orderId,
        ),
      ),
    );
    if (!mounted) return;
    await _syncOrder(orderId, showFeedback: true);
  }

  Future<void> _syncOrder(String orderId, {bool showFeedback = false}) async {
    setState(() => _syncingOrderId = orderId);
    try {
      final result = await ApiService.syncWalletTopupStatus(orderId);
      await AuthService.verifyActiveSession();
      await _loadWallet();
      if (!mounted) return;
      setState(() => _syncingOrderId = null);

      if (showFeedback) {
        final isPaid = result.transaction.status == 'PAID';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor:
                isPaid ? AppColors.primaryGreen : AppColors.warningOrange,
            content: Text(
              isPaid
                  ? 'Top-up berhasil! Saldo kredit sekarang ${formatRupiah(result.creditBalance)}.'
                  : 'Status pembayaran: ${_statusLabel(result.transaction.status)}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _syncingOrderId = null);
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.discountRed,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Lunas';
      case 'EXPIRED':
        return 'Kedaluwarsa';
      case 'FAILED':
        return 'Gagal';
      default:
        return 'Menunggu Bayar';
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return AppColors.primaryGreen;
      case 'EXPIRED':
      case 'FAILED':
        return AppColors.discountRed;
      default:
        return AppColors.warningOrange;
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Saldo Kredit Pemilik',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadWallet,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadWallet,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 16),
            _buildTopupCard(),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Transaksi Kredit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.discountRed,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _loadWallet,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            else if (_transactions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 36,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada transaksi top-up kredit.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._transactions.map(_buildTransactionTile),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Penarikan Dana',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_payoutRequests.length} ajuan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_loading && _payoutRequests.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 32,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada pengajuan penarikan saldo sewa.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._payoutRequests.map(_buildPayoutRequestTile),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Saldo Kredit Keyloka',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            formatRupiah(_creditBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nilai kredit 1:1 dengan nominal top-up Anda.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pendapatan Sewa (Escrow Cair)',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatRupiah(_payoutBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _openPayoutRequestSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.darkGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Tarik Dana'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopupCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Up Kredit',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih nominal atau masukkan jumlah top-up (min. Rp10.000).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetAmounts.map((nominal) {
              final selected = _selectedPreset == nominal;
              return ChoiceChip(
                label: Text(
                  formatRupiah(nominal),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primaryGreen,
                backgroundColor: AppColors.surfaceBg,
                side: BorderSide(
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.cardBorder,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedPreset = nominal;
                    _amountController.text = nominal.toString();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              final parsed = int.tryParse(val) ?? 0;
              setState(() {
                _selectedPreset = _presetAmounts.contains(parsed) ? parsed : 0;
              });
            },
            decoration: InputDecoration(
              labelText: 'Nominal Top-Up (Rp)',
              prefixText: 'Rp ',
              filled: true,
              fillColor: AppColors.surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.5,
                ),
              ),
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submitting ? null : _startTopup,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Bayar Sekarang (Midtrans)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransaction tx) {
    final isDebit = tx.isDebit;
    final statusColor = isDebit ? AppColors.warningOrange : _statusColor(tx.status);
    final isPending = !isDebit && tx.status.toUpperCase() == 'PENDING';
    final isSyncing = _syncingOrderId == tx.orderId;
    final amountPrefix = isDebit ? '- ' : '+ ';
    final amountColor = isDebit
        ? AppColors.discountRed
        : (tx.status.toUpperCase() == 'PAID'
            ? AppColors.primaryGreen
            : AppColors.textPrimary);
    final badgeText = isDebit
        ? (tx.type.toUpperCase() == 'SLOT_FEE' ? 'Slot Properti' : 'Boost Iklan')
        : _statusLabel(tx.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(
                  '$amountPrefix${formatRupiah(tx.amount)}',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (tx.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tx.description,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            tx.orderId,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(tx.createdAt) +
                (tx.paymentMethod.isNotEmpty
                    ? ' • ${tx.paymentMethod.toUpperCase()}'
                    : ''),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (tx.paymentUrl != null && tx.paymentUrl!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openSnapPayment(
                        paymentUrl: tx.paymentUrl!,
                        orderId: tx.orderId,
                      ),
                      child: const Text(
                        'Lanjutkan Bayar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (tx.paymentUrl != null && tx.paymentUrl!.isNotEmpty)
                  const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceBg,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isSyncing
                        ? null
                        : () => _syncOrder(tx.orderId, showFeedback: true),
                    child: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Cek Status',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPayoutRequestSheet() async {
    if (_payoutBalance < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saldo pendapatan sewa minimal Rp10.000 untuk ditarik.',
          ),
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController(text: _payoutBalance.toString());
    final bankCtrl = TextEditingController();
    final accNumCtrl = TextEditingController();
    final accHolderCtrl = TextEditingController(
      text: (AuthService.currentUserNotifier.value ?? widget.user).name,
    );
    bool saving = false;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> submit() async {
              final rawDigits = amountCtrl.text.replaceAll(
                RegExp(r'[^0-9]'),
                '',
              );
              final amount = int.tryParse(rawDigits) ?? 0;
              final bank = bankCtrl.text.trim();
              final accNum = accNumCtrl.text.trim();
              final holder = accHolderCtrl.text.trim();

              if (amount < 10000) {
                setSheetState(() {
                  formError = 'Minimal penarikan adalah Rp10.000.';
                });
                return;
              }
              if (amount > _payoutBalance) {
                setSheetState(() {
                  formError = 'Nominal melebihi saldo pendapatan sewa Anda.';
                });
                return;
              }
              if (bank.isEmpty || accNum.isEmpty || holder.isEmpty) {
                setSheetState(() {
                  formError = 'Lengkapi nama bank, nomor rekening, dan pemilik.';
                });
                return;
              }

              setSheetState(() {
                saving = true;
                formError = null;
              });

              try {
                final res = await ApiService.createPayoutRequest(
                  amount: amount,
                  bankName: bank,
                  accountNumber: accNum,
                  accountHolder: holder,
                );
                if (!mounted || !sheetContext.mounted) return;
                final updatedBalance =
                    (res['payoutBalance'] as num?)?.toInt() ??
                    (_payoutBalance - amount);
                setState(() {
                  _payoutBalance = updatedBalance;
                });
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pengajuan penarikan dana dikirim. Menunggu proses admin.',
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                _loadWallet();
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  saving = false;
                  formError = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tarik Pendapatan Sewa',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Saldo: ${formatRupiah(_payoutBalance)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal Penarikan (Rp)',
                        hintText: 'Contoh: 500000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Bank / E-Wallet',
                        hintText: 'Contoh: BCA / BRI / Mandiri / GoPay',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accNumCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Rekening / Akun',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: accHolderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pemilik Rekening',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        formError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                                'Ajukan Penarikan Dana',
                                style: TextStyle(fontWeight: FontWeight.w800),
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
    Future.delayed(const Duration(milliseconds: 400), () {
      amountCtrl.dispose();
      bankCtrl.dispose();
      accNumCtrl.dispose();
      accHolderCtrl.dispose();
    });
  }

  Widget _buildPayoutRequestTile(Map<String, dynamic> req) {
    final amount = (req['amount'] as num?)?.toInt() ?? 0;
    final bankName = (req['bankName'] ?? '').toString();
    final accountNumber = (req['accountNumber'] ?? '').toString();
    final accountHolder = (req['accountHolder'] ?? '').toString();
    final status = (req['status'] ?? 'PENDING').toString().toUpperCase();
    final adminNote = (req['adminNote'] ?? '').toString();

    String statusLabel = 'Menunggu';
    Color badgeColor = Colors.orange.shade800;
    Color badgeBg = Colors.orange.shade50;
    if (status == 'APPROVED') {
      statusLabel = 'Disetujui';
      badgeColor = AppColors.primaryGreen;
      badgeBg = AppColors.lightGreenBg;
    } else if (status == 'REJECTED') {
      statusLabel = 'Ditolak';
      badgeColor = Colors.red.shade700;
      badgeBg = Colors.red.shade50;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(
                  formatRupiah(amount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$bankName • $accountNumber ($accountHolder)',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan admin: $adminNote',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MidtransSnapWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const _MidtransSnapWebViewScreen({
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<_MidtransSnapWebViewScreen> createState() =>
      _MidtransSnapWebViewScreenState();
}

class _MidtransSnapWebViewScreenState
    extends State<_MidtransSnapWebViewScreen> {
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
        title: const Text(
          'Pembayaran Midtrans',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
