class AppConfig {
  static const baseUrl = 'https://api-dev.zazu.com.pe/api';
  static const googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'TU_API_KEY_AQUI',
  );
}
