class Kost {
  final int id;
  final String name;
  final String slug;
  final String type; // 'Putra' | 'Putri' | 'Campur'
  final String city;
  final String district;
  final String address;
  final String description;
  final int pricePerMonth;
  final int? originalPrice;
  final int discountPercent;
  final double rating;
  final int reviewCount;
  final int availableRooms;
  final int totalRooms;
  final String roomSize;
  final bool electricityIncluded;
  final bool isSinggahsini;
  final bool isInstantBooking;
  final List<String> roomFacilities;
  final List<String> publicFacilities;
  final List<String> rules;
  final List<String> images;
  final String ownerName;
  final String ownerPhone;
  final String nearbyLandmark;
  final bool isFavorite;

  const Kost({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.city,
    required this.district,
    required this.address,
    required this.description,
    required this.pricePerMonth,
    this.originalPrice,
    required this.discountPercent,
    required this.rating,
    required this.reviewCount,
    required this.availableRooms,
    required this.totalRooms,
    required this.roomSize,
    required this.electricityIncluded,
    required this.isSinggahsini,
    required this.isInstantBooking,
    required this.roomFacilities,
    required this.publicFacilities,
    required this.rules,
    required this.images,
    required this.ownerName,
    required this.ownerPhone,
    required this.nearbyLandmark,
    this.isFavorite = false,
  });

  factory Kost.fromJson(Map<String, dynamic> json) {
    return Kost(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      type: json['type'] ?? 'Campur',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      pricePerMonth: json['pricePerMonth'] is int
          ? json['pricePerMonth']
          : int.tryParse('${json['pricePerMonth']}') ?? 0,
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
      electricityIncluded: json['electricityIncluded'] == true,
      isSinggahsini: json['isSinggahsini'] == true,
      isInstantBooking: json['isInstantBooking'] ?? true,
      roomFacilities: _parseStringList(json['roomFacilities']),
      publicFacilities: _parseStringList(json['publicFacilities']),
      rules: _parseStringList(json['rules']),
      images: _parseStringList(json['images']),
      ownerName: json['ownerName'] ?? 'Pemilik Kost',
      ownerPhone: json['ownerPhone'] ?? '6281234567890',
      nearbyLandmark: json['nearbyLandmark'] ?? '',
      isFavorite: json['isFavorite'] == true,
    );
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
