import 'app_config.dart';

/// Resuelve una URL de imagen que puede venir absoluta o relativa desde el
/// backend (mismo criterio que `resolveMediaUrl` en el panel web: ver
/// frontend/src/utils/mediaUrl.js).
String? resolveMediaUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return url;

  final api = AppConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');
  final backend = api.replaceFirst(RegExp(r'/api/?$'), '');

  if (url.startsWith('/storage/')) {
    return '$api/media/${url.replaceFirst('/storage/', '')}';
  }
  return '$backend$url';
}
