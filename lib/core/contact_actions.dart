import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';

/// Número en formato internacional para wa.me (sin "+"). Los números
/// peruanos de 9 dígitos reciben el prefijo 51.
String? whatsAppPhone(String? rawPhone) {
  if (rawPhone == null) return null;
  var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 9) digits = '51$digits';
  return digits.length >= 11 ? digits : null;
}

/// "Overshark/066467" → "Overshark".
String sellerName(String reference) {
  final seller = reference.split('/').first.trim();
  return seller.isEmpty ? 'ZAZU' : seller;
}

/// Pedido de posventa (cambio de un pedido anterior): "ATC/000018".
bool isAtcOrder(DeliveryOrder order) =>
    sellerName(order.externalRef).toUpperCase() == 'ATC';

/// Marca para los mensajes al cliente: la que manda el servidor, o el prefijo
/// de la nota de venta. En un ATC sin marca devuelve null, porque "ATC" no
/// le dice nada al cliente.
String? orderBrand(DeliveryOrder order) {
  final brand = order.brand?.trim();
  if (brand != null && brand.isNotEmpty) return _titleCase(brand);
  return isAtcOrder(order) ? null : sellerName(order.externalRef);
}

/// Cómo se nombra el pedido ante el cliente. Un ATC no muestra su código:
/// "el cambio de su pedido anterior de Bravos".
String orderPhrase(DeliveryOrder order) {
  final brand = orderBrand(order);
  if (isAtcOrder(order)) {
    return brand == null
        ? 'el cambio de su pedido anterior'
        : 'el cambio de su pedido anterior de $brand';
  }
  return 'su pedido de $brand (${order.externalRef})';
}

/// "BOX PRIME" → "Box Prime".
String _titleCase(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

Future<void> callCustomer(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));
  await _launch(context, uri, 'No se pudo abrir el marcador.');
}

/// Abre el chat de WhatsApp del cliente. Sin [text] solo abre la
/// conversación; con [text] deja el mensaje escrito listo para enviar.
Future<void> openWhatsAppChat(
  BuildContext context,
  DeliveryOrder order, {
  String? text,
}) async {
  final phone = whatsAppPhone(order.phone);
  if (phone == null) return;
  final uri = Uri.https('wa.me', '/$phone', {
    if (text != null && text.isNotEmpty) 'text': text,
  });
  await _launch(context, uri, 'No se pudo abrir WhatsApp para este número.');
}

Future<void> _launch(BuildContext context, Uri uri, String errorText) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Se informa el problema debajo si no existe una aplicación compatible.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorText)));
  }
}
