import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Avisos push de eventos de viaje vía la Edge Function `notify-ride`.
///
/// La función toma los textos de la base y solo deja avisar a la contraparte
/// del viaje: aquí solo se envía el tipo y el id.
class NotificationRepository {
  NotificationRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Best-effort: nunca lanza ni debe frenar el flujo del viaje.
  Future<void> notifyRideEvent({
    required String type,
    required String rideId,
  }) async {
    if (rideId.isEmpty || rideId == 'temporal') return;
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      await _supabase.functions.invoke(
        'notify-ride',
        body: {'type': type, 'ride_id': rideId},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
    } catch (e) {
      developer.log(
        'notify-ride ($type, $rideId): $e',
        name: 'NotificationRepository',
      );
    }
  }
}
