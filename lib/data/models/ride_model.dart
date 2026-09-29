import '../../domain/entities/ride_entity.dart';

/// Modelo de datos que extiende RideEntity.
///
/// Se encarga de la serialización/deserialización de datos
/// que provienen de PostgreSQL (vía Supabase).
class RideModel extends RideEntity {
  const RideModel({
    required super.id,
    required super.clientId,
    super.driverId,
    required super.originLat,
    required super.originLng,
    required super.destLat,
    required super.destLng,
    required super.originName,
    required super.destName,
    required super.status,
    required super.offeredPrice,
    super.finalPrice,
    required super.createdAt,
    super.driverLat,
    super.driverLng,
    super.paymentMethod,
    super.clientFirstName,
    super.clientCompletedTrips,
    super.clientPassengerRating,
    super.clientProfilePicUrl,
    super.driverFullName,
    super.driverProfilePicUrl,
    super.driverRating,
    super.driverCompletedTrips,
    super.driverCarModel,
    super.driverCarBrand,
    super.driverCarPlate,
  });

  /// Crea una instancia de RideModel desde un Map JSON.
  ///
  /// Maneja la conversión segura de tipos numéricos y fechas
  /// que pueden venir como diferentes tipos desde PostgreSQL.
  /// Fila de Supabase con posibles nulos (viajes antiguos o incompletos).
  factory RideModel.fromJsonForHistory(Map<String, dynamic> json) {
    String str(dynamic key, [String fallback = '—']) {
      final v = json[key];
      if (v == null) return fallback;
      final t = v.toString().trim();
      return t.isEmpty ? fallback : t;
    }

    double coord(dynamic key, double fallback) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    double offered(dynamic key) {
      final v = json[key];
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final id = str('id', '');
    final clientId = str('client_id', '');

    return RideModel(
      id: id.isEmpty ? 'unknown' : id,
      clientId: clientId.isEmpty ? 'unknown' : clientId,
      driverId: json['driver_id']?.toString(),
      originLat: coord('origin_lat', 0),
      originLng: coord('origin_lng', 0),
      destLat: coord('dest_lat', 0),
      destLng: coord('dest_lng', 0),
      originName: str('origin_name', 'Origen no disponible'),
      destName: str('dest_name', 'Destino no disponible'),
      status: str('status', 'unknown'),
      offeredPrice: offered('offered_price'),
      finalPrice: json['final_price'] != null
          ? _parseNullableDouble(json['final_price'])
          : null,
      createdAt: _parseDateTimeLoose(json['created_at']),
      driverLat: _parseNullableDouble(json['driver_lat']),
      driverLng: _parseNullableDouble(json['driver_lng']),
      paymentMethod: _parsePaymentMethod(json['payment_method']),
      clientFirstName: json['client_first_name']?.toString() ?? '',
      clientCompletedTrips: _parseIntLoose(json['client_completed_trips']),
      clientPassengerRating: _parseNullableDouble(json['passenger_rating']),
      clientProfilePicUrl: json['client_profile_pic_url']?.toString(),
      driverFullName: json['driver_full_name']?.toString(),
      driverProfilePicUrl: json['driver_profile_pic_url']?.toString(),
      driverRating: _parseNullableDouble(json['driver_rating']),
      driverCompletedTrips: _parseIntLoose(json['driver_completed_trips']),
      driverCarModel: json['driver_car_model']?.toString(),
      driverCarBrand: json['driver_car_brand']?.toString(),
      driverCarPlate: json['driver_car_plate']?.toString(),
    );
  }

  static String _parsePaymentMethod(dynamic value) {
    if (value == null) return 'efectivo';
    final s = value.toString().trim().toLowerCase();
    return s.isEmpty ? 'efectivo' : s;
  }

  static int _parseIntLoose(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _parseDateTimeLoose(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    if (value is int) {
      if (value.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      driverId: json['driver_id'] as String?,
      originLat: _parseDouble(json['origin_lat']),
      originLng: _parseDouble(json['origin_lng']),
      destLat: _parseDouble(json['dest_lat']),
      destLng: _parseDouble(json['dest_lng']),
      originName: json['origin_name'] as String,
      destName: json['dest_name'] as String,
      status: json['status'] as String,
      offeredPrice: _parseDouble(json['offered_price']),
      finalPrice: json['final_price'] != null
          ? _parseDouble(json['final_price'])
          : null,
      createdAt: _parseDateTime(json['created_at']),
      driverLat: _parseNullableDouble(json['driver_lat']),
      driverLng: _parseNullableDouble(json['driver_lng']),
      paymentMethod: _parsePaymentMethod(json['payment_method']),
      clientFirstName: json['client_first_name']?.toString() ?? '',
      clientCompletedTrips: _parseIntLoose(json['client_completed_trips']),
      clientPassengerRating: _parseNullableDouble(json['passenger_rating']),
      clientProfilePicUrl: json['client_profile_pic_url']?.toString(),
      driverFullName: json['driver_full_name']?.toString(),
      driverProfilePicUrl: json['driver_profile_pic_url']?.toString(),
      driverRating: _parseNullableDouble(json['driver_rating']),
      driverCompletedTrips: _parseIntLoose(json['driver_completed_trips']),
      driverCarModel: json['driver_car_model']?.toString(),
      driverCarBrand: json['driver_car_brand']?.toString(),
      driverCarPlate: json['driver_car_plate']?.toString(),
    );
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Convierte la instancia a un Map JSON para enviar a PostgreSQL.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'client_id': clientId,
      'driver_id': driverId,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'origin_name': originName,
      'dest_name': destName,
      'status': status,
      'offered_price': offeredPrice,
      'final_price': finalPrice,
      'created_at': createdAt.toUtc().toIso8601String(),
      'payment_method': paymentMethod,
    };

    // Solo enviamos el ID si es un UUID real; para 'temporal'
    // dejamos que PostgreSQL genere el valor por defecto.
    if (id != 'temporal' && id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  /// Convierte un valor dinámico a double de forma segura.
  ///
  /// Maneja casos donde PostgreSQL puede retornar int o double.
  static double _parseDouble(dynamic value) {
    if (value == null) {
      throw ArgumentError(
          'El valor no puede ser null para campos double requeridos');
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.parse(value);
    }
    throw ArgumentError(
        'No se puede convertir $value (${value.runtimeType}) a double');
  }

  /// Convierte un valor dinámico a DateTime de forma segura.
  ///
  /// Maneja diferentes formatos de fecha que pueden venir de PostgreSQL.
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      throw ArgumentError(
          'El valor no puede ser null para campos DateTime requeridos');
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    if (value is int) {
      // Maneja timestamps Unix (segundos o milisegundos)
      if (value.toString().length == 10) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      } else {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }
    throw ArgumentError(
        'No se puede convertir $value (${value.runtimeType}) a DateTime');
  }
}
