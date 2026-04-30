import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/utils/age_validation.dart';
import '../../../core/utils/pending_driver_documents.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/document_review_status.dart';
import '../../../domain/repositories/user_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final UserRepository _userRepository;
  final StorageService _storageService;

  AuthBloc({
    required UserRepository userRepository,
    required StorageService storageService,
  })  : _userRepository = userRepository,
        _storageService = storageService,
        super(const AuthInitial()) {
    on<VerifyPhoneNumber>(_onVerifyPhoneNumber);
    on<RegisterUser>(_onRegisterUser);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<RefreshProfileEvent>(_onRefreshProfile);
    on<LogoutRequested>(_onLogoutRequested);
    on<SubmitDriverApplicationEvent>(_onSubmitDriverApplication);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final phone = await _userRepository.getSavedSession();
      if (phone == null || phone.isEmpty) {
        emit(const AuthInitial());
        return;
      }

      final user = await _userRepository.getUserByPhone(phone);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
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

  Future<void> _onVerifyPhoneNumber(
    VerifyPhoneNumber event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final user = await _userRepository.getUserByPhone(event.phone);
      if (user != null) {
        await _userRepository.saveUserSession(user.phone);
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthNeedsRegistration(event.phone));
      }
    } catch (e) {
      emit(AuthError('Ocurrió un error al verificar el usuario'));
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

      final user = UserModel(
        id: 'temporal',
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
        await _userRepository.saveUserSession(created.phone);
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
