import '../models/annoucement.dart';

/// Opcje sortowania listy ogłoszeń.
enum SortOption { nameAsc, nameDesc, depositAsc, depositDesc }

/// Zestaw filtrów stosowanych na liście ogłoszeń.
class SearchFilters {
  final SortOption? sortOption;
  final String? announcementType;
  final String? category;
  final double? minDeposit;
  final double? maxDeposit;
  final String? location;
  final double? radiusKm;
  final String? searchText;

  const SearchFilters({
    this.sortOption,
    this.announcementType,
    this.category,
    this.minDeposit,
    this.maxDeposit,
    this.location,
    this.radiusKm,
    this.searchText,
  });

  SearchFilters copyWith({
    SortOption? sortOption,
    String? announcementType,
    String? category,
    double? minDeposit,
    double? maxDeposit,
    String? location,
    double? radiusKm,
    String? searchText,
  }) {
    return SearchFilters(
      sortOption: sortOption ?? this.sortOption,
      announcementType: announcementType ?? this.announcementType,
      category: category ?? this.category,
      minDeposit: minDeposit ?? this.minDeposit,
      maxDeposit: maxDeposit ?? this.maxDeposit,
      location: location ?? this.location,
      radiusKm: radiusKm ?? this.radiusKm,
      searchText: searchText ?? this.searchText,
    );
  }

  static List<Announcement> applyTo(
    List<Announcement> items,
    SearchFilters filters,
  ) {
    var result = List<Announcement>.from(items);

    // Typ ogłoszenia (Ogłoszenie / Zgłoszenie).
    if (filters.announcementType != null &&
        filters.announcementType!.trim().isNotEmpty) {
      final expectedType = filters.announcementType!.trim().toLowerCase();
      result = result.where((a) {
        final type = _parseType(a.category).toLowerCase();
        return type == expectedType;
      }).toList();
    }

    // Cena min/max (kaucja)
    if (filters.minDeposit != null) {
      result = result
          .where((a) => (a.deposit ?? 0) >= filters.minDeposit!)
          .toList();
    }
    if (filters.maxDeposit != null) {
      result = result
          .where((a) => (a.deposit ?? 0) <= filters.maxDeposit!)
          .toList();
    }

    // Miasto / lokalizacja – proste dopasowanie tekstu.
    if (filters.location != null && filters.location!.trim().isNotEmpty) {
      final q = filters.location!.trim().toLowerCase();
      result = result
          .where((a) => a.location.toLowerCase().contains(q))
          .toList();
    }

    // Sortowanie
    switch (filters.sortOption) {
      case SortOption.nameAsc:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SortOption.nameDesc:
        result.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case SortOption.depositAsc:
        result.sort((a, b) => (a.deposit ?? 0).compareTo(b.deposit ?? 0));
        break;
      case SortOption.depositDesc:
        result.sort((a, b) => (b.deposit ?? 0).compareTo(a.deposit ?? 0));
        break;
      case null:
        // pozostaw domyślne sortowanie (wg CreatedAt z backendu)
        break;
    }

    return result;
  }

  static String _parseType(String? rawCategory) {
    if (rawCategory == null || rawCategory.isEmpty) return '';
    final parts = rawCategory.split('|');
    return parts.first.trim();
  }
}
