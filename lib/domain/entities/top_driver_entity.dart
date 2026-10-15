/// Conductor destacado que se muestra en el inicio del pasajero.
///
/// Corresponde a una fila de la vista `top_drivers` en Supabase.
class TopDriverEntity {
  final String id;
  final String fullName;
  final String? profilePicUrl;
  final String? carBrand;
  final String? carModel;
  final String? carColor;
  final int? carYear;
  final double driverRating;
  final int tripCount;

  const TopDriverEntity({
    required this.id,
    required this.fullName,
    this.profilePicUrl,
    this.carBrand,
    this.carModel,
    this.carColor,
    this.carYear,
    required this.driverRating,
    required this.tripCount,
  });
}
