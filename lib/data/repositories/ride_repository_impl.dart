import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/passenger_name_helper.dart';
import '../../domain/entities/ride_entity.dart';
import '../../domain/entities/ride_offer_entity.dart';
import '../../domain/repositories/ride_repository.dart';
import '../models/ride_model.dart';
import '../models/ride_offer_model.dart';

String _profileMapKey(String? raw) => (raw ?? '').trim().toLowerCase();

/// Implementación concreta de RideRepository usando Supabase.
///
/// Se comunica con PostgreSQL a través de Supabase para realizar
/// operaciones CRUD y suscripciones en tiempo real.
class RideRepositoryImpl implements RideRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  @override
  Future<RideEntity> createRideRequest(RideEntity ride) async {
    final rideModel = RideModel(
      id: ride.id,
      clientId: ride.clientId,
      driverId: ride.driverId,
      originLat: ride.originLat,
      originLng: ride.originLng,
      destLat: ride.destLat,
      destLng: ride.destLng,
      originName: ride.originName,
      destName: ride.destName,
      status: ride.status,
      offeredPrice: ride.offeredPrice,
      finalPrice: ride.finalPrice,
      createdAt: ride.createdAt,
      driverLat: ride.driverLat,
      driverLng: ride.driverLng,
      paymentMethod: ride.paymentMethod,
      clientFirstName: ride.clientFirstName,
      clientCompletedTrips: ride.clientCompletedTrips,
      clientPassengerRating: ride.clientPassengerRating,
      clientProfilePicUrl: ride.clientProfilePicUrl,
    );

    final response = await _supabaseClient
        .from('rides')
        .insert(rideModel.toJson())
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception('No se pudo crear el viaje');
    }
    return RideModel.fromJson(response);
  }

  @override
  Stream<RideEntity> subscribeToRide(String rideId) {
    return _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('id', rideId)
        .where((list) => list.isNotEmpty)
        .asyncExpand((list) async* {
          final baseRide = RideModel.fromJson(
            Map<String, dynamic>.from(list.first as Map),
          );
          developer.log(
            '[NEGOTIATION_DEBUG] subscribeToRide base emit '
            'rideId=${baseRide.id} status=${baseRide.status} '
            'driverId=${baseRide.driverId} '
            'offered=${baseRide.offeredPrice} final=${baseRide.finalPrice}',
            name: 'RideRepository',
          );
          // Emite de inmediato el ride base para que la UI no espere
          // el enriquecimiento de perfil del conductor.
          yield baseRide;
          final withDriver = await _enrichRideWithDriverProfile(baseRide);
          final enriched = await _enrichRideWithClientProfile(withDriver);
          developer.log(
            '[NEGOTIATION_DEBUG] subscribeToRide enriched emit '
            'rideId=${enriched.id} status=${enriched.status} '
            'driverName=${enriched.driverFullName} '
            'clientFirst=${enriched.clientFirstName} '
            'car=${enriched.driverCarBrand} ${enriched.driverCarModel} '
            'plate=${enriched.driverCarPlate} '
            'rating=${enriched.driverRating} '
            'trips=${enriched.driverCompletedTrips}',
            name: 'RideRepository',
          );
          yield enriched;
        });
  }

  Future<RideModel> _enrichRideWithDriverProfile(RideModel ride) async {
    final driverId = ride.driverId;
    if (driverId == null || driverId.isEmpty) return ride;

    String? fullName;
    String? profilePicUrl;
    double? driverRating;
    String? carModel;
    String? carBrand;
    String? carPlate;
    try {
      final row = await _supabaseClient
          .from('profiles')
          .select(
            'full_name, profile_pic_url, driver_rating, car_model, car_brand, car_plate',
          )
          .eq('id', driverId)
          .maybeSingle();
      if (row != null) {
        final m = Map<String, dynamic>.from(row);
        fullName = m['full_name']?.toString();
        profilePicUrl = m['profile_pic_url']?.toString();
        final rawRating = m['driver_rating'];
        if (rawRating is num) {
          driverRating = rawRating.toDouble();
        } else if (rawRating != null) {
          driverRating = double.tryParse(rawRating.toString());
        }
        carModel = m['car_model']?.toString();
        carBrand = m['car_brand']?.toString();
        carPlate = m['car_plate']?.toString();
      }
    } catch (e, stack) {
      developer.log(
        '[NEGOTIATION_DEBUG] _enrichRideWithDriverProfile profiles error: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    var completedTrips = 0;
    try {
      final rows = await _supabaseClient
          .from('rides')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'finished');
      completedTrips = (rows as List<dynamic>).length;
    } catch (e, stack) {
      developer.log(
        '[NEGOTIATION_DEBUG] _enrichRideWithDriverProfile trips error: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    return RideModel(
      id: ride.id,
      clientId: ride.clientId,
      driverId: ride.driverId,
      originLat: ride.originLat,
      originLng: ride.originLng,
      destLat: ride.destLat,
      destLng: ride.destLng,
      originName: ride.originName,
      destName: ride.destName,
      status: ride.status,
      offeredPrice: ride.offeredPrice,
      finalPrice: ride.finalPrice,
      createdAt: ride.createdAt,
      driverLat: ride.driverLat,
      driverLng: ride.driverLng,
      paymentMethod: ride.paymentMethod,
      clientFirstName: ride.clientFirstName,
      clientCompletedTrips: ride.clientCompletedTrips,
      clientPassengerRating: ride.clientPassengerRating,
      clientProfilePicUrl: ride.clientProfilePicUrl,
      driverFullName: fullName,
      driverProfilePicUrl: profilePicUrl,
      driverRating: driverRating,
      driverCompletedTrips: completedTrips,
      driverCarModel: carModel,
      driverCarBrand: carBrand,
      driverCarPlate: carPlate,
    );
  }

  /// Perfil del pasajero para vistas del conductor (primer nombre desde `full_name`).
  Future<RideModel> _enrichRideWithClientProfile(RideModel ride) async {
    final clientId = ride.clientId.trim();
    if (clientId.isEmpty) return ride;

    String? fullNameRaw;
    String? picUrl;
    double? passengerRating = ride.clientPassengerRating;

    try {
      final row = await _supabaseClient
          .from('profiles')
          .select('full_name, profile_pic_url')
          .eq('id', clientId)
          .maybeSingle();
      if (row != null) {
        final m = Map<String, dynamic>.from(row);
        fullNameRaw = m['full_name']?.toString();
        final p = m['profile_pic_url']?.toString().trim();
        if (p != null && p.isNotEmpty) {
          picUrl = p;
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichRideWithClientProfile full_name: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    try {
      final row = await _supabaseClient
          .from('profiles')
          .select('passenger_rating')
          .eq('id', clientId)
          .maybeSingle();
      if (row != null) {
        final m = Map<String, dynamic>.from(row);
        final raw = m['passenger_rating'];
        if (raw != null) {
          passengerRating = raw is num
              ? raw.toDouble()
              : double.tryParse(raw.toString());
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichRideWithClientProfile passenger_rating (opcional): $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    final first = passengerFirstNameFromFullName(fullNameRaw);
    final mergedFirst =
        first.isNotEmpty ? first : ride.clientFirstName;

    return RideModel(
      id: ride.id,
      clientId: ride.clientId,
      driverId: ride.driverId,
      originLat: ride.originLat,
      originLng: ride.originLng,
      destLat: ride.destLat,
      destLng: ride.destLng,
      originName: ride.originName,
      destName: ride.destName,
      status: ride.status,
      offeredPrice: ride.offeredPrice,
      finalPrice: ride.finalPrice,
      createdAt: ride.createdAt,
      driverLat: ride.driverLat,
      driverLng: ride.driverLng,
      paymentMethod: ride.paymentMethod,
      clientFirstName: mergedFirst,
      clientCompletedTrips: ride.clientCompletedTrips,
      clientPassengerRating: passengerRating,
      clientProfilePicUrl: picUrl ?? ride.clientProfilePicUrl,
      driverFullName: ride.driverFullName,
      driverProfilePicUrl: ride.driverProfilePicUrl,
      driverRating: ride.driverRating,
      driverCompletedTrips: ride.driverCompletedTrips,
      driverCarModel: ride.driverCarModel,
      driverCarBrand: ride.driverCarBrand,
      driverCarPlate: ride.driverCarPlate,
    );
  }

  @override
  Future<RideEntity?> getRideById(String rideId) async {
    final row = await _supabaseClient
        .from('rides')
        .select()
        .eq('id', rideId)
        .maybeSingle();
    if (row == null) return null;
    final model = RideModel.fromJson(Map<String, dynamic>.from(row));
    return _enrichRideWithClientProfile(model);
  }

  @override
  Future<RideEntity?> getActiveRideByClientId(String clientId) async {
    final response = await _supabaseClient
        .from('rides')
        .select()
        .eq('client_id', clientId)
        .or(
          'status.eq.searching,status.eq.accepted,status.eq.negotiating,status.eq.arrived,status.eq.ongoing',
        )
        .order('created_at', ascending: false)
        .maybeSingle();

    if (response == null) return null;
    return RideModel.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<RideEntity?> getActiveRideByDriverId(String driverId) async {
    // Buscamos viajes donde el conductor ya esté asignado y el viaje no haya terminado
    final response = await _supabaseClient
        .from('rides')
        .select()
        .eq('driver_id', driverId)
        .or(
          'status.eq.accepted,status.eq.negotiating,status.eq.arrived,status.eq.ongoing',
        )
        .order('created_at', ascending: false)
        .maybeSingle();

    if (response == null) return null;
    return RideModel.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<RideEntity> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    final baseUrl = AppConstants.erpApiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const RideAcceptanceException(
        'No se configuró ERP_API_BASE_URL para aceptar viajes.',
      );
    }

    final uri = Uri.parse('$baseUrl/api/rides/$rideId/accept');
    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'driverId': driverId}),
    );

    if (response.statusCode == 200) {
      final latest = await getRideById(rideId);
      if (latest == null) {
        throw const RideAcceptanceException(
          'El viaje fue aceptado, pero no se pudo leer su estado actual.',
        );
      }
      return latest;
    }

    String backendMessage = 'No se pudo aceptar la solicitud.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final m = decoded['message'];
        if (m != null && m.toString().trim().isNotEmpty) {
          backendMessage = m.toString().trim();
        }
      }
    } catch (_) {}

    if (response.statusCode == 409) {
      throw const RideRequestExpiredException(
        'La solicitud ha expirado y fue cancelada automáticamente.',
      );
    }

    throw RideAcceptanceException(backendMessage);
  }

  @override
  Future<void> cancelRide(String rideId) async {
    developer.log(
      'cancelRide: inicio rideId=$rideId',
      name: 'RideRepository',
    );

    if (rideId.isEmpty || rideId == 'temporal') {
      developer.log(
        'cancelRide: rideId inválido (vacío o temporal) — no se llama a Supabase',
        name: 'RideRepository',
      );
      throw ArgumentError(
        'cancelRide: rideId debe ser el UUID persistido (no vacío ni temporal).',
      );
    }

    try {
      final response = await _supabaseClient
          .from('rides')
          .update({'status': 'cancelled'})
          .eq('id', rideId)
          .select('id');

      developer.log(
        'cancelRide: respuesta raw type=${response.runtimeType} '
        'value=$response',
        name: 'RideRepository',
      );

      final rows = List<Map<String, dynamic>>.from(response as List<dynamic>);
      if (rows.isEmpty) {
        developer.log(
          'cancelRide: 0 filas actualizadas — suele ser RLS o id inexistente. '
          'Revisa políticas UPDATE en rides para el rol del cliente.',
          name: 'RideRepository',
        );
        throw Exception(
          'No se actualizó ningún viaje: comprueba el id o permisos (RLS).',
        );
      }

      developer.log(
        'Supabase OK: rides.status=\'cancelled\' id=$rideId filas=${rows.length}',
        name: 'RideRepository',
      );
    } on PostgrestException catch (e, stack) {
      developer.log(
        'cancelRide PostgREST: ${e.message} '
        'code=${e.code} details=${e.details} hint=${e.hint}',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    } catch (e, stack) {
      developer.log(
        'cancelRide error inesperado: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  @override
  Future<void> updateRideStatus(
    String rideId,
    String status, {
    String? driverId,
    double? finalPrice,
    bool clearDriver = false,
  }) async {
    final updateData = <String, dynamic>{'status': status};

    if (clearDriver) {
      updateData['driver_id'] = null;
      updateData['final_price'] = null;
    } else {
      if (driverId != null) {
        updateData['driver_id'] = driverId;
      }
      if (finalPrice != null) {
        updateData['final_price'] = finalPrice;
      }
    }

    await _supabaseClient.from('rides').update(updateData).eq('id', rideId);
  }

  @override
  Future<void> updateDriverLocation(
    String rideId,
    double lat,
    double lng,
  ) async {
    await _supabaseClient.from('rides').update({
      'driver_lat': lat,
      'driver_lng': lng,
    }).eq('id', rideId);
  }

  @override
  Stream<List<RideEntity>> getNearbyRideRequests(
    double lat,
    double lng,
    double radiusInKm,
  ) {
    return _supabaseClient
        .from('rides')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .asyncMap((data) async {
          final list = List<Map<String, dynamic>>.from(data as List<dynamic>);
          final rides = list
              .map((json) => RideModel.fromJson(json))
              .where(
                (ride) =>
                    _approxDistanceInKm(
                      lat,
                      lng,
                      ride.originLat,
                      ride.originLng,
                    ) <=
                    radiusInKm,
              )
              .toList();
          return _enrichNearbyRidesForDriver(rides);
        });
  }

  /// Nombre (primer token de `full_name`), foto, rating y conteo de viajes del pasajero.
  Future<List<RideEntity>> _enrichNearbyRidesForDriver(
    List<RideModel> rides,
  ) async {
    if (rides.isEmpty) return const [];

    final ids = rides
        .map((r) => _profileMapKey(r.clientId))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return rides;

    final idToFullNameRaw = <String, String>{};
    final idToProfilePic = <String, String>{};
    final idToPassengerRating = <String, double>{};

    try {
      final profiles = await _supabaseClient
          .from('profiles')
          .select('id, full_name, profile_pic_url')
          .inFilter('id', ids);
      for (final row in profiles as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final id = _profileMapKey(m['id']?.toString());
        if (id.isEmpty) continue;
        idToFullNameRaw[id] = m['full_name']?.toString() ?? '';
        final pic = m['profile_pic_url']?.toString().trim();
        if (pic != null && pic.isNotEmpty) {
          idToProfilePic[id] = pic;
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichNearbyRidesForDriver profiles: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    try {
      final ratingRows = await _supabaseClient
          .from('profiles')
          .select('id, passenger_rating')
          .inFilter('id', ids);
      for (final row in ratingRows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final id = _profileMapKey(m['id']?.toString());
        final raw = m['passenger_rating'];
        if (id.isEmpty || raw == null) continue;
        final d =
            raw is num ? raw.toDouble() : double.tryParse(raw.toString());
        if (d != null) idToPassengerRating[id] = d;
      }
    } catch (e, stack) {
      developer.log(
        '_enrichNearbyRidesForDriver passenger_rating (opcional): $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    final tripCounts = {for (final id in ids) id: 0};
    try {
      final rows = await _supabaseClient
          .from('rides')
          .select('client_id')
          .inFilter('client_id', ids)
          .or('status.eq.finished,status.eq.completed');
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
        final cid = _profileMapKey(m['client_id']?.toString());
        if (cid.isNotEmpty) {
          tripCounts[cid] = (tripCounts[cid] ?? 0) + 1;
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichNearbyRidesForDriver tripCounts: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
      try {
        final rows = await _supabaseClient
            .from('rides')
            .select('client_id')
            .eq('status', 'finished')
            .inFilter('client_id', ids);
        for (final row in rows as List<dynamic>) {
          final m = Map<String, dynamic>.from(row as Map<dynamic, dynamic>);
          final cid = _profileMapKey(m['client_id']?.toString());
          if (cid.isNotEmpty) {
            tripCounts[cid] = (tripCounts[cid] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    return rides
        .map(
          (r) {
            final cid = _profileMapKey(r.clientId);
            final rawName = idToFullNameRaw[cid];
            final first = passengerFirstNameFromFullName(rawName);
            return RideModel(
              id: r.id,
              clientId: r.clientId,
              driverId: r.driverId,
              originLat: r.originLat,
              originLng: r.originLng,
              destLat: r.destLat,
              destLng: r.destLng,
              originName: r.originName,
              destName: r.destName,
              status: r.status,
              offeredPrice: r.offeredPrice,
              finalPrice: r.finalPrice,
              createdAt: r.createdAt,
              driverLat: r.driverLat,
              driverLng: r.driverLng,
              paymentMethod: r.paymentMethod,
              clientFirstName: first,
              clientCompletedTrips: tripCounts[cid] ?? 0,
              clientPassengerRating: idToPassengerRating[cid],
              clientProfilePicUrl: idToProfilePic[cid],
            );
          },
        )
        .toList();
  }

  /// Distancia aproximada en km (Haversine), misma lógica que en el flujo del cliente.
  double _approxDistanceInKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lng2 - lng1);

    final radLat1 = _degToRad(lat1);
    final radLat2 = _degToRad(lat2);

    final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(radLat1) *
            math.cos(radLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));

    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  @override
  Future<Map<String, dynamic>> getTodayDriverStats(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final response = await _supabaseClient
        .from('rides')
        .select('final_price')
        .eq('driver_id', driverId)
        .eq('status', 'finished')
        .gte('created_at', startOfDay.toIso8601String());

    final list = List<Map<String, dynamic>>.from(response as List<dynamic>);
    var sum = 0.0;
    for (final row in list) {
      final fp = row['final_price'];
      if (fp != null) {
        if (fp is num) {
          sum += fp.toDouble();
        } else {
          sum += double.parse(fp.toString());
        }
      }
    }

    return {
      'earnings': sum,
      'trips': list.length,
    };
  }

  @override
  Future<List<RideEntity>> getRideHistory(String userId, String role) async {
    if (userId.isEmpty) {
      return [];
    }

    final List<dynamic> response;
    if (role == 'client') {
      response = await _supabaseClient
          .from('rides')
          .select()
          .eq('client_id', userId)
          .order('created_at', ascending: false);
    } else if (role == 'driver') {
      response = await _supabaseClient
          .from('rides')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false);
    } else {
      throw ArgumentError('role debe ser client o driver');
    }

    final raw = List<Map<String, dynamic>>.from(response);
    final rides = <RideEntity>[];

    for (final row in raw) {
      try {
        rides.add(
          RideModel.fromJsonForHistory(
            Map<String, dynamic>.from(row),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return rides;
  }

  @override
  Stream<List<RideOfferEntity>> listenToRideOffers(
    String rideId, {
    bool pendingOnly = true,
  }) {
    if (rideId.isEmpty) {
      return Stream.value(const <RideOfferEntity>[]);
    }
    return _supabaseClient
        .from('ride_offers')
        .stream(primaryKey: const ['id'])
        .eq('ride_id', rideId)
        .asyncMap((raw) async {
          try {
            final list = List<Map<String, dynamic>>.from(raw as List<dynamic>);
            final models = list
                .map(
                  (row) => RideOfferModel.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList();
            final enriched = await _enrichRideOffers(models);
            enriched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            if (pendingOnly) {
              return enriched
                  .where((o) => o.isPending)
                  .map((e) => e as RideOfferEntity)
                  .toList();
            }
            return List<RideOfferEntity>.from(enriched);
          } catch (e, stack) {
            developer.log(
              'listenToRideOffers asyncMap: $e',
              name: 'RideRepository',
              error: e,
              stackTrace: stack,
            );
            rethrow;
          }
        });
  }

  @override
  Future<List<RideOfferEntity>> fetchPendingRideOffers(String rideId) async {
    if (rideId.isEmpty) return const [];
    final rows = await _supabaseClient
        .from('ride_offers')
        .select()
        .eq('ride_id', rideId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    final list = List<Map<String, dynamic>>.from(rows as List<dynamic>);
    final models = list
        .map((e) => RideOfferModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final enriched = await _enrichRideOffers(models);
    return List<RideOfferEntity>.from(enriched);
  }

  Future<List<RideOfferModel>> _enrichRideOffers(
    List<RideOfferModel> offers,
  ) async {
    if (offers.isEmpty) return offers;

    final driverIds = offers.map((o) => o.driverId.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (driverIds.isEmpty) return offers;

    final idToProfile = <String, Map<String, dynamic>>{};
    try {
      final rows = await _supabaseClient
          .from('profiles')
          .select(
            'id, full_name, profile_pic_url, driver_rating, car_model, car_brand, car_plate',
          )
          .inFilter('id', driverIds);
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = _profileMapKey(m['id']?.toString());
        if (id.isNotEmpty) {
          idToProfile[id] = m;
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichRideOffers profiles: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    final tripCounts = {for (final id in driverIds) _profileMapKey(id): 0};
    try {
      final rows = await _supabaseClient
          .from('rides')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .eq('status', 'finished');
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map);
        final did = _profileMapKey(m['driver_id']?.toString());
        if (did.isNotEmpty) {
          tripCounts[did] = (tripCounts[did] ?? 0) + 1;
        }
      }
    } catch (e, stack) {
      developer.log(
        '_enrichRideOffers tripCounts: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    return offers
        .map((o) {
          final dk = _profileMapKey(o.driverId);
          final p = idToProfile[dk];
          if (p == null) {
            return o.copyWithProfile(
              driverCompletedTrips: tripCounts[dk] ?? 0,
            );
          }
          final rawRating = p['driver_rating'];
          double? driverRating;
          if (rawRating is num) {
            driverRating = rawRating.toDouble();
          } else if (rawRating != null) {
            driverRating = double.tryParse(rawRating.toString());
          }
          return o.copyWithProfile(
            driverFullName: p['full_name']?.toString(),
            driverProfilePicUrl: p['profile_pic_url']?.toString(),
            driverRating: driverRating,
            driverCompletedTrips: tripCounts[dk] ?? 0,
            driverCarModel: p['car_model']?.toString(),
            driverCarBrand: p['car_brand']?.toString(),
            driverCarPlate: p['car_plate']?.toString(),
          );
        })
        .toList();
  }

  @override
  Future<RideOfferEntity> submitNegotiationOffer({
    required String rideId,
    required String driverId,
    required double offeredPrice,
  }) async {
    final row = <String, dynamic>{
      'ride_id': rideId,
      'driver_id': driverId,
      'offered_price': offeredPrice,
      'status': 'pending',
    };

    await _supabaseClient.from('ride_offers').upsert(
      row,
      onConflict: 'ride_id,driver_id',
    );

    final readBack = await _supabaseClient
        .from('ride_offers')
        .select()
        .eq('ride_id', rideId)
        .eq('driver_id', driverId)
        .eq('status', 'pending')
        .maybeSingle();

    if (readBack == null) {
      throw Exception('No se pudo registrar la oferta en ride_offers');
    }

    double readPrice(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    Map<String, dynamic> effective = Map<String, dynamic>.from(readBack);
    final priceFromRow = readPrice(effective['offered_price']);
    if ((priceFromRow - offeredPrice).abs() > 0.009) {
      await _supabaseClient.from('ride_offers').update({
        'offered_price': offeredPrice,
        'status': 'pending',
      }).eq('ride_id', rideId).eq('driver_id', driverId);
      final again = await _supabaseClient
          .from('ride_offers')
          .select()
          .eq('ride_id', rideId)
          .eq('driver_id', driverId)
          .eq('status', 'pending')
          .maybeSingle();
      if (again != null) {
        effective = Map<String, dynamic>.from(again);
      }
    }

    final model = RideOfferModel.fromJson(effective);
    final enriched = await _enrichRideOffers([model]);
    return enriched.first;
  }

  @override
  Future<void> withdrawRideOffer(String offerId) async {
    if (offerId.isEmpty) return;
    await _supabaseClient.from('ride_offers').update({
      'status': 'withdrawn',
    }).eq('id', offerId).eq('status', 'pending');
  }

  @override
  Future<void> rejectRideOffer(String offerId) async {
    if (offerId.isEmpty) return;
    await _supabaseClient.from('ride_offers').update({
      'status': 'rejected',
    }).eq('id', offerId).eq('status', 'pending');
  }

  @override
  Future<void> acceptRideOffer({
    required String offerId,
    required String rideId,
    required String driverId,
    required double finalPrice,
  }) async {
    try {
      await _supabaseClient.rpc(
        'accept_ride_offer',
        params: {
          'p_offer_id': offerId,
          'p_ride_id': rideId,
          'p_driver_id': driverId,
          'p_final_price': finalPrice,
        },
      );
      return;
    } on PostgrestException catch (e, stack) {
      developer.log(
        'accept_ride_offer RPC: ${e.message} code=${e.code} — intentando fallback',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    } catch (e, stack) {
      developer.log(
        'accept_ride_offer RPC error: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }

    await _acceptRideOfferSequential(
      offerId: offerId,
      rideId: rideId,
      driverId: driverId,
      finalPrice: finalPrice,
    );
  }

  Future<void> _acceptRideOfferSequential({
    required String offerId,
    required String rideId,
    required String driverId,
    required double finalPrice,
  }) async {
    await _supabaseClient.from('ride_offers').update({
      'status': 'accepted',
    }).eq('id', offerId).eq('ride_id', rideId).eq('driver_id', driverId).eq('status', 'pending');

    await _supabaseClient.from('ride_offers').update({
      'status': 'rejected',
    }).eq('ride_id', rideId).neq('id', offerId).eq('status', 'pending');

    await _supabaseClient.from('rides').update({
      'driver_id': driverId,
      'final_price': finalPrice,
      'status': 'accepted',
    }).eq('id', rideId).eq('status', 'searching');
  }

  @override
  Future<({RideEntity ride, RideOfferEntity offer})?>
      getPendingOfferContextForDriver(String driverId) async {
    final trimmed = driverId.trim();
    if (trimmed.isEmpty) return null;

    try {
      final rows = await _supabaseClient
          .from('ride_offers')
          .select()
          .eq('driver_id', trimmed)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map);
        final rid = m['ride_id']?.toString() ?? '';
        if (rid.isEmpty) continue;
        final ride = await getRideById(rid);
        if (ride != null && ride.status == 'searching') {
          final model = RideOfferModel.fromJson(m);
          final enriched = await _enrichRideOffers([model]);
          return (ride: ride, offer: enriched.first);
        }
      }
    } catch (e, stack) {
      developer.log(
        'getPendingOfferContextForDriver: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
    }
    return null;
  }

  @override
  Future<int> getRideViewersCount(String rideId) async {
    if (rideId.isEmpty) return 0;
    try {
      final rows = await _supabaseClient
          .from('ride_offers')
          .select('driver_id')
          .eq('ride_id', rideId);
      final list = rows as List<dynamic>;
      final distinct = <String>{};
      for (final row in list) {
        final m = Map<String, dynamic>.from(row as Map);
        final did = m['driver_id']?.toString().trim() ?? '';
        if (did.isNotEmpty) distinct.add(did);
      }
      return distinct.length;
    } catch (e, stack) {
      developer.log(
        'getRideViewersCount: $e',
        name: 'RideRepository',
        error: e,
        stackTrace: stack,
      );
      return 0;
    }
  }

  @override
  Future<void> updateOfferedPrice(String rideId, double newPrice) async {
    if (rideId.isEmpty) return;
    await _supabaseClient
        .from('rides')
        .update({'offered_price': newPrice})
        .eq('id', rideId);
  }
}
