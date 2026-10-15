import '../../domain/entities/top_driver_entity.dart';

/// Modelo de datos para la vista `top_drivers` de Supabase.
class TopDriverModel extends TopDriverEntity {
  const TopDriverModel({
    required super.id,
    required super.fullName,
    super.profilePicUrl,
    super.carBrand,
    super.carModel,
    super.carColor,
    super.carYear,
    required super.driverRating,
    required super.tripCount,
  });

  factory TopDriverModel.fromJson(Map<String, dynamic> json) {
    return TopDriverModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      profilePicUrl: json['profile_pic_url'] as String?,
      carBrand: json['car_brand'] as String?,
      carModel: json['car_model'] as String?,
      carColor: json['car_color'] as String?,
      carYear: (json['car_year'] as num?)?.toInt(),
      driverRating: (json['driver_rating'] as num?)?.toDouble() ?? 5.0,
      tripCount: (json['trip_count'] as num?)?.toInt() ?? 0,
    );
  }
}
