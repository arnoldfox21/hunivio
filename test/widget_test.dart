import 'package:flutter_test/flutter_test.dart';
import 'package:hunivio/main.dart';
import 'package:hunivio/models/kost.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HuniVioApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HuniVioApp());
    expect(find.text('HuniVio'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Cari Kost'), findsOneWidget);
  });

  group('Kost model category & pricing helpers', () {
    Kost makeKost({
      String propertyCategory = 'KOST',
      String unitType = '',
      int pricePerMonth = 1200000,
      int? pricePerDay,
    }) {
      return Kost(
        id: 1,
        name: 'Sample Property',
        slug: 'sample-property',
        propertyCategory: propertyCategory,
        type: 'Campur',
        city: 'Malang',
        district: 'Lowokwaru',
        address: 'Jl. Soekarno Hatta',
        description: 'Deskripsi dinamis properti.',
        pricePerMonth: pricePerMonth,
        pricePerDay: pricePerDay,
        discountPercent: 0,
        rating: 4.8,
        reviewCount: 10,
        availableRooms: 3,
        roomSize: '4x5 m',
        unitType: unitType,
        electricityIncluded: true,
        isSinggahsini: false,
        isInstantBooking: false,
        roomFacilities: const ['AC', 'WiFi'],
        publicFacilities: const ['Parkir'],
        rules: const ['Dilarang merokok'],
        images: const ['https://example.com/1.jpg'],
        ownerName: 'Pemilik',
        ownerPhone: '08123456789',
        ownerId: 1,
        nearbyLandmark: 'Dekat UB',
      );
    }

    test('daily stay villa uses pricePerDay and Villa categoryLabel', () {
      final villa = makeKost(
        propertyCategory: 'HUNIAN_HARIAN',
        unitType: 'Villa',
        pricePerMonth: 0,
        pricePerDay: 850000,
      );
      expect(villa.isDailyStay, isTrue);
      expect(villa.categoryLabel, 'Villa');
      expect(villa.displayPrice, 850000);
      expect(villa.displayPriceShortUnit, '/malam');
      expect(villa.displayPriceFullUnit, 'per malam');
    });

    test('daily stay homestay uses Homestay categoryLabel', () {
      final homestay = makeKost(
        propertyCategory: 'HUNIAN_HARIAN',
        unitType: 'Homestay',
        pricePerMonth: 0,
        pricePerDay: 250000,
      );
      expect(homestay.isDailyStay, isTrue);
      expect(homestay.categoryLabel, 'Homestay');
      expect(homestay.displayPrice, 250000);
    });

    test('long-term categories use monthly price & correct labels', () {
      final kost = makeKost(propertyCategory: 'KOST');
      final apt = makeKost(propertyCategory: 'APARTEMEN');
      final kontrakan = makeKost(propertyCategory: 'KONTRAKAN');

      expect(kost.isDailyStay, isFalse);
      expect(kost.categoryLabel, 'Kost');
      expect(kost.displayPrice, 1200000);
      expect(kost.displayPriceShortUnit, '/bln');
      expect(kost.displayPriceFullUnit, 'per bulan');

      expect(apt.categoryLabel, 'Apartemen');
      expect(kontrakan.categoryLabel, 'Kontrakan');
    });
  });
}
