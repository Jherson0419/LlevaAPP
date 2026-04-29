import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

const String kClientIconEfectivo = 'assets/icons/IconoEfectivo.png';
const String kClientIconPlin = 'assets/icons/IconoPlin.png';
const String kClientIconYape = 'assets/icons/IconoYape.png';

String clientPaymentMethodAsset(String method) {
  switch (method.toLowerCase()) {
    case 'yape':
      return kClientIconYape;
    case 'plin':
      return kClientIconPlin;
    default:
      return kClientIconEfectivo;
  }
}

String clientPaymentMethodLabel(String method) {
  switch (method.toLowerCase()) {
    case 'yape':
      return 'Yape';
    case 'plin':
      return 'Plin';
    default:
      return 'Efectivo';
  }
}

class ClientPaymentMethodImage extends StatelessWidget {
  const ClientPaymentMethodImage({
    super.key,
    required this.method,
    this.size = 28,
  });

  final String method;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = method.toLowerCase();
    return Image.asset(
      clientPaymentMethodAsset(method),
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        m == 'yape'
            ? Icons.qr_code_2
            : m == 'plin'
                ? Icons.phone_android
                : Icons.payments_outlined,
        color: AppTheme.primaryBlue,
        size: size,
      ),
    );
  }
}

void showClientPaymentMethodPicker(BuildContext context) {
  final rideBloc = context.read<ClientRideBloc>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Método de pago',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _ClientPaymentMethodOptionTile(
                sheetCtx: sheetCtx,
                rideBloc: rideBloc,
                method: 'efectivo',
                label: 'Efectivo',
                assetPath: kClientIconEfectivo,
              ),
              const SizedBox(height: 8),
              _ClientPaymentMethodOptionTile(
                sheetCtx: sheetCtx,
                rideBloc: rideBloc,
                method: 'plin',
                label: 'Plin',
                assetPath: kClientIconPlin,
              ),
              const SizedBox(height: 8),
              _ClientPaymentMethodOptionTile(
                sheetCtx: sheetCtx,
                rideBloc: rideBloc,
                method: 'yape',
                label: 'Yape',
                assetPath: kClientIconYape,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ClientPaymentMethodOptionTile extends StatelessWidget {
  const _ClientPaymentMethodOptionTile({
    required this.sheetCtx,
    required this.rideBloc,
    required this.method,
    required this.label,
    required this.assetPath,
  });

  final BuildContext sheetCtx;
  final ClientRideBloc rideBloc;
  final String method;
  final String label;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            assetPath,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              method == 'yape'
                  ? Icons.qr_code_2
                  : method == 'plin'
                      ? Icons.phone_android
                      : Icons.payments_outlined,
              color: AppTheme.primaryBlue,
              size: 32,
            ),
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.darkTextSecondary,
        ),
        onTap: () {
          rideBloc.add(PaymentMethodChanged(method));
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }
}
