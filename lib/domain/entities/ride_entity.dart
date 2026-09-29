import 'package:equatable/equatable.dart';

/// Entidad de dominio que representa un Viaje (Ride) en la aplicación.
///
/// Esta clase es inmutable y representa la estructura de datos
/// independiente de cualquier fuente de datos externa.
class RideEntity extends Equatable {
  final String id;
  final String clientId;
  final String? driverId;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String originName;
  final String destName;
  final String
      status; // 'searching', 'negotiating', 'accepted', 'completed', 'cancelled'
  final double offeredPrice;
  final double? finalPrice;
  final DateTime createdAt;

  /// Última posición reportada del conductor (tabla `rides`).
  final double? driverLat;
  final double? driverLng;

  /// `efectivo` | `yape` | `plin` (u otros valores desde Supabase).
  final String paymentMethod;

  /// Primer nombre del cliente (p. ej. desde `profiles.full_name` en listados de conductor).
  final String clientFirstName;

  /// Viajes finalizados del cliente como pasajero (`rides` con `status = finished`).
  final int clientCompletedTrips;

  /// Valoración del pasajero en `profiles.passenger_rating` si existe en la BD.
  final double? clientPassengerRating;

  /// Foto del pasajero (`profiles.profile_pic_url`), enriquecido para listados del conductor.
  final String? clientProfilePicUrl;

  /// Nombre completo del conductor (profiles.full_name).
  final String? driverFullName;

  /// URL de foto de perfil del conductor (profiles.profile_pic_url).
  final String? driverProfilePicUrl;

  /// Valoración del conductor (profiles.driver_rating).
  final double? driverRating;

  /// Cantidad de viajes finalizados del conductor.
  final int driverCompletedTrips;

  /// Modelo del auto del conductor (profiles.car_model).
  final String? driverCarModel;

  /// Marca del auto del conductor (profiles.car_brand).
  final String? driverCarBrand;

  /// Placa del auto del conductor (profiles.car_plate).
  final String? driverCarPlate;

  const RideEntity({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.originName,
    required this.destName,
    required this.status,
    required this.offeredPrice,
    this.finalPrice,
    required this.createdAt,
    this.driverLat,
    this.driverLng,
    this.paymentMethod = 'efectivo',
    this.clientFirstName = '',
    this.clientCompletedTrips = 0,
    this.clientPassengerRating,
    this.clientProfilePicUrl,
    this.driverFullName,
    this.driverProfilePicUrl,
    this.driverRating,
    this.driverCompletedTrips = 0,
    this.driverCarModel,
    this.driverCarBrand,
    this.driverCarPlate,
  });

  @override
  List<Object?> get props => [
        id,
        clientId,
        driverId,
        originLat,
        originLng,
        destLat,
        destLng,
        originName,
        destName,
        status,
        offeredPrice,
        finalPrice,
        createdAt,
        driverLat,
        driverLng,
        paymentMethod,
        clientFirstName,
        clientCompletedTrips,
        clientPassengerRating,
        clientProfilePicUrl,
        driverFullName,
        driverProfilePicUrl,
        driverRating,
        driverCompletedTrips,
        driverCarModel,
        driverCarBrand,
        driverCarPlate,
      ];
}
