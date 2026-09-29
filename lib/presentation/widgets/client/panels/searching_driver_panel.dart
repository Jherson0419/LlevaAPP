import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/enums/client_ride_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/client_ride_pricing.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';
import '../client_ride_driver_attention_banner.dart';

class SearchingDriverPanel extends StatefulWidget {
  const SearchingDriverPanel({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  State<SearchingDriverPanel> createState() => _SearchingDriverPanelState();
}

class _SearchingDriverPanelState extends State<SearchingDriverPanel> {
  static const Duration _autoCancelAfter = Duration(minutes: 15);
  Timer? _ticker;
  bool _autoCancelTriggered = false;
  String? _lastRideId;

  @override
  void initState() {
    super.initState();
    _lastRideId = widget.state.activeRide?.id;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkAutoCancel();
    });
  }

  @override
  void didUpdateWidget(covariant SearchingDriverPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentRideId = widget.state.activeRide?.id;
    if (currentRideId != _lastRideId) {
      _lastRideId = currentRideId;
      _autoCancelTriggered = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _checkAutoCancel() {
    if (_autoCancelTriggered) return;
    final blocState = context.read<ClientRideBloc>().state;
    if (blocState.status != ClientRideStatus.searchingDriver) return;
    final createdAt = blocState.activeRide?.createdAt;
    if (createdAt == null) return;
    final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (elapsed < _autoCancelAfter) return;

    _autoCancelTriggered = true;
    developer.log(
      'SearchingDriverPanel: timeout 15m -> add(CancelRide)',
      name: 'ClientUI',
    );
    context.read<ClientRideBloc>().add(const CancelRide());
  }

  void _showCancelDialog(BuildContext context, ClientRideBloc rideBloc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancelar solicitud',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Seguro que deseas cancelar la búsqueda de conductor?',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              rideBloc.add(const CancelRide());
            },
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Duration _elapsedRequestTime(ClientRideState state) {
    final createdAt = state.activeRide?.createdAt;
    if (createdAt == null) return Duration.zero;
    final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (elapsed.isNegative) return Duration.zero;
    return elapsed;
  }

  Duration _remainingRequestTime(Duration elapsed) {
    if (elapsed >= _autoCancelAfter) return Duration.zero;
    return _autoCancelAfter - elapsed;
  }

  String _formatDuration(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientRideBloc, ClientRideState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.offeredPrice != current.offeredPrice ||
          previous.suggestedPrice != current.suggestedPrice ||
          previous.paymentMethod != current.paymentMethod ||
          previous.moreThanFourPassengers != current.moreThanFourPassengers ||
          previous.babySeat != current.babySeat ||
          previous.pet != current.pet ||
          previous.rideComments != current.rideComments ||
          previous.pendingRideOffers != current.pendingRideOffers ||
          previous.activeRide?.id != current.activeRide?.id ||
          previous.activeRide?.offeredPrice !=
              current.activeRide?.offeredPrice ||
          previous.viewersCount != current.viewersCount,
      builder: (context, state) {
        final rideBloc = context.read<ClientRideBloc>();
        final suggested = state.suggestedPrice;
        final elapsed = _elapsedRequestTime(state);
        final remainingLabel = _formatDuration(_remainingRequestTime(elapsed));

        // Precio comprometido: el que está guardado en la BD.
        // El precio ofertado nunca puede bajar de este valor.
        final committedPrice =
            state.activeRide?.offeredPrice ?? state.offeredPrice;

        double currentPrice() =>
            state.offeredPrice > 0 ? state.offeredPrice : (suggested ?? 5);

        // Solo se puede aumentar, nunca bajar del precio comprometido.
        final canDecrease =
            !isRequesting(state) && currentPrice() > committedPrice;
        final canBoost =
            !isRequesting(state) && currentPrice() > committedPrice;

        // Heading
        final viewersCount = state.viewersCount;
        final headingText = isRequesting(state)
            ? 'Enviando solicitud...'
            : viewersCount == 0
                ? 'Buscando conductores...'
                : '$viewersCount conductor${viewersCount == 1 ? '' : 'es'} '
                    '${viewersCount == 1 ? 'está' : 'están'} visualizando '
                    'la solicitud';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                height: 4,
                width: 48,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Driver counter-offer banner
            ClientRideDriverAttentionBanner(offers: state.pendingRideOffers),
            const SizedBox(height: 14),

            // Heading + countdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    headingText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tiempo restante',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remainingLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Price rectangle: [−] price [+]  +  "Aumentar oferta" button inside
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Decrease button — disabled when at or below committed price
                      Material(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: canDecrease
                              ? () {
                                  final next =
                                      ClientRidePricing.decreaseOffered(
                                    current: currentPrice(),
                                    suggestedPrice: suggested,
                                  );
                                  // Clamp so price never drops below committed
                                  rideBloc.add(
                                    PriceChanged(
                                      next < committedPrice
                                          ? committedPrice
                                          : next,
                                    ),
                                  );
                                }
                              : null,
                          icon: Icon(
                            Icons.remove,
                            color: canDecrease
                                ? AppTheme.primaryBlue
                                : Colors.white24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'S/ ${currentPrice().toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Increase button
                      Material(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        child: IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: isRequesting(state)
                              ? null
                              : () {
                                  final next = ClientRidePricing.increaseOffered(
                                    currentPrice(),
                                  );
                                  rideBloc.add(PriceChanged(next));
                                },
                          icon: const Icon(
                            Icons.add,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // "Aumentar oferta" button — inside the rectangle
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canBoost
                          ? () => rideBloc.add(BoostOfferedPrice(currentPrice()))
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppTheme.darkSurface,
                        disabledForegroundColor: Colors.white24,
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Aumentar oferta',
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
            const SizedBox(height: 8),

            // Cancel request button — at the very bottom
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isRequesting(state)
                    ? null
                    : () => _showCancelDialog(context, rideBloc),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancelar solicitud',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool isRequesting(ClientRideState state) =>
      state.status == ClientRideStatus.requesting;
}
