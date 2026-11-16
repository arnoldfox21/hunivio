class WalletTransaction {
  final int id;
  final int userId;
  final String orderId;
  final int amount;
  final String type;
  final String status;
  final String? snapToken;
  final String? paymentUrl;
  final String paymentMethod;
  final String description;
  final String? paidAt;
  final String createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.amount,
    required this.type,
    required this.status,
    this.snapToken,
    this.paymentUrl,
    this.paymentMethod = '',
    this.description = '',
    this.paidAt,
    required this.createdAt,
  });

  bool get isDebit => type.toUpperCase() != 'TOPUP';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      userId: json['userId'] is int
          ? json['userId'] as int
          : int.tryParse('${json['userId'] ?? 0}') ?? 0,
      orderId: json['orderId']?.toString() ?? '',
      amount: json['amount'] is int
          ? json['amount'] as int
          : int.tryParse('${json['amount'] ?? 0}') ?? 0,
      type: json['type']?.toString() ?? 'TOPUP',
      status: json['status']?.toString() ?? 'PENDING',
      snapToken: json['snapToken']?.toString(),
      paymentUrl: json['paymentUrl']?.toString(),
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      paidAt: json['paidAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class WalletSummary {
  final int creditBalance;
  final List<WalletTransaction> transactions;

  const WalletSummary({
    required this.creditBalance,
    required this.transactions,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    final rawList = json['transactions'] is List
        ? json['transactions'] as List
        : const [];
    return WalletSummary(
      creditBalance: json['creditBalance'] is int
          ? json['creditBalance'] as int
          : int.tryParse('${json['creditBalance'] ?? 0}') ?? 0,
      transactions: rawList
          .whereType<Map>()
          .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CreateTopupResult {
  final WalletTransaction transaction;
  final String snapToken;
  final String paymentUrl;

  const CreateTopupResult({
    required this.transaction,
    required this.snapToken,
    required this.paymentUrl,
  });

  factory CreateTopupResult.fromJson(Map<String, dynamic> json) {
    return CreateTopupResult(
      transaction: WalletTransaction.fromJson(
        Map<String, dynamic>.from(json['transaction'] as Map),
      ),
      snapToken: json['snapToken']?.toString() ?? '',
      paymentUrl: json['paymentUrl']?.toString() ?? '',
    );
  }
}

class SyncTopupResult {
  final WalletTransaction transaction;
  final int creditBalance;

  const SyncTopupResult({
    required this.transaction,
    required this.creditBalance,
  });

  factory SyncTopupResult.fromJson(Map<String, dynamic> json) {
    return SyncTopupResult(
      transaction: WalletTransaction.fromJson(
        Map<String, dynamic>.from(json['transaction'] as Map),
      ),
      creditBalance: json['creditBalance'] is int
          ? json['creditBalance'] as int
          : int.tryParse('${json['creditBalance'] ?? 0}') ?? 0,
    );
  }
}

class BoostPackageOption {
  final String code;
  final String label;
  final int days;
  final int price;

  const BoostPackageOption({
    required this.code,
    required this.label,
    required this.days,
    required this.price,
  });

  factory BoostPackageOption.fromJson(Map<String, dynamic> json) {
    return BoostPackageOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      days: json['days'] is int
          ? json['days'] as int
          : int.tryParse('${json['days'] ?? 0}') ?? 0,
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse('${json['price'] ?? 0}') ?? 0,
    );
  }
}

class WalletPricing {
  final int freePropertyQuota;
  final int extraPropertySlotFee;
  final List<BoostPackageOption> boostPackages;

  const WalletPricing({
    required this.freePropertyQuota,
    required this.extraPropertySlotFee,
    required this.boostPackages,
  });

  factory WalletPricing.fromJson(Map<String, dynamic> json) {
    final rawList = (json['boostPackages'] as List?) ?? const [];
    return WalletPricing(
      freePropertyQuota: json['freePropertyQuota'] is int
          ? json['freePropertyQuota'] as int
          : int.tryParse('${json['freePropertyQuota'] ?? 2}') ?? 2,
      extraPropertySlotFee: json['extraPropertySlotFee'] is int
          ? json['extraPropertySlotFee'] as int
          : int.tryParse('${json['extraPropertySlotFee'] ?? 10000}') ?? 10000,
      boostPackages: rawList
          .whereType<Map>()
          .map((e) => BoostPackageOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class BoostKostResult {
  final int creditBalance;
  final DateTime? boostedUntil;

  const BoostKostResult({
    required this.creditBalance,
    this.boostedUntil,
  });

  factory BoostKostResult.fromJson(Map<String, dynamic> json) {
    final kostMap = json['kost'] is Map
        ? Map<String, dynamic>.from(json['kost'] as Map)
        : const <String, dynamic>{};
    return BoostKostResult(
      creditBalance: json['creditBalance'] is int
          ? json['creditBalance'] as int
          : int.tryParse('${json['creditBalance'] ?? 0}') ?? 0,
      boostedUntil: kostMap['boostedUntil'] != null
          ? DateTime.tryParse(kostMap['boostedUntil'].toString())
          : null,
    );
  }
}
