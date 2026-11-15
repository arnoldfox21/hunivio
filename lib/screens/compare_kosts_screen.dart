import 'package:flutter/material.dart';
import '../models/kost.dart';
import '../utils/formatters.dart';

class CompareKostsScreen extends StatelessWidget {
  final List<Kost> kosts;

  const CompareKostsScreen({super.key, required this.kosts});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        title: Text(
          'Bandingkan Properti (${kosts.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 130,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 110,
            columnSpacing: 18,
            headingRowColor: WidgetStateProperty.all(Colors.white),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            columns: [
              const DataColumn(
                label: SizedBox(
                  width: 110,
                  child: Text(
                    'Kriteria',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              ...kosts.map(
                (k) => DataColumn(
                  label: SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (k.images.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              k.images.first,
                              width: 155,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 155,
                                height: 68,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.home_work_outlined),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          k.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            rows: [
              _buildRow(
                'Harga / Bulan',
                kosts
                    .map(
                      (k) => Text(
                        formatRupiah(k.pricePerMonth),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Tipe & Kategori',
                kosts
                    .map((k) => Text('${k.propertyCategory} • ${k.type}'))
                    .toList(),
              ),
              _buildRow(
                'Lokasi',
                kosts
                    .map(
                      (k) => SizedBox(
                        width: 160,
                        child: Text(
                          '${k.district}, ${k.city}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Sisa Kamar',
                kosts
                    .map(
                      (k) => Text(
                        k.availableRooms > 0
                            ? 'Sisa ${k.availableRooms} kamar'
                            : 'Penuh',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: k.availableRooms > 0
                              ? AppColors.darkGreen
                              : AppColors.discountRed,
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Rating',
                kosts
                    .map(
                      (k) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            k.reviewCount > 0
                                ? '${k.rating.toStringAsFixed(1)} (${k.reviewCount})'
                                : 'Belum ada',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Fasilitas Kamar',
                kosts
                    .map(
                      (k) => SizedBox(
                        width: 160,
                        child: Text(
                          k.roomFacilities.isEmpty
                              ? '-'
                              : k.roomFacilities.join(', '),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Fasilitas Umum',
                kosts
                    .map(
                      (k) => SizedBox(
                        width: 160,
                        child: Text(
                          k.publicFacilities.isEmpty
                              ? '-'
                              : k.publicFacilities.join(', '),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              _buildRow(
                'Aturan',
                kosts
                    .map(
                      (k) => SizedBox(
                        width: 160,
                        child: Text(
                          k.rules.isEmpty ? '-' : k.rules.join(', '),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(String label, List<Widget> cells) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        ...cells.map((w) => DataCell(w)),
      ],
    );
  }
}
