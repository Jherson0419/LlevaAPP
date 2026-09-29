import '../entities/user.dart';

/// Contrato de repositorio para operaciones relacionadas a usuarios/perfiles.
abstract class UserRepository {
  /// Obtiene un perfil por número de teléfono.
  ///
  /// Devuelve null si no existe.
  Future<UserEntity?> getUserByPhone(String phone);

  /// Obtiene un perfil por `id` (= `auth.uid()` de Supabase Auth tras el login
  /// real por OTP — ver BLOQUE 1.3 de la auditoría). Devuelve null si no existe.
  Future<UserEntity?> getUserById(String id);

  /// Migra una fila legacy de `profiles` (creada antes del login real por OTP,
  /// con un `id` que no coincide con ningún `auth.uid()`) para que pase a usar
  /// [newId]. Necesario porque la política RLS `id = auth.uid()` (ver
  /// supabase/migrations/002_fix_profiles_rls.sql) no puede aplicar a una fila
  /// cuyo id no es el del usuario autenticado. Se invoca una sola vez, en el
  /// primer login exitoso de un usuario existente tras el cambio a OTP real.
  Future<UserEntity?> migrateProfileId({
    required String currentId,
    required String newId,
  });

  /// Crea un nuevo perfil de usuario en la tabla `profiles`.
  ///
  /// Devuelve el usuario creado o null si falla la inserción.
  Future<UserEntity?> createUserProfile(UserEntity user);

  /// Guarda la sesión del usuario (teléfono) en almacenamiento local.
  Future<void> saveUserSession(String phone);

  /// Obtiene el teléfono de la sesión guardada, o null si no existe.
  Future<String?> getSavedSession();

  /// Limpia la sesión persistida.
  Future<void> clearSession();

  /// Actualiza el perfil con datos de solicitud de conductor (vehículo, legales, URLs).
  ///
  /// No modifica [UserEntity.role] ni [UserEntity.isApproved] en base de datos.
  /// Establece `is_driver_applicant = true`. Requiere sesión Supabase Auth.
  ///
  /// [applicationData] debe reflejar el perfil completo o los campos a persistir;
  /// el ID debe coincidir con el usuario autenticado.
  Future<UserEntity?> submitDriverApplication(UserEntity applicationData);
}
