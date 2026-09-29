import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/ride_entity.dart';
import '../../../../domain/entities/ride_offer_entity.dart';
import '../../../../core/utils/passenger_name_helper.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';
import '../client_ride_driver_attention_banner.dart';
import '../client_ride_searching_actions_row.dart';

String? _lastNegotiatingPanelLogSig;

/// Lista de ofertas concurrentes (`ride_offers`) mientras el viaje sigue en `searching`.
class NegotiatingPanel extends StatelessWidget {
  const NegotiatingPanel({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientRideBloc, ClientRideState>(
      buildWhen: (previous, current) =>
          previous.pendingRideOffers != current.pendingRideOffers ||
          previous.paymentMethod != current.paymentMethod ||
          previous.moreThanFourPassengers != current.moreThanFourPassengers ||
          previous.babySeat != current.babySeat ||
          previous.pet != current.pet ||
          previous.rideComments != current.rideComments ||
          previous.activeRide?.id != current.activeRide?.id,
      builder: (context, state) {
        final ride = state.activeRide;
        final offers = state.pendingRideOffers;

        if (ride == null) {
          return const SafeArea(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            ),
          );
        }

        final sig =
            '${ride.id}|${offers.length}|${offers.map((o) => o.id).join(',')}';
        if (sig != _lastNegotiatingPanelLogSig) {
          _lastNegotiatingPanelLogSig = sig;
          developer.log(
            '[OFFERS_UI] NegotiatingPanel rideId=${ride.id} count=${offers.length}',
            name: 'ClientUI',
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black.withValues(alpha: 0.05),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 90, 16, 18),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.72,
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111).withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClientRideDriverAttentionBanner(offers: offers),
                          const SizedBox(height: 12),
                          Text(
                            offers.isEmpty
                                ? 'Buscando conductores'
                                : 'Ofertas (${offers.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: offers.isEmpty
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: offers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      return _OfferCard(
                                        ride: ride,
                                        offer: offers[index],
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          ClientRideSearchingActionsRow(state: state),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.ride,
    required this.offer,
  });

  final RideEntity ride;
  final RideOfferEntity offer;

  @override
  Widget build(BuildContext context) {
    final basePassengerPrice = ride.offeredPrice;
    final sameAsPassenger =
        (offer.offeredPrice - basePassengerPrice).abs() < 0.009;
    final priceLabel = sameAsPassenger
        ? 'Acepta tu tarifa'
        : 'Contraoferta';

    final rawName = (offer.driverFullName ?? '').trim();
    final firstFromProfile = rawName.isNotEmpty
        ? passengerFirstNameFromFullName(rawName).trim()
        : '';
    final idTail = offer.driverId.length >= 8
        ? offer.driverId.substring(0, 8).toUpperCase()
        : offer.driverId.toUpperCase();
    final displayName = firstFromProfile.isNotEmpty
        ? firstFromProfile
        : (idTail.isNotEmpty ? 'Conductor · $idTail' : 'Conductor');

    final driverRatingText = offer.driverRating != null
        ? '${offer.driverRating!.toStringAsFixed(1)} ★'
        : '— ★';
    final driverTripsText = '${offer.driverCompletedTrips} viajes';
    final vehicleBrand = (offer.driverCarBrand ?? '').trim();
    final vehicleModel = (offer.driverCarModel ?? '').trim();
    final vehiclePlate = (offer.driverCarPlate ?? '').trim();
    final vehicleMain =
        [vehicleBrand, vehicleModel].where((p) => p.isNotEmpty).join(' ');
    final vehicleModelText =
        vehicleMain.isNotEmpty ? vehicleMain : 'Vehículo no disponible';
    final vehicleExtraText =
        vehiclePlate.isNotEmpty ? 'Placa $vehiclePlate' : null;
    final profilePicUrl = offer.driverProfilePicUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Text(
                  priceLabel,
                  style: const TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'S/ ${offer.offeredPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.8),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: (profilePicUrl != null && profilePicUrl.trim().isNotEmpty)
                    ? Image.network(
                        profilePicUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: AppTheme.primaryBlue,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: AppTheme.primaryBlue,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$driverRatingText  ·  $driverTripsText',
                      style: const TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicleModelText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (vehicleExtraText != null)
                      Text(
                        vehicleExtraText,
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    context.read<ClientRideBloc>().add(
                          RejectRideOffer(offer.id),
                        );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    backgroundColor: const Color(0xFF2A2A2A),
                    side: const BorderSide(
                      color: AppTheme.errorRed,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Descartar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.read<ClientRideBloc>().add(
                          AcceptDriverOffer(
                            offerId: offer.id,
                            driverId: offer.driverId,
                            finalPrice: offer.offeredPrice,
                          ),
                        );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
