import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/location_helper.dart';
import '../../../domain/entities/ride_entity.dart';
import '../ride_destination_display.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/driver_status/driver_status_bloc.dart';
import '../../bloc/driver_status/driver_status_event.dart';
import '../../bloc/driver_status/driver_status_state.dart';

/// Tarjeta de negociación: modo inmersivo, dos columnas + panel de acciones.
class DriverNegotiatingCard extends StatelessWidget {
  final DriverNegotiating state;
  /// Distancia conductor → recojo (km), si hay GPS.
  final double? distanceToPickupKm;

  const DriverNegotiatingCard({
    super.key,
    required this.state,
    this.distanceToPickupKm,
  });

  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _priceCyan = Color(0xFF00D4FF);
  static const Color _yapePurple = Color(0xFF742384);
  static const Color _cashGreen = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final ride = state.activeRide;
    final isYape = ride.paymentMethod.toLowerCase() == 'yape';
    final passengerLabel = ride.clientId.length >= 5
        ? ride.clientId.substring(0, 5)
        : (ride.clientId.isEmpty ? 'Pasajero' : ride.clientId);

    final distanceText = distanceToPickupKm != null
        ? 'A ${distanceToPickupKm!.toStringAsFixed(1)} km de ti'
        : 'Calculando distancia…';

    if (state.awaitingPassengerResponse) {
      return _buildAwaitingPassengerPanel(
        context,
        ride,
        passengerLabel,
        isYape,
        distanceText,
      );
    }

    final origin = LatLng(ride.originLat, ride.originLng);
    final destination = LatLng(ride.destLat, ride.destLng);
    final tripKm = LocationHelper.calculateDistance(origin, destination);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dragHandle(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _priceCyan,
                                width: 1.5,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.darkSurfaceElevated,
                              child: Icon(
                                Icons.person,
                                color: AppTheme.darkTextSecondary,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            passengerLabel,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.star, color: Colors.amber, size: 12),
                              SizedBox(width: 2),
                              Text(
                                '4.9',
                                style: TextStyle(
                                  color: AppTheme.darkText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '(120 viajes)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            distanceText,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${AppConstants.currencySymbol} ${ride.offeredPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _priceCyan,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tarifa ofrecida · ~${tripKm.toStringAsFixed(1)} km trayecto',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _routeRow(
                            Icons.my_location,
                            AppTheme.primaryBlue,
                            ride.originName,
                          ),
                          const SizedBox(height: 6),
                          RideDestinationDisplay(rawDestName: ride.destName),
                          const SizedBox(height: 10),
                          _paymentChip(isYape),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.white12),
                const SizedBox(height: 12),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _requestAgeLabel(DateTime createdAt) {
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes <= 0) return 'Hace un momento';
    if (minutes == 1) return 'Hace 1 min';
    return 'Hace $minutes min';
  }

  /// Modal inferior en espera de respuesta (mensaje va en el dashboard).
  Widget _buildAwaitingPassengerPanel(
    BuildContext context,
    RideEntity ride,
    String passengerLabel,
    bool isYape,
    String distanceText,
  ) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          decoration: const BoxDecoration(
            color: _cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _dragHandle(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppTheme.darkSurfaceElevated,
                                  child: Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  passengerLabel,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.darkText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '4.9',
                                      style: TextStyle(
                                        color: AppTheme.darkText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '(120 viajes)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _requestAgeLabel(ride.createdAt),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  distanceText,
                                  style: const TextStyle(
                                    color: Color(0xFF00D4FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${AppConstants.currencySymbol} ${state.currentOffer.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: _priceCyan,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _routeRow(
                                  Icons.trip_origin,
                                  Colors.greenAccent,
                                  ride.originName,
                                ),
                                const SizedBox(height: 6),
                                RideDestinationDisplay(rawDestName: ride.destName),
                                const SizedBox(height: 10),
                                _paymentChip(isYape),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey<String>(
                  'offer_timer_${ride.id}_${state.currentOffer}',
                ),
                duration: const Duration(seconds: 10),
                tween: Tween(begin: 1.0, end: 0.0),
                builder: (context, value, _) {
                  return Directionality(
                    textDirection: TextDirection.rtl,
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_priceCyan),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _routeRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.darkText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentChip(bool isYape) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isYape
              ? _yapePurple.withValues(alpha: 0.35)
              : _cashGreen.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isYape
                ? const Color(0xFF9C4DAD)
                : const Color(0xFF43A047),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isYape ? Icons.qr_code : Icons.attach_money,
              size: 14,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            const SizedBox(width: 6),
            Text(
              isYape ? 'Yape / Plin' : 'Efectivo',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final ride = state.activeRide;
    final offered = ride.offeredPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _onAcceptExact(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Aceptar por ${AppConstants.currencySymbol} ${offered.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickOfferButton(context, 1.0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickOfferButton(context, 2.0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickOfferButton(context, 3.0),
            ),
            IconButton(
              onPressed: () => _showManualOfferDialog(context),
              icon: const Icon(Icons.edit, color: _priceCyan),
              tooltip: 'Oferta manual',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            context.read<DriverStatusBloc>().add(const RejectRide());
          },
          child: const Text(
            'Ignorar solicitud',
            style: TextStyle(
              color: AppTheme.errorRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickOfferButton(BuildContext context, double delta) {
    return OutlinedButton(
      onPressed: () => _sendCounter(context, state.currentOffer + delta),
      style: OutlinedButton.styleFrom(
        foregroundColor: _priceCyan,
        side: const BorderSide(color: _priceCyan, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        '+ ${AppConstants.currencySymbol} ${delta.toStringAsFixed(1)}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  void _onAcceptExact(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión como conductor'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    context.read<DriverStatusBloc>().add(
          AcceptRide(
            ride: state.activeRide,
            driverId: authState.user.id,
            finalPrice: state.activeRide.offeredPrice,
          ),
        );
  }

  void _sendCounter(BuildContext context, double newPrice) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión como conductor'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    context.read<DriverStatusBloc>().add(
          CounterOfferRide(
            ride: state.activeRide,
            driverId: authState.user.id,
            newPrice: newPrice,
          ),
        );
  }

  void _showManualOfferDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text(
            'Tu contraoferta',
            style: TextStyle(color: AppTheme.darkText),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            style: const TextStyle(color: AppTheme.darkText, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Monto en soles',
              hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
              prefixText: 'S/ ',
              prefixStyle: TextStyle(color: AppTheme.darkText),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un monto mayor a cero'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                _sendCounter(context, value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _priceCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('Enviar oferta'),
            ),
          ],
        );
      },
    );
  }
}
