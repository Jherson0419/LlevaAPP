import 'package:equatable/equatable.dart';

/// Oferta de un conductor sobre un viaje en estado `searching` (tabla `ride_offers`).
class RideOfferEntity extends Equatable {
  final String id;
  final String rideId;
  final String driverId;
  final double offeredPrice;
  /// `pending` | `accepted` | `rejected` | `withdrawn`
  final String status;
  final DateTime createdAt;

  final String? driverFullName;
  final String? driverProfilePicUrl;
  final double? driverRating;
  final int driverCompletedTrips;
  final String? driverCarModel;
  final String? driverCarBrand;
  final String? driverCarPlate;

  const RideOfferEntity({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.offeredPrice,
    required this.status,
    required this.createdAt,
    this.driverFullName,
    this.driverProfilePicUrl,
    this.driverRating,
    this.driverCompletedTrips = 0,
    this.driverCarModel,
    this.driverCarBrand,
    this.driverCarPlate,
  });

  bool get isPending => status == 'pending';

  /// Tras un `upsert` o repoll, conserva nombre/foto/coche del listado anterior si la fila nueva viene sin enriquecer.
  static RideOfferEntity mergeNullableProfile(
    RideOfferEntity fresh,
    RideOfferEntity? fallback,
  ) {
    if (fallback == null) return fresh;
    final sameRow = fresh.id == fallback.id;
    final sameDriver = fresh.driverId == fallback.driverId;
    if (!sameRow && !sameDriver) return fresh;
    String? pickStr(String? primary, String? secondary) {
      final t = primary?.trim() ?? '';
      return t.isNotEmpty ? primary : secondary;
    }

    return RideOfferEntity(
      id: fresh.id,
      rideId: fresh.rideId,
      driverId: fresh.driverId,
      offeredPrice: fresh.offeredPrice,
      status: fresh.status,
      createdAt: fresh.createdAt,
      driverFullName: pickStr(fresh.driverFullName, fallback.driverFullName),
      driverProfilePicUrl:
          pickStr(fresh.driverProfilePicUrl, fallback.driverProfilePicUrl),
      driverRating: fresh.driverRating ?? fallback.driverRating,
      driverCompletedTrips: fresh.driverCompletedTrips > 0
          ? fresh.driverCompletedTrips
          : fallback.driverCompletedTrips,
      driverCarModel: pickStr(fresh.driverCarModel, fallback.driverCarModel),
      driverCarBrand: pickStr(fresh.driverCarBrand, fallback.driverCarBrand),
      driverCarPlate: pickStr(fresh.driverCarPlate, fallback.driverCarPlate),
    );
  }

  @override
  List<Object?> get props => [
        id,
        rideId,
        driverId,
        offeredPrice,
        status,
        createdAt,
        driverFullName,
        driverProfilePicUrl,
        driverRating,
        driverCompletedTrips,
        driverCarModel,
        driverCarBrand,
        driverCarPlate,
      ];
}
