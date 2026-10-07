import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_theme.dart';
import '../core/currency_format.dart';
import '../models/ligo_qr.dart';

/// Cobro con Ligo Pay dentro de la pantalla de cobro: el QR con el monto
/// exacto mientras se espera el pago, y la confirmación cuando llega. No
/// guarda estado: la pantalla de cobro genera el QR y consulta el pago.
class LigoQrPanel extends StatelessWidget {
  const LigoQrPanel({
    super.key,
    required this.qr,
    required this.loading,
    required this.onRetry,
    required this.onRegenerate,
    required this.onRefresh,
    this.error,
  });

  final LigoQr? qr;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRegenerate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final qr = this.qr;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading && qr != null) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (qr == null)
            loading ? const _Generating() : _failure()
          else if (qr.isActive)
            _active(context, qr)
          else if (qr.isPaid)
            _paid(qr)
          else if (qr.canRegenerate)
            _regenerate(qr)
          else
            _notPayable(qr),
          if (error != null && qr != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.warning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _failure() {
    return Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 36, color: AppTheme.warning),
        const SizedBox(height: 10),
        Text(
          error ?? 'No se pudo generar el QR de Ligo Pay.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _active(BuildContext context, LigoQr qr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Muestra este QR al cliente',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            _LigoBadge(),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showFullScreen(context, qr),
            child: _QrBox(data: qr.qrValue!, size: 210),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          peruvianCurrency.format(qr.amount),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const Text(
          'ZAZU EXPRESS · monto exacto, un solo pago',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.purpleLight,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Esperando el pago del cliente…',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Consultar ahora',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          [
            if (qr.expiresAt != null) 'Vence el ${_expiry(qr.expiresAt!)}.',
            'Se confirma solo: no hace falta foto del comprobante.',
          ].join(' '),
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'Se paga con Yape, Plin o la app del banco. La app del BCP no lee '
          'estos QR: si el cliente es del BCP, que pague con Yape.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _paid(LigoQr qr) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: AppTheme.success,
        ),
        const SizedBox(height: 8),
        const Text(
          'Pago confirmado',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          peruvianCurrency.format(qr.amount),
          style: const TextStyle(
            color: AppTheme.success,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (qr.instructionId != null)
          Text(
            'Operación Ligo ${qr.instructionId}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        const SizedBox(height: 10),
        const Text(
          'Toma las dos fotos de la entrega para terminar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _regenerate(LigoQr qr) {
    final expired = qr.status == 'vencido';
    return Column(
      children: [
        Icon(
          expired ? Icons.timer_off_outlined : Icons.qr_code_2,
          size: 40,
          color: expired ? AppTheme.warning : AppTheme.purpleLight,
        ),
        const SizedBox(height: 8),
        Text(
          expired ? 'El QR venció sin pagarse' : 'El saldo cambió',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          'Genera uno nuevo por ${peruvianCurrency.format(qr.amount)}.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : onRegenerate,
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Generar nuevo QR'),
        ),
      ],
    );
  }

  Widget _notPayable(LigoQr qr) {
    return Column(
      children: [
        const Icon(Icons.info_outline, size: 36, color: AppTheme.info),
        const SizedBox(height: 8),
        Text(
          qr.message ??
              (qr.status == 'sin_saldo'
                  ? 'Este pedido no tiene saldo pendiente.'
                  : 'Ligo Pay no puede cobrar este monto.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Elige otro medio de pago.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  static String _expiry(DateTime date) =>
      '${DateFormat('dd/MM').format(date)} a las ${DateFormat('HH:mm').format(date)}';

  void _showFullScreen(BuildContext context, LigoQr qr) {
    final size = (MediaQuery.sizeOf(context).width - 96).clamp(200.0, 340.0);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QrBox(data: qr.qrValue!, size: size),
                  const SizedBox(height: 14),
                  Text(
                    peruvianCurrency.format(qr.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const Text(
                    'Ligo Pay · ZAZU EXPRESS',
                    style: TextStyle(
                      color: AppTheme.purpleLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toca para cerrar',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Generando el QR con el monto exacto…',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo blanco con margen: los lectores de QR fallan sobre fondos oscuros.
class _QrBox extends StatelessWidget {
  const _QrBox({required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _LigoBadge extends StatelessWidget {
  const _LigoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.purple.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Ligo Pay',
        style: TextStyle(
          color: AppTheme.purpleLight,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
