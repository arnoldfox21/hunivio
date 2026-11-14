class Kost {
  final int id;
  final String name;
  final String slug;
  final String propertyCategory; // 'KOST' | 'APARTEMEN' | 'KONTRAKAN'
  final String type; // 'Putra' | 'Putri' | 'Campur'
  final String city;
  final String district;
  final String address;
  final String description;
  final int pricePerMonth;
  final int? pricePerDay;
  final int? pricePerYear;
  final int depositAmount;
  final int? originalPrice;
  final int discountPercent;
  final double rating;
  final int reviewCount;
  final int availableRooms;
  final int totalRooms;
  final String roomSize;
  final String unitType;
  final String furnishing;
  final int? floorLevel;
  final int? buildingArea;
  final int? landArea;
  final int bedrooms;
  final int bathrooms;
  final bool hasCarport;
  final bool isVerified;
  final bool electricityIncluded;
  final bool isSinggahsini;
  final bool isInstantBooking;
  final List<String> roomFacilities;
  final List<String> publicFacilities;
  final List<String> rules;
  final List<String> images;
  final String ownerName;
  final String ownerPhone;
  final int ownerId;
  final String nearbyLandmark;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;
  final String approvalStatus; // 'PENDING' | 'APPROVED' | 'REJECTED'
  final String rejectionReason;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isPendingApproval => approvalStatus.toUpperCase() == 'PENDING';
  bool get isApproved => approvalStatus.toUpperCase() == 'APPROVED';
  bool get isRejected => approvalStatus.toUpperCase() == 'REJECTED';

  Kost copyWith({bool? isFavorite}) {
    return Kost(
      id: id,
      name: name,
      slug: slug,
      propertyCategory: propertyCategory,
      type: type,
      city: city,
      district: district,
      address: address,
      description: description,
      pricePerMonth: pricePerMonth,
      pricePerDay: pricePerDay,
      pricePerYear: pricePerYear,
      depositAmount: depositAmount,
      originalPrice: originalPrice,
      discountPercent: discountPercent,
      rating: rating,
      reviewCount: reviewCount,
      availableRooms: availableRooms,
      totalRooms: totalRooms,
      roomSize: roomSize,
      unitType: unitType,
      furnishing: furnishing,
      floorLevel: floorLevel,
      buildingArea: buildingArea,
      landArea: landArea,
      bedrooms: bedrooms,
      bathrooms: bathrooms,
      hasCarport: hasCarport,
      isVerified: isVerified,
      electricityIncluded: electricityIncluded,
      isSinggahsini: isSinggahsini,
      isInstantBooking: isInstantBooking,
      roomFacilities: roomFacilities,
      publicFacilities: publicFacilities,
      rules: rules,
      images: images,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      ownerId: ownerId,
      nearbyLandmark: nearbyLandmark,
      latitude: latitude,
      longitude: longitude,
      isFavorite: isFavorite ?? this.isFavorite,
      approvalStatus: approvalStatus,
      rejectionReason: rejectionReason,
    );
  }

  String get categoryLabel {
    switch (propertyCategory.toUpperCase()) {
      case 'APARTEMEN':
        return 'Apartemen';
      case 'KONTRAKAN':
        return 'Kontrakan';
      default:
        return 'Kost';
    }
  }

  const Kost({
    required this.id,
    required this.name,
    required this.slug,
    this.propertyCategory = 'KOST',
    required this.type,
    required this.city,
    required this.district,
    required this.address,
    required this.description,
    required this.pricePerMonth,
    this.pricePerDay,
    this.pricePerYear,
    this.depositAmount = 0,
    this.originalPrice,
    required this.discountPercent,
    required this.rating,
    required this.reviewCount,
    required this.availableRooms,
    required this.totalRooms,
    required this.roomSize,
    this.unitType = '',
    this.furnishing = '',
    this.floorLevel,
    this.buildingArea,
    this.landArea,
    this.bedrooms = 1,
    this.bathrooms = 1,
    this.hasCarport = false,
    this.isVerified = true,
    required this.electricityIncluded,
    required this.isSinggahsini,
    required this.isInstantBooking,
    required this.roomFacilities,
    required this.publicFacilities,
    required this.rules,
    required this.images,
    required this.ownerName,
    required this.ownerPhone,
    this.ownerId = 1,
    required this.nearbyLandmark,
    this.latitude,
    this.longitude,
    this.isFavorite = false,
    this.approvalStatus = 'APPROVED',
    this.rejectionReason = '',
  });

  factory Kost.fromJson(Map<String, dynamic> json) {
    return Kost(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      propertyCategory:
          (json['propertyCategory'] ?? 'KOST').toString().toUpperCase(),
      type: json['type'] ?? 'Campur',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      pricePerMonth: json['pricePerMonth'] is int
          ? json['pricePerMonth']
          : int.tryParse('${json['pricePerMonth']}') ?? 0,
      pricePerDay: _parseIntNullable(json['pricePerDay']),
      pricePerYear: _parseIntNullable(json['pricePerYear']),
      depositAmount: _parseIntNullable(json['depositAmount']) ?? 0,
      originalPrice: json['originalPrice'] != null
          ? (json['originalPrice'] is int
              ? json['originalPrice']
              : int.tryParse('${json['originalPrice']}'))
          : null,
      discountPercent: json['discountPercent'] is int
          ? json['discountPercent']
          : int.tryParse('${json['discountPercent']}') ?? 0,
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : double.tryParse('${json['rating']}') ?? 4.5,
      reviewCount: json['reviewCount'] is int
          ? json['reviewCount']
          : int.tryParse('${json['reviewCount']}') ?? 0,
      availableRooms: json['availableRooms'] is int
          ? json['availableRooms']
          : int.tryParse('${json['availableRooms']}') ?? 0,
      totalRooms: json['totalRooms'] is int
          ? json['totalRooms']
          : int.tryParse('${json['totalRooms']}') ?? 10,
      roomSize: json['roomSize'] ?? '3 x 4 m',
      unitType: json['unitType']?.toString() ?? '',
      furnishing: json['furnishing']?.toString() ?? '',
      floorLevel: _parseIntNullable(json['floorLevel']),
      buildingArea: _parseIntNullable(json['buildingArea']),
      landArea: _parseIntNullable(json['landArea']),
      bedrooms: _parseIntNullable(json['bedrooms']) ?? 1,
      bathrooms: _parseIntNullable(json['bathrooms']) ?? 1,
      hasCarport: json['hasCarport'] == true,
      isVerified: json['isVerified'] ?? true,
      electricityIncluded: json['electricityIncluded'] == true,
      isSinggahsini: json['isSinggahsini'] == true,
      isInstantBooking: json['isInstantBooking'] ?? true,
      roomFacilities: _parseStringList(json['roomFacilities']),
      publicFacilities: _parseStringList(json['publicFacilities']),
      rules: _parseStringList(json['rules']),
      images: _parseStringList(json['images']),
      ownerName: json['ownerName'] ?? 'Pemilik Kost',
      ownerPhone: json['ownerPhone'] ?? '6281234567890',
      ownerId: json['ownerId'] is int
          ? json['ownerId']
          : int.tryParse('${json['ownerId']}') ?? 1,
      nearbyLandmark: json['nearbyLandmark'] ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      isFavorite: json['isFavorite'] == true,
      approvalStatus:
          (json['approvalStatus'] ?? 'APPROVED').toString().toUpperCase(),
      rejectionReason: json['rejectionReason']?.toString() ?? '',
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }
}
