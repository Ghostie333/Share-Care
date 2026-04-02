class AnnouncementMetadata {
  const AnnouncementMetadata._();

  /// Lista dostępnych kategorii ogłoszeń / zgłoszeń.
  static const List<String> categories = <String>[
    'Wszystkie kategorie',
    'Książki',
    'Elektronika',
    'Artykuły budowlane',
  ];

  /// Typy ogłoszeń.
  static const List<String> types = <String>[
    'Ogłoszenie',
    'Zgłoszenie',
  ];

  static String get defaultCategory => categories.first;

  static const String defaultAnnouncementType = 'Ogłoszenie';
  static const String defaultReportType = 'Zgłoszenie';

  /// Koduje typ i kategorię do jednego pola Category ("Typ|Kategoria").
  static String encode(String type, String category) {
    final t = type.trim().isEmpty ? defaultAnnouncementType : type.trim();
    final c = category.trim().isEmpty ? defaultCategory : category.trim();
    return '$t|$c';
  }

  /// Zwraca typ z zakodowanego pola Category.
  static String parseType(String? categoryEncoded) {
    final raw = (categoryEncoded ?? '').trim();
    if (raw.isEmpty) return defaultAnnouncementType;
    if (raw.contains('|')) return raw.split('|').first.trim();
    // kompatybilność dla starych danych
    return raw == defaultReportType ? defaultReportType : defaultAnnouncementType;
  }

  /// Zwraca samą kategorię z zakodowanego pola Category.
  static String parseCategory(String? categoryEncoded) {
    final raw = (categoryEncoded ?? '').trim();
    if (raw.isEmpty) return '';
    if (raw.contains('|')) return raw.split('|').skip(1).join('|').trim();
    return raw;
  }
}
