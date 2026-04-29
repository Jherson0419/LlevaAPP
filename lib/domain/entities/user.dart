import 'package:equatable/equatable.dart';

/// Entidad de dominio que representa un usuario/perfil en la app.
///
/// Corresponde a la tabla `profiles` en Supabase.
class UserEntity extends Equatable {
  final String id;
  final String phone;
  final String role; // 'client' | 'driver'
  /// Solicitud de ascenso a conductor enviada; el [role] sigue siendo `client` hasta aprobación ERP.
  final bool isDriverApplicant;
  final String fullName;
  final String? email;
  final String? dni;
  final String? carPlate;
  final String? carBrand;
  final String? carModel;
  final bool isApproved;
  final bool isBanned;
  final int? carYear;
  final String? carColor;
  final DateTime? soatExpiration;
  final DateTime? propertyCardExpiration;
  final DateTime? technicalReviewExpiration;
  final String? licenseCategory;
  final String? licenseNumber;
  final DateTime? birthDate;
  final String? dniFrontUrl;
  final String? dniBackUrl;
  final String? licenseUrl;
  final String? soatUrl;
  final String? propertyCardUrl;
  final String? profilePicUrl;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.role,
    this.isDriverApplicant = false,
    required this.fullName,
    this.email,
    this.dni,
    this.carPlate,
    this.carBrand,
    this.carModel,
    this.isApproved = true,
    this.isBanned = false,
    this.carYear,
    this.carColor,
    this.soatExpiration,
    this.propertyCardExpiration,
    this.technicalReviewExpiration,
    this.licenseCategory,
    this.licenseNumber,
    this.birthDate,
    this.dniFrontUrl,
    this.dniBackUrl,
    this.licenseUrl,
    this.soatUrl,
    this.propertyCardUrl,
    this.profilePicUrl,
  });

  @override
  List<Object?> get props => [
        id,
        phone,
        role,
        isDriverApplicant,
        fullName,
        email,
        dni,
        carPlate,
        carBrand,
        carModel,
        isApproved,
        isBanned,
        carYear,
        carColor,
        soatExpiration,
        propertyCardExpiration,
        technicalReviewExpiration,
        licenseCategory,
        licenseNumber,
        birthDate,
        dniFrontUrl,
        dniBackUrl,
        licenseUrl,
        soatUrl,
        propertyCardUrl,
        profilePicUrl,
      ];
}
