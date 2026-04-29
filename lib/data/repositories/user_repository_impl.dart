import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/user_model.dart';

/// Implementación concreta de [UserRepository] usando Supabase.
class UserRepositoryImpl implements UserRepository {
  static const _sessionKey = 'user_phone_session';

  final SupabaseClient _supabaseClient = Supabase.instance.client;

  @override
  Future<UserEntity?> getUserByPhone(String phone) async {
    final response = await _supabaseClient
        .from('profiles')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (response != null) {
      return UserModel.fromJson(response);
    }
    return null;
  }

  @override
  Future<UserEntity?> createUserProfile(UserEntity user) async {
    final model = user as UserModel;
    try {
      final response = await _supabaseClient
          .from('profiles')
          .insert(model.toJson())
          .select()
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
      developer.log(
        'createUserProfile: insert devolvió null (sin fila). '
        'phone=${model.phone} role=${model.role}',
        name: 'UserRepositoryImpl',
      );
      return null;
    } on PostgrestException catch (e, st) {
      developer.log(
        'createUserProfile PostgrestException: ${e.message} '
        '(code=${e.code}, details=${e.details}, hint=${e.hint}) '
        'phone=${model.phone} role=${model.role}',
        name: 'UserRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      developer.log(
        'createUserProfile error: $e phone=${model.phone} role=${model.role}',
        name: 'UserRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> saveUserSession(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, phone);
  }

  @override
  Future<String?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Campos que [submitDriverApplication] puede escribir. Excluye `role` e `is_approved`.
  static Map<String, dynamic> _driverApplicationPatch(UserEntity u) {
    final map = <String, dynamic>{
      'is_driver_applicant': true,
      'car_plate': u.carPlate,
      'car_brand': u.carBrand,
      'car_model': u.carModel,
      'car_year': u.carYear,
      'car_color': u.carColor,
      'soat_expiration': u.soatExpiration?.toUtc().toIso8601String(),
      'property_card_expiration':
          u.propertyCardExpiration?.toUtc().toIso8601String(),
      'technical_review_expiration':
          u.technicalReviewExpiration?.toUtc().toIso8601String(),
      'license_category': u.licenseCategory,
      'license_number': u.licenseNumber,
      'dni_front_url': u.dniFrontUrl,
      'dni_back_url': u.dniBackUrl,
      'license_url': u.licenseUrl,
      'soat_url': u.soatUrl,
      'property_card_url': u.propertyCardUrl,
      'profile_pic_url': u.profilePicUrl,
    };
    map.removeWhere((_, v) => v == null);
    return map;
  }

  @override
  Future<UserEntity?> submitDriverApplication(
    UserEntity applicationData,
  ) async {
    final sessionUid = _supabaseClient.auth.currentUser?.id;
    if (sessionUid == null || sessionUid.isEmpty) {
      developer.log(
        'submitDriverApplication: sin usuario de Supabase Auth',
        name: 'UserRepositoryImpl',
      );
      return null;
    }

    // Tras subir fotos suele usarse sesión anónima; auth.uid() puede no coincidir con
    // profiles.id (usuario ya existía como cliente). El update debe apuntar al id del perfil.
    final profileId = applicationData.id.trim();
    if (profileId.isEmpty || profileId == 'temporal') {
      developer.log(
        'submitDriverApplication: id de perfil inválido: $profileId',
        name: 'UserRepositoryImpl',
      );
      return null;
    }
    if (profileId != sessionUid) {
      developer.log(
        'submitDriverApplication: actualizando perfil id=$profileId '
        '(sesión auth.uid()=$sessionUid). Requiere política RLS en profiles que permita '
        'UPDATE a filas cuyo id no sea auth.uid() si aplica vuestro modelo.',
        name: 'UserRepositoryImpl',
      );
    }

    final patch = _driverApplicationPatch(applicationData);
    if (patch.isEmpty) {
      developer.log(
        'submitDriverApplication: patch vacío',
        name: 'UserRepositoryImpl',
      );
      return null;
    }

    try {
      final response = await _supabaseClient
          .from('profiles')
          .update(patch)
          .eq('id', profileId)
          .select()
          .maybeSingle();

      if (response != null) {
        return UserModel.fromJson(response);
      }
      developer.log(
        'submitDriverApplication: update sin fila devuelta',
        name: 'UserRepositoryImpl',
      );
      return null;
    } on PostgrestException catch (e, st) {
      developer.log(
        'submitDriverApplication PostgrestException: ${e.message} '
        '(code=${e.code})',
        name: 'UserRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      developer.log(
        'submitDriverApplication error: $e',
        name: 'UserRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
