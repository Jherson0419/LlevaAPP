import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import '../../widgets/client/ride_price_control.dart';
import '../../widgets/client/ride_step_indicator.dart';
import '../../widgets/client/ride_trip_labels.dart';
import '../../widgets/client/vehicle_category_card.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);

/// Paso 3 del pedido: resumen del viaje, oferta, tipo de vehículo y «Pedir
/// Lleva». Espera un [ClientRideBloc] ya provisto por quien navega aquí.
///
/// Al pedir el viaje solo envía la solicitud: el dashboard abre la pantalla
/// del viaje en cuanto el estado pasa a «solicitando», y esa pantalla es
/// quien cierra todo el flujo cuando el viaje termina.
class VehicleStepScreen extends StatelessWidget {
  const VehicleStepScreen({super.key});

  /// Tarifa sugerida de [category] para la ruta actual, con los extras ya
  /// elegidos. Sin ruta usa 3 km como referencia.
  static String _priceForCategory(
    ClientVehicleCategory category,
    ClientRideState state,
  ) {
    final base = state.routeBaseSuggested;
    final routeBase = base != null && base > 0
        ? base
        : ClientRidePricing.routeBaseFromDistanceKm(
            state.routeDistanceKm ?? 3.0,
          );
    final total = ClientRidePricing.totalSuggested(
      routeBase: routeBase,
      category: category,
      moreThanFourPassengers: state.moreThanFourPassengers,
      babySeat: state.babySeat,
      pet: state.pet,
    );
    return 'S/ ${total.toStringAsFixed(2)}';
  }

  static String _firstLine(String? raw, String fallback) {
    final text = raw?.trim() ?? '';
    return text.isEmpty ? fallback : text.split('\n').first;
  }

  /// Editor de la oferta: sube desde abajo con un efecto de zoom y muestra
  /// el precio en grande con los botones − / +.
  void _showPriceEditor(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: rideBloc,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Zoom de entrada: el editor crece hasta su tamaño.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: BlocBuilder<ClientRideBloc, ClientRideState>(
                      builder: (context, state) =>
                          RidePriceControl(state: state),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _requestRide(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para pedir un viaje'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    context.read<ClientRideBloc>().add(SubmitRideRequest(authState.user.id));
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
                  final rideBloc = context.read<ClientRideBloc>();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Elige tu vehículo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Origen y destino + oferta, en una sola tarjeta
                      _TripOfferCard(
                        origin: _firstLine(state.originName, 'Tu ubicación'),
                        destination: _firstLine(state.destName, 'Destino'),
                        state: state,
                        onEditPrice: () => _showPriceEditor(context),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricBox(
                              icon: Icons.route_rounded,
                              value: RideTripLabels.distance(state),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricBox(
                              icon: Icons.access_time_rounded,
                              value: RideTripLabels.duration(state),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Tipo de vehículo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final option in kVehicleCategoryOptions)
                        _VehicleOptionCard(
                          option: option,
                          // La elegida muestra la oferta actual; las demás,
                          // su tarifa sugerida.
                          price: state.vehicleCategory == option.category &&
                                  state.offeredPrice > 0
                              ? 'S/ ${state.offeredPrice.toStringAsFixed(2)}'
                              : _priceForCategory(option.category, state),
                          isSelected: state.vehicleCategory == option.category,
                          onTap: () => rideBloc
                              .add(VehicleCategoryChanged(option.category)),
                        ),
                      const SizedBox(height: 6),
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
                RideStepIndicator(
                  number: 2,
                  label: 'Pago',
                  isActive: false,
                  isDone: true,
                ),
                RideStepDivider(),
                RideStepIndicator(number: 3, label: 'Vehículo', isActive: true),
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
          p.offeredPrice != c.offeredPrice || p.status != c.status,
      builder: (context, state) {
        // Sin tarifa (ruta aún sin calcular) o con el pedido ya en curso no
        // se puede pedir.
        final canRequest = state.offeredPrice > 0 &&
            state.status != ClientRideStatus.requesting &&
            state.status != ClientRideStatus.searchingDriver;
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tu oferta final',
                      style: TextStyle(fontSize: 11, color: _kTextMuted),
                    ),
                    Text(
                      state.offeredPrice > 0
                          ? 'S/ ${state.offeredPrice.toStringAsFixed(2)}'
                          : 'S/ --',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: canRequest ? () => _requestRide(context) : null,
                child: Opacity(
                  opacity: canRequest ? 1 : 0.5,
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
                          'Pedir Lleva',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta única con el origen y el destino a la izquierda y, a la derecha,
/// la oferta del pasajero. El precio no se edita aquí: tocarlo llama a
/// [onEditPrice], que abre el editor en la parte inferior. Sin tarifa
/// muestra «S/ --» y no responde al toque.
class _TripOfferCard extends StatelessWidget {
  const _TripOfferCard({
    required this.origin,
    required this.destination,
    required this.state,
    required this.onEditPrice,
  });

  final String origin;
  final String destination;
  final ClientRideState state;
  final VoidCallback onEditPrice;

  Widget _place(Color dotColor, String label, String value) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 10),
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

  @override
  Widget build(BuildContext context) {
    final offered = state.offeredPrice;
    final hasPrice = offered > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Origen y destino
          Expanded(
            child: Column(
              children: [
                _place(const Color(0xFF00AA44), 'Origen', origin),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 10,
                        child: Center(
                          child: SizedBox(
                            width: 1.5,
                            height: 14,
                            child: ColoredBox(color: Color(0xFFDDDDDD)),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Divider(color: Color(0xFFF0F0F0), height: 1),
                      ),
                    ],
                  ),
                ),
                _place(_kBlue, 'Destino', destination),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFE0E0E0),
          ),

          // Oferta: tocar el precio abre el editor en la parte inferior.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasPrice ? onEditPrice : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Tu oferta',
                  style: TextStyle(fontSize: 10, color: _kTextMuted),
                ),
                Text(
                  hasPrice ? 'S/ ${offered.toStringAsFixed(2)}' : 'S/ --',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
                if (hasPrice) ...[
                  const SizedBox(height: 2),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: _kTextMuted, size: 10),
                      SizedBox(width: 3),
                      Text(
                        'Toca para cambiar',
                        style: TextStyle(fontSize: 9, color: _kTextMuted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _kBlue, size: 14),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de vehículo a todo el ancho: ícono, datos (nombre, modelos de
/// referencia, tiempo y capacidad) y precio estimado para la ruta.
class _VehicleOptionCard extends StatelessWidget {
  const _VehicleOptionCard({
    required this.option,
    required this.price,
    required this.isSelected,
    required this.onTap,
  });

  final VehicleCategoryOption option;
  final String price;
  final bool isSelected;
  final VoidCallback onTap;

  static const Color _detail = Color(0xFF666666);

  /// Espacio de la foto del vehículo. Los autos (apaisados) llenan el ancho;
  /// la moto (casi cuadrada), el alto.
  static const double _imageWidth = 104;
  static const double _imageHeight = 76;

  /// Modelos de referencia de la categoría.
  static String _model(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.standard:
        return 'Toyota Corolla / similar';
      case ClientVehicleCategory.comfort:
        return 'BMW 3 / Mercedes C';
      case ClientVehicleCategory.xl:
        return 'Toyota Fortuner / similar';
      case ClientVehicleCategory.moto:
        return 'Honda CB / Yamaha';
    }
  }

  static String _capacity(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.standard:
      case ClientVehicleCategory.comfort:
        return '1-4 pas.';
      case ClientVehicleCategory.xl:
        return '1-6 pas.';
      case ClientVehicleCategory.moto:
        return '1 pas.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kBlue : const Color(0xFFEEEEEE),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Foto del vehículo, sin recuadro de fondo. Su tamaño marca el
            // alto de la tarjeta.
            SizedBox(
              width: _imageWidth,
              height: _imageHeight,
              child: Image.asset(
                option.image,
                fit: BoxFit.contain,
                // Los PNG originales miden hasta 2048 px; se decodifican
                // cerca del tamaño en que se muestran.
                cacheWidth: 360,
                // Si el asset falta, queda el ícono de la categoría.
                errorBuilder: (_, __, ___) => Icon(
                  option.icon,
                  size: 40,
                  color: option.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _model(option.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _kTextMuted),
                  ),
                  const SizedBox(height: 6),
                  // Wrap: con la foto más ancha, tiempo y capacidad pasan a
                  // dos líneas en pantallas angostas en vez de cortarse.
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: _detail,
                            size: 12,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '~4 min',
                            style: TextStyle(fontSize: 11, color: _detail),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            color: _detail,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _capacity(option.category),
                            style:
                                const TextStyle(fontSize: 11, color: _detail),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _kBlue : _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSelected ? 'tu oferta' : 'estimado',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _kBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
