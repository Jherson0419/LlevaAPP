import 'package:equatable/equatable.dart';

import '../../../data/models/user_model.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Pide a Supabase Auth que envíe (o reenvíe) el código SMS al número dado.
///
/// Reemplaza al antiguo `VerifyPhoneNumber`, que "autenticaba" solo con el
/// número de teléfono sin verificar ningún código — cualquiera que conociera
/// el teléfono de otra persona podía iniciar sesión como ella. Ver auditoría
/// BLOQUE 1.3.
class SendOtpRequested extends AuthEvent {
  final String phone;

  const SendOtpRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// El usuario ingresó el código de 6 dígitos recibido por SMS.
class OtpVerified extends AuthEvent {
  final String phone;
  final String code;

  const OtpVerified({required this.phone, required this.code});

  @override
  List<Object?> get props => [phone, code];
}

/// Evento interno: signInWithOtp/verifyOTP fallaron (código inválido/expirado,
/// proveedor SMS no configurado, etc.). Separado de AuthError como evento (no
/// solo estado) para que el flujo de envío/verificación sea testeable de punta
/// a punta vía bloc_test sin mockear excepciones a mitad de un handler.
class OtpFailed extends AuthEvent {
  final String message;

  const OtpFailed(this.message);

  @override
  List<Object?> get props => [message];
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

/// Inicia sesión con Google (One Tap / selector de cuentas nativo) — ver
/// AuthBloc._onGoogleSignIn.
class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
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
