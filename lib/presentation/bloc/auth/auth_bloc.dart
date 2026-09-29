import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
// `supabase_flutter` también exporta un `AuthState` (gotrue, eventos de
// sesión) que choca con nuestro propio `AuthState` (estado del BLoC, en
// auth_state.dart) — sin el `hide`, todo archivo que use `AuthBloc` con
// `BlocBuilder`/`BlocListener` deja de compilar (ambiguous_import en cascada).
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/age_validation.dart';
import '../../../core/utils/pending_driver_documents.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/document_review_status.dart';
import '../../../domain/repositories/user_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Atajo de autenticación SOLO para pruebas locales: con [kDevMode] activo,
/// el código de verificación '000000' evita la llamada real a
/// `Supabase.auth.verifyOTP` y resuelve directamente si el teléfono ya tiene
/// perfil (login) o si necesita registro — ver [AuthBloc._onDevBypassOtpVerified].
/// Desactivado por defecto; actívalo explícitamente con
/// `--dart-define=DEV_MODE=true`. Sin sesión real de Supabase Auth, cualquier
/// operación que dependa de `auth.uid()` (RLS) fallará para un usuario
/// "logueado" por este atajo — solo sirve para navegar la UI en pruebas.
const bool kDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final UserRepository _userRepository;
  final StorageService _storageService;
  final SupabaseClient _supabase;

  AuthBloc({
    required UserRepository userRepository,
    required StorageService storageService,
    required SupabaseClient supabaseClient,
  })  : _userRepository = userRepository,
        _storageService = storageService,
        _supabase = supabaseClient,
        super(const AuthInitial()) {
    on<SendOtpRequested>(_onSendOtpRequested);
    on<OtpVerified>(_onOtpVerified);
    on<OtpFailed>(_onOtpFailed);
    on<GoogleSignInRequested>(_onGoogleSignIn);
    on<RegisterUser>(_onRegisterUser);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<RefreshProfileEvent>(_onRefreshProfile);
    on<LogoutRequested>(_onLogoutRequested);
    on<SubmitDriverApplicationEvent>(_onSubmitDriverApplication);
  }

  /// Supabase Phone Auth exige E.164; la UI solo captura el número local
  /// peruano de 9 dígitos (ver login_screen.dart). El lookup en
  /// `profiles.phone` sigue usando el número local tal cual ya estaba
  /// guardado — esta función solo aplica a las llamadas a Supabase Auth.
  String _toE164(String localPhone) {
    final digits = localPhone.trim();
    if (digits.startsWith('+')) return digits;
    return '+51$digits';
  }

  String _otpErrorMessage(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'El código expiró. Pide uno nuevo.';
    }
    if (code == 'sms_send_failed' ||
        (msg.contains('sms') && msg.contains('provider'))) {
      return 'El inicio de sesión por SMS no está configurado en el servidor. '
          'Contacta a soporte (ver docs/setup_phone_auth.md).';
    }
    if (msg.contains('invalid') || msg.contains('token')) {
      return 'Código incorrecto. Verifica los 6 dígitos.';
    }
    if (code == 'over_sms_send_rate_limit' || msg.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos antes de reintentar.';
    }
    return 'No se pudo verificar el código: ${e.message}';
  }

  Future<void> _onSendOtpRequested(
    SendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      await _supabase.auth.signInWithOtp(phone: _toE164(event.phone));
      emit(AuthOtpSent(event.phone));
    } on AuthException catch (e, st) {
      developer.log(
        'SendOtpRequested AuthException: ${e.message} (code=${e.code})',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      add(OtpFailed(_otpErrorMessage(e)));
    } catch (e, st) {
      developer.log(
        'SendOtpRequested error: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      add(const OtpFailed(
        'No se pudo enviar el código. Revisa tu conexión e intenta de nuevo.',
      ));
    }
  }

  Future<void> _onOtpVerified(
    OtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    if (kDevMode && event.code == '000000') {
      await _onDevBypassOtpVerified(event, emit);
      return;
    }
    try {
      emit(const AuthLoading());
      final response = await _supabase.auth.verifyOTP(
        phone: _toE164(event.phone),
        token: event.code,
        type: OtpType.sms,
      );
      final authUid = response.user?.id;
      if (authUid == null || authUid.isEmpty) {
        add(const OtpFailed(
            'No se pudo verificar el código. Intenta de nuevo.'));
        return;
      }

      var user = await _userRepository.getUserById(authUid);
      if (user == null) {
        // Filas creadas antes de este cambio (login por teléfono sin OTP real)
        // no tienen id = auth.uid(). Se ubican por teléfono y se migra su id
        // una sola vez para que la política RLS id = auth.uid() pueda aplicar
        // (ver supabase/migrations/002_fix_profiles_rls.sql).
        final legacy = await _userRepository.getUserByPhone(event.phone);
        if (legacy != null && legacy.id != authUid) {
          final migrated = await _userRepository.migrateProfileId(
            currentId: legacy.id,
            newId: authUid,
          );
          // Si la migración falla (p. ej. FK de rides.client_id/driver_id sin
          // ON UPDATE CASCADE), no bloqueamos el login — solo seguirá fallando
          // la próxima escritura que dependa de id = auth.uid() hasta migrar
          // el esquema (documentado en docs/setup_phone_auth.md).
          user = migrated ?? legacy;
        } else {
          user = legacy;
        }
      }

      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthNeedsRegistration(event.phone));
      }
    } on AuthException catch (e, st) {
      developer.log(
        'OtpVerified AuthException: ${e.message} (code=${e.code})',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      add(OtpFailed(_otpErrorMessage(e)));
    } catch (e, st) {
      developer.log(
        'OtpVerified error: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      add(const OtpFailed('No se pudo verificar el código. Intenta de nuevo.'));
    }
  }

  /// Rama de [kDevMode]: no llama a Supabase Auth, resuelve directo contra
  /// `profiles` por teléfono. Ver el comentario de [kDevMode] arriba.
  Future<void> _onDevBypassOtpVerified(
    OtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final user = await _userRepository.getUserByPhone(event.phone);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthNeedsRegistration(event.phone));
      }
    } catch (e, st) {
      developer.log(
        'DevBypass OtpVerified error: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      add(const OtpFailed('No se pudo verificar el código. Intenta de nuevo.'));
    }
  }

  Future<void> _onOtpFailed(
    OtpFailed event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthError(event.message));
  }

  Future<void> _onGoogleSignIn(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());

      final googleSignIn = GoogleSignIn(
        // Supabase valida el idToken contra el ID de cliente Web (no el de
        // Android) — se pasa como serverClientId, no como clientId, o
        // signInWithIdToken rechaza el token con audience inválida.
        serverClientId: AppConstants.googleWebClientId,
        scopes: const ['email'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Usuario cerró el selector de cuentas sin elegir ninguna.
        emit(const AuthInitial());
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        emit(const AuthError(
          'No se pudo obtener el token de Google. Intenta de nuevo.',
        ));
        return;
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final authUid = response.user?.id;
      if (authUid == null || authUid.isEmpty) {
        emit(const AuthError(
          'No se pudo iniciar sesión con Google. Intenta de nuevo.',
        ));
        return;
      }

      final existing = await _userRepository.getUserById(authUid);
      if (existing != null) {
        emit(AuthAuthenticated(existing));
        return;
      }

      // Perfil nuevo: un usuario de Google no tiene teléfono todavía, así que
      // llega con `phone` vacío a RegisterProfileScreen (campo editable ahí);
      // el correo de Google sí se propaga vía prefilledEmail.
      developer.log(
        'GoogleSignIn: perfil nuevo — '
        'displayName="${googleUser.displayName}" email="${googleUser.email}"',
        name: 'AuthBloc',
      );
      emit(AuthNeedsRegistration('', prefilledEmail: googleUser.email));
    } catch (e, st) {
      developer.log(
        'GoogleSignInRequested error: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      emit(AuthError('No se pudo iniciar sesión con Google: $e'));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      // La sesión real ahora la persiste Supabase Auth (JWT en su propio
      // storage), no el teléfono guardado a mano en SharedPreferences — ese
      // mecanismo era precisamente el punto de entrada inseguro que cierra
      // este bloque (ver auditoría BLOQUE 1.3).
      final authUid = _supabase.auth.currentSession?.user.id;
      if (authUid == null || authUid.isEmpty) {
        emit(const AuthInitial());
        return;
      }

      final user = await _userRepository.getUserById(authUid);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        // Sesión Supabase válida pero sin fila en `profiles` (registro
        // interrumpido a mitad de camino): no hay teléfono verificado a mano
        // para reanudar el registro, así que se manda a /login a reintentar
        // el flujo OTP completo.
        emit(const AuthInitial());
      }
    } catch (_) {
      emit(const AuthInitial());
    }
  }

  Future<void> _onRefreshProfile(
    RefreshProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) return;
    final phone = (state as AuthAuthenticated).user.phone.trim();
    if (phone.isEmpty) return;
    try {
      final user = await _userRepository.getUserByPhone(phone);
      if (user != null) {
        emit(AuthAuthenticated(user));
      }
    } catch (e, st) {
      developer.log(
        'RefreshProfile: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _supabase.auth.signOut();
    // Limpia cualquier resto del mecanismo de sesión legacy (teléfono en
    // SharedPreferences); ya no se usa para decidir autenticación, pero se
    // borra por higiene si quedó de una instalación previa a este cambio.
    await _userRepository.clearSession();
    emit(const AuthInitial());
  }

  Future<void> _onSubmitDriverApplication(
    SubmitDriverApplicationEvent event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAuthenticated) {
      emit(const AuthError('Debes iniciar sesión para enviar la solicitud'));
      return;
    }

    final authState = state as AuthAuthenticated;
    final base = authState.user;
    if (base is! UserModel) {
      emit(const AuthError('No se pudo preparar la solicitud de conductor'));
      return;
    }

    final merged = event.applicationData.copyWith(
      id: base.id,
      phone: base.phone,
      role: base.role,
      isApproved: base.isApproved,
      isBanned: base.isBanned,
      fullName: base.fullName,
      email: base.email,
      dni: base.dni,
      birthDate: base.birthDate,
      isDriverApplicant: true,
    );

    try {
      emit(const AuthLoading());
      final updated = await _userRepository.submitDriverApplication(merged);
      if (updated != null) {
        emit(AuthAuthenticated(updated));
      } else {
        emit(const AuthError(
          'No se pudo enviar la solicitud. Revisa tu conexión o vuelve a iniciar sesión.',
        ));
      }
    } catch (e, st) {
      developer.log(
        'SubmitDriverApplication falló: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      emit(const AuthError('Ocurrió un error al enviar la solicitud'));
    }
  }

  Future<void> _onRegisterUser(
    RegisterUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final isDriver = event.role == 'driver';
      final driverWillUpload = isDriver && _driverUsesLocalDocPaths(event);
      if (!driverWillUpload) {
        emit(const AuthLoading());
      }

      if (isDriver) {
        final full = event.fullName.trim();
        final mail = event.email?.trim() ?? '';
        final doc = event.dni?.trim() ?? '';
        final plate = event.carPlate?.trim() ?? '';
        final brand = event.carBrand?.trim() ?? '';
        final model = event.carModel?.trim() ?? '';
        final brevete = event.licenseNumber?.trim() ?? '';
        final category = event.licenseCategory?.trim() ?? '';

        if (full.length < 5) {
          emit(const AuthError('Ingresa nombre y apellidos completos'));
          return;
        }
        if (mail.isEmpty || !mail.contains('@')) {
          emit(const AuthError('Ingresa un correo electrónico válido'));
          return;
        }
        if (doc.length != 8 || int.tryParse(doc) == null) {
          emit(const AuthError('El DNI debe tener 8 dígitos'));
          return;
        }
        if (brand.isEmpty || model.isEmpty || plate.isEmpty) {
          emit(const AuthError('Completa marca, modelo y placa del vehículo'));
          return;
        }
        if (event.carYear == null ||
            event.carYear! < 2005 ||
            event.carYear! > DateTime.now().year + 1) {
          emit(const AuthError(
            'Indica un año de fabricación válido (desde 2005)',
          ));
          return;
        }
        if (category.isEmpty) {
          emit(const AuthError('Selecciona la categoría de tu licencia'));
          return;
        }
        if (brevete.isEmpty) {
          emit(const AuthError('Ingresa el número de tu brevete'));
          return;
        }
        if (event.soatExpiration == null) {
          emit(const AuthError('Selecciona la fecha de vencimiento del SOAT'));
          return;
        }
        if (event.propertyCardExpiration == null) {
          emit(const AuthError(
            'Selecciona la fecha de vencimiento de la tarjeta de propiedad',
          ));
          return;
        }
        if (event.technicalReviewExpiration == null) {
          emit(const AuthError(
            'Selecciona la fecha de vencimiento de la revisión técnica',
          ));
          return;
        }
        if (_driverUsesLocalDocPaths(event)) {
          final missing = _missingDriverLocalPaths(event);
          if (missing != null) {
            emit(AuthError(missing));
            return;
          }
        }
      } else if (event.role == 'client') {
        final full = event.fullName.trim();
        final mail = event.email?.trim() ?? '';
        final doc = event.dni?.trim() ?? '';

        if (full.length < 5) {
          emit(const AuthError('Ingresa nombre y apellidos completos'));
          return;
        }
        if (mail.isEmpty || !mail.contains('@') || !mail.contains('.')) {
          emit(const AuthError('Ingresa un correo electrónico válido'));
          return;
        }
        if (doc.length != 8 || int.tryParse(doc) == null) {
          emit(const AuthError('El DNI debe tener 8 dígitos'));
          return;
        }
        if (event.birthDate == null) {
          emit(const AuthError('Selecciona tu fecha de nacimiento'));
          return;
        }
        if (!AgeValidation.isAtLeastYearsOld(event.birthDate!, 18)) {
          emit(const AuthError(
            'Debes tener al menos 18 años para crear una cuenta',
          ));
          return;
        }
      }

      String? dniFrontUrl = event.dniFrontUrl?.trim();
      String? dniBackUrl = event.dniBackUrl?.trim();
      String? licenseUrl = event.licenseUrl?.trim();
      String? soatUrl = event.soatUrl?.trim();
      String? propertyCardUrl = event.propertyCardUrl?.trim();
      String? profilePicUrl = event.profilePicUrl?.trim();

      if (isDriver && _driverUsesLocalDocPaths(event)) {
        final specs = <({String path, String fileBase, String label})>[
          (
            path: event.dniFrontLocalPath!.trim(),
            fileBase: 'dni_front',
            label: 'DNI frontal',
          ),
          (
            path: event.dniBackLocalPath!.trim(),
            fileBase: 'dni_back',
            label: 'DNI posterior',
          ),
          (
            path: event.licenseLocalPath!.trim(),
            fileBase: 'license',
            label: 'Licencia',
          ),
          (
            path: event.soatLocalPath!.trim(),
            fileBase: 'soat',
            label: 'SOAT',
          ),
          (
            path: event.propertyCardLocalPath!.trim(),
            fileBase: 'property_card',
            label: 'Tarjeta de propiedad',
          ),
          (
            path: event.profilePicLocalPath!.trim(),
            fileBase: 'profile_pic',
            label: 'Foto de perfil',
          ),
        ];

        for (var i = 0; i < specs.length; i++) {
          emit(AuthUploadingDriverDocs(
            completed: i,
            total: specs.length,
          ));
          final spec = specs[i];
          final file = File(spec.path);
          if (!await file.exists()) {
            developer.log(
              'Subida documentos conductor: archivo inexistente '
              'label=${spec.label} path=${spec.path}',
              name: 'AuthBloc',
            );
            emit(AuthError(
              'No se encontró el archivo de ${spec.label}. Vuelve a tomar la foto.',
            ));
            return;
          }
          try {
            developer.log(
              'Subida documentos conductor: inicio ${spec.fileBase} '
              'path=${spec.path}',
              name: 'AuthBloc',
            );
            final url = await _storageService.uploadImage(file, spec.fileBase);
            switch (i) {
              case 0:
                dniFrontUrl = url;
                break;
              case 1:
                dniBackUrl = url;
                break;
              case 2:
                licenseUrl = url;
                break;
              case 3:
                soatUrl = url;
                break;
              case 4:
                propertyCardUrl = url;
                break;
              case 5:
                profilePicUrl = url;
                break;
            }
          } catch (e, st) {
            developer.log(
              'Subida documentos conductor falló ${spec.fileBase} '
              'label=${spec.label} localPath=${spec.path}: $e',
              name: 'AuthBloc',
              error: e,
              stackTrace: st,
            );
            emit(AuthError(
              'Error al subir ${spec.label}. Revisa tu conexión e intenta de nuevo.',
            ));
            return;
          }
        }
        emit(AuthUploadingDriverDocs(
          completed: specs.length,
          total: specs.length,
        ));
      }

      emit(const AuthLoading());

      // Tras un verifyOTP exitoso ya existe una sesión real de Supabase Auth;
      // el perfil nuevo debe nacer con id = auth.uid() para que la política
      // RLS id = auth.uid() (002_fix_profiles_rls.sql) le permita editarse a
      // sí mismo más adelante. 'temporal' queda solo como red de seguridad
      // si por algún motivo no hay sesión (no debería ocurrir en este punto).
      final authUid = _supabase.auth.currentUser?.id;
      final user = UserModel(
        id: (authUid != null && authUid.isNotEmpty) ? authUid : 'temporal',
        phone: event.phone,
        role: event.role,
        fullName: event.fullName.trim(),
        email: isDriver
            ? event.email!.trim()
            : (event.role == 'client' ? event.email!.trim() : null),
        dni: isDriver
            ? event.dni!.trim()
            : (event.role == 'client' ? event.dni!.trim() : null),
        carPlate: isDriver ? event.carPlate!.trim() : null,
        carBrand: isDriver ? event.carBrand!.trim() : null,
        carModel: isDriver ? event.carModel!.trim() : null,
        isApproved: isDriver ? false : true,
        isBanned: false,
        carYear: isDriver ? event.carYear : null,
        carColor: isDriver ? event.carColor?.trim() : null,
        soatExpiration: isDriver ? event.soatExpiration : null,
        propertyCardExpiration: isDriver ? event.propertyCardExpiration : null,
        technicalReviewExpiration:
            isDriver ? event.technicalReviewExpiration : null,
        licenseCategory: isDriver ? event.licenseCategory!.trim() : null,
        licenseNumber: isDriver ? event.licenseNumber!.trim() : null,
        birthDate: event.role == 'client' ? event.birthDate : null,
        dniFrontUrl: isDriver ? dniFrontUrl : null,
        dniBackUrl: isDriver ? dniBackUrl : null,
        licenseUrl: isDriver ? licenseUrl : null,
        soatUrl: isDriver ? soatUrl : null,
        propertyCardUrl: isDriver ? propertyCardUrl : null,
        profilePicUrl: isDriver ? profilePicUrl : null,
        dniFrontStatus: DocumentReviewStatus.pending.value,
        dniBackStatus: DocumentReviewStatus.pending.value,
        licenseStatus: DocumentReviewStatus.pending.value,
        soatStatus: DocumentReviewStatus.pending.value,
        propertyCardStatus: DocumentReviewStatus.pending.value,
      );

      final created = await _userRepository.createUserProfile(user);
      if (created != null) {
        if (isDriver) {
          await PendingDriverDocuments.clear();
        }
        // La sesión ya quedó persistida por Supabase Auth desde el verifyOTP;
        // ya no se guarda el teléfono a mano (ver _onCheckAuthStatus).
        emit(AuthAuthenticated(created));
      } else {
        emit(const AuthError('No se pudo crear el perfil'));
      }
    } catch (e, st) {
      developer.log(
        'RegisterUser falló en AuthBloc: $e',
        name: 'AuthBloc',
        error: e,
        stackTrace: st,
      );
      emit(AuthError('Ocurrió un error al crear el perfil'));
    }
  }

  static bool _driverUsesLocalDocPaths(RegisterUser e) {
    if (e.role != 'driver') return false;
    final paths = [
      e.dniFrontLocalPath,
      e.dniBackLocalPath,
      e.licenseLocalPath,
      e.soatLocalPath,
      e.propertyCardLocalPath,
      e.profilePicLocalPath,
    ];
    return paths.any((p) => p != null && p.trim().isNotEmpty);
  }

  /// Si falta alguna ruta cuando se usan documentos locales.
  static String? _missingDriverLocalPaths(RegisterUser e) {
    final paths = [
      e.dniFrontLocalPath,
      e.dniBackLocalPath,
      e.licenseLocalPath,
      e.soatLocalPath,
      e.propertyCardLocalPath,
      e.profilePicLocalPath,
    ];
    if (!paths.any((p) => p != null && p.trim().isNotEmpty)) {
      return null;
    }
    if (paths.every((p) => p != null && p.trim().isNotEmpty)) {
      return null;
    }
    return 'Faltan fotos de documentos. Completa todas antes de registrarte.';
  }
}
