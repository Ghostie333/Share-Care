// lib/config/app_config.dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://92.5.29.30:7070',
  );

  /// Klucz MapTiler używany w widoku mapy na stronie głównej.
  /// Ustaw w --dart-define=MAPTILER_API_KEY=... przy budowaniu.
  static const String mapTilerApiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: '',
  );

  // Informacja o wersji aplikacji
  static const String version = '0.9.3'; 
}