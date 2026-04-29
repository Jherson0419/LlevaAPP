import 'package:equatable/equatable.dart';

import '../../../data/models/user_model.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class VerifyPhoneNumber extends AuthEvent {
  final String phone;

  const VerifyPhoneNumber(this.phone);

  @override
  List<Object?> get props => [phone];
}

class RegisterUser extends AuthEvent {
  final String phone;
  final String fullName;
  final String role;
  final String? email;
  final String? dni;
  final String? carPlate;
  final String? carBrand;
  final String? carModel;
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

  /// Rutas locales (post registro 3 pasos); el BLoC sube y rellena URLs en perfil.
  final String? dniFrontLocalPath;
  final String? dniBackLocalPath;
  final String? licenseLocalPath;
  final String? soatLocalPath;
  final String? propertyCardLocalPath;
  final String? profilePicLocalPath;

  const RegisterUser({
    required this.phone,
    required this.fullName,
    required this.role,
    this.email,
    this.dni,
    this.carPlate,
    this.carBrand,
    this.carModel,
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
    this.dniFrontLocalPath,
    this.dniBackLocalPath,
    this.licenseLocalPath,
    this.soatLocalPath,
    this.propertyCardLocalPath,
    this.profilePicLocalPath,
  });

  @override
  List<Object?> get props => [
        phone,
        fullName,
        role,
        email,
        dni,
        carPlate,
        carBrand,
        carModel,
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
        dniFrontLocalPath,
        dniBackLocalPath,
        licenseLocalPath,
        soatLocalPath,
        propertyCardLocalPath,
        profilePicLocalPath,
      ];
}

class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

/// Vuelve a leer `profiles` por teléfono (p. ej. tras aprobar conductor en el panel).
/// No muestra pantalla de carga; solo actualiza [AuthAuthenticated].
class RefreshProfileEvent extends AuthEvent {
  const RefreshProfileEvent();
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// Envío de solicitud de conductor (Fase 3): vehículo, legales y URLs ya resueltas.
///
/// El [AuthBloc] fusiona con el usuario en sesión para no alterar `role` ni `isApproved`.
class SubmitDriverApplicationEvent extends AuthEvent {
  final UserModel applicationData;

  const SubmitDriverApplicationEvent(this.applicationData);

  @override
  List<Object?> get props => [applicationData];
}
