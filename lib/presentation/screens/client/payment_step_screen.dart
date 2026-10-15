import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import '../../widgets/client/ride_step_indicator.dart';
import '../../widgets/client/ride_trip_labels.dart';
import '../../widgets/client/route_preview_map.dart';
import 'ride_flow_routes.dart';
import 'vehicle_step_screen.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);
const Color _kCashGreen = Color(0xFF2E7D32);

/// Paso 2 del pedido: resumen del viaje, vista previa de la ruta y método de
/// pago. Espera un [ClientRideBloc] ya provisto por quien navega aquí.
class PaymentStepScreen extends StatefulWidget {
  const PaymentStepScreen({super.key});

  @override
  State<PaymentStepScreen> createState() => _PaymentStepScreenState();
}

class _PaymentStepScreenState extends State<PaymentStepScreen> {
  static Color _getPaymentBgColor(String method) {
    switch (method) {
      case 'efectivo':
        return const Color(0xFFE8F5E9);
      case 'yape':
        return const Color(0xFFF3E5FF);
      case 'plin':
        return const Color(0xFFE3F2FF);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  static String _getPaymentLabel(String method) {
    switch (method) {
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      default:
        return 'Efectivo';
    }
  }

  static Widget _getPaymentIcon(String method) {
    switch (method) {
      case 'yape':
        return Image.asset('assets/icons/IconoYape.png', width: 24, height: 24);
      case 'plin':
        return Image.asset('assets/icons/IconoPlin.png', width: 24, height: 24);
      default:
        return const Icon(Icons.payments_rounded, color: _kCashGreen, size: 22);
    }
  }

  /// Abre el paso 3. «Atrás» desde ahí vuelve a este paso.
  void _goToVehicleStep() {
    final rideBloc = context.read<ClientRideBloc>();
    Navigator.of(context).push(
      rideFlowRoute<void>(
        (_) => BlocProvider.value(
          value: rideBloc,
          child: const VehicleStepScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: BlocBuilder<ClientRideBloc, ClientRideState>(
                builder: (context, state) {
                  void select(String method) => context
                      .read<ClientRideBloc>()
                      .add(PaymentMethodChanged(method));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Cómo vas a pagar?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Elige tu método de pago preferido',
                        style: TextStyle(fontSize: 14, color: _kTextMuted),
                      ),
                      const SizedBox(height: 20),
                      _TripSummaryCard(state: state),
                      const SizedBox(height: 16),

                      // Vista previa de la ruta (solo lectura)
                      const RoutePreviewMap(height: 200),

                      const SizedBox(height: 20),
                      const Text(
                        'Método de pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PaymentOption(
                        value: 'efectivo',
                        icon: Icons.payments_rounded,
                        iconColor: _kCashGreen,
                        iconBgColor: const Color(0xFFE8F5E9),
                        label: 'Efectivo',
                        subtitle: 'Paga al conductor en mano',
                        selectedMethod: state.paymentMethod,
                        onTap: () => select('efectivo'),
                      ),
                      const SizedBox(height: 10),
                      _PaymentOption(
                        value: 'yape',
                        assetIcon: 'assets/icons/IconoYape.png',
                        label: 'Yape',
                        subtitle: 'Paga con tu app Yape',
                        selectedMethod: state.paymentMethod,
                        onTap: () => select('yape'),
                      ),
                      const SizedBox(height: 10),
                      _PaymentOption(
                        value: 'plin',
                        assetIcon: 'assets/icons/IconoPlin.png',
                        label: 'Plin',
                        subtitle: 'Paga con tu app Plin',
                        selectedMethod: state.paymentMethod,
                        onTap: () => select('plin'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        16,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _kTextDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(
              children: [
                RideStepIndicator(
                  number: 1,
                  label: 'Destino',
                  isActive: false,
                  isDone: true,
                ),
                RideStepDivider(),
                RideStepIndicator(number: 2, label: 'Pago', isActive: true),
                RideStepDivider(),
                RideStepIndicator(
                  number: 3,
                  label: 'Vehículo',
                  isActive: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return BlocBuilder<ClientRideBloc, ClientRideState>(
      buildWhen: (p, c) =>
          p.paymentMethod != c.paymentMethod ||
          p.routeDistanceKm != c.routeDistanceKm ||
          p.routeDurationSeconds != c.routeDurationSeconds,
      builder: (context, state) {
        Widget metric(IconData icon, String value) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kBlue, size: 14),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                ),
              ),
            ],
          );
        }

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.paddingOf(context).bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Distancia y tiempo del viaje
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  metric(Icons.route_rounded, RideTripLabels.distance(state)),
                  const SizedBox(width: 16),
                  Container(
                    width: 1,
                    height: 14,
                    color: const Color(0xFFE0E0E0),
                  ),
                  const SizedBox(width: 16),
                  metric(
                    Icons.access_time_rounded,
                    RideTripLabels.duration(state),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFF0F0F0), height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _getPaymentBgColor(state.paymentMethod),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _getPaymentIcon(state.paymentMethod),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pagas con',
                                style:
                                    TextStyle(fontSize: 11, color: _kTextMuted),
                              ),
                              Text(
                                _getPaymentLabel(state.paymentMethod),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _kTextDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _goToVehicleStep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x440066CC),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continuar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de resumen: solo origen y destino. La distancia y el tiempo van
/// en la barra inferior, y la oferta se ajusta en el paso del vehículo.
class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.state});

  final ClientRideState state;

  static String _firstLine(String? raw, String fallback) {
    final text = raw?.trim() ?? '';
    return text.isEmpty ? fallback : text.split('\n').first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Column(
        children: [
          _PlaceRow(
            dotColor: const Color(0xFF00AA44),
            label: 'Origen',
            value: _firstLine(state.originName, 'Tu ubicación'),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 10,
              child: Center(
                child: SizedBox(
                  width: 1.5,
                  height: 16,
                  child: ColoredBox(color: Color(0xFFDDDDDD)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _PlaceRow(
            dotColor: _kBlue,
            label: 'Destino',
            value: _firstLine(state.destName, 'Destino'),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.dotColor,
    required this.label,
    required this.value,
  });

  final Color dotColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _kTextMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.selectedMethod,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.iconBgColor,
    this.assetIcon,
  });

  final String value;
  final String label;
  final String subtitle;
  final String selectedMethod;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? assetIcon;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMethod == value;
    final asset = assetIcon;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kBlue : const Color(0xFFEEEEEE),
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor ?? const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: asset != null
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(asset, fit: BoxFit.contain),
                    )
                  : Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kTextDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _kTextMuted),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _kBlue : const Color(0xFFCCCCCC),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
