import '../../domain/entities/ride_offer_entity.dart';

/// Modelo `ride_offers` + campos enriquecidos desde `profiles`.
class RideOfferModel extends RideOfferEntity {
  const RideOfferModel({
    required super.id,
    required super.rideId,
    required super.driverId,
    required super.offeredPrice,
    required super.status,
    required super.createdAt,
    super.driverFullName,
    super.driverProfilePicUrl,
    super.driverRating,
    super.driverCompletedTrips = 0,
    super.driverCarModel,
    super.driverCarBrand,
    super.driverCarPlate,
  });

  factory RideOfferModel.fromJson(Map<String, dynamic> json) {
    double price(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    DateTime ts(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    double? rating(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return RideOfferModel(
      id: json['id']?.toString() ?? '',
      rideId: json['ride_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      offeredPrice: price(json['offered_price']),
      status: (json['status']?.toString() ?? 'pending').trim().toLowerCase(),
      createdAt: ts(json['created_at']),
      driverFullName: json['driver_full_name']?.toString(),
      driverProfilePicUrl: json['driver_profile_pic_url']?.toString(),
      driverRating: rating(json['driver_rating']),
      driverCompletedTrips: _intLoose(json['driver_completed_trips']),
      driverCarModel: json['driver_car_model']?.toString(),
      driverCarBrand: json['driver_car_brand']?.toString(),
      driverCarPlate: json['driver_car_plate']?.toString(),
    );
  }

  static int _intLoose(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  RideOfferModel copyWithProfile({
    String? driverFullName,
    String? driverProfilePicUrl,
    double? driverRating,
    int? driverCompletedTrips,
    String? driverCarModel,
    String? driverCarBrand,
    String? driverCarPlate,
  }) {
    return RideOfferModel(
      id: id,
      rideId: rideId,
      driverId: driverId,
      offeredPrice: offeredPrice,
      status: status,
      createdAt: createdAt,
      driverFullName: driverFullName ?? this.driverFullName,
      driverProfilePicUrl: driverProfilePicUrl ?? this.driverProfilePicUrl,
      driverRating: driverRating ?? this.driverRating,
      driverCompletedTrips: driverCompletedTrips ?? this.driverCompletedTrips,
      driverCarModel: driverCarModel ?? this.driverCarModel,
      driverCarBrand: driverCarBrand ?? this.driverCarBrand,
      driverCarPlate: driverCarPlate ?? this.driverCarPlate,
    );
  }
}
