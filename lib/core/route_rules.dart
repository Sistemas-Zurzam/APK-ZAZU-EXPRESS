import '../models/order.dart';

/// Motivo por el que no se puede iniciar ruta de [order], o null si se puede.
///
/// Se reparte de uno en uno: solo puede haber un pedido En ruta. El servidor
/// valida lo mismo; revisarlo aquí evita esperar su respuesta para un "no".
String? startRouteBlockReason(DeliveryOrder order, List<DeliveryOrder> all) {
  if (order.isDelivered) return 'Este pedido ya fue entregado.';
  if (order.isInRoute) return 'Este pedido ya está en ruta.';
  if (!order.isReceived) {
    return 'Primero recepciona el pedido para poder iniciar su ruta.';
  }
  for (final other in all) {
    if (other.id != order.id && other.isInRoute) {
      return 'Ya tienes un pedido en ruta (${other.externalRef} - '
          '${other.customerName}). Entrégalo o reprográmalo antes de '
          'iniciar otro.';
    }
  }
  return null;
}
