import '../../domain/entities/user.dart';
import '../../domain/entities/document_review_status.dart';

/// Modelo de datos para la tabla `profiles` de Supabase.
///
/// Se encarga de la serialización/deserialización entre JSON y [UserEntity].
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phone,
    required super.role,
    super.isDriverApplicant = false,
    required super.fullName,
    super.email,
    super.dni,
    super.carPlate,
    super.carBrand,
    super.carModel,
    super.isApproved = true,
    super.isBanned = false,
    super.carYear,
    super.carColor,
    super.soatExpiration,
    super.propertyCardExpiration,
    super.technicalReviewExpiration,
    super.licenseCategory,
    super.licenseNumber,
    super.birthDate,
    super.dniFrontUrl,
    super.dniBackUrl,
    super.licenseUrl,
    super.soatUrl,
    super.propertyCardUrl,
    super.profilePicUrl,
    super.dniFrontStatus = 'PENDING',
    super.dniBackStatus = 'PENDING',
    super.licenseStatus = 'PENDING',
    super.soatStatus = 'PENDING',
    super.propertyCardStatus = 'PENDING',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final docs = _extractDocumentPayload(json);
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      isDriverApplicant: _parseBool(json['is_driver_applicant'], false),
      fullName: json['full_name'] as String,
      email: json['email']?.toString(),
      dni: json['dni']?.toString(),
      carPlate: json['car_plate']?.toString(),
      carBrand: json['car_brand']?.toString(),
      carModel: json['car_model']?.toString(),
      isApproved: _parseBool(json['is_approved'], false),
      isBanned: _parseBool(json['is_banned'], false),
      carYear: _parseNullableInt(json['car_year']),
      carColor: json['car_color']?.toString(),
      soatExpiration: _parseNullableDateTime(json['soat_expiration']),
      propertyCardExpiration:
          _parseNullableDateTime(json['property_card_expiration']),
      technicalReviewExpiration:
          _parseNullableDateTime(json['technical_review_expiration']),
      licenseCategory: json['license_category']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      birthDate: _parseNullableDateTime(json['birth_date']),
      dniFrontUrl: _firstNonEmptyString([
        docs['dni_front_url'],
        docs['dniFrontUrl'],
        json['dni_front_url'],
        json['dniFrontUrl'],
      ]),
      dniBackUrl: _firstNonEmptyString([
        docs['dni_back_url'],
        docs['dniBackUrl'],
        json['dni_back_url'],
        json['dniBackUrl'],
      ]),
      licenseUrl: _firstNonEmptyString([
        docs['license_url'],
        docs['licenseUrl'],
        json['license_url'],
        json['licenseUrl'],
      ]),
      soatUrl: _firstNonEmptyString([
        docs['soat_url'],
        docs['soatUrl'],
        json['soat_url'],
        json['soatUrl'],
      ]),
      propertyCardUrl: _firstNonEmptyString([
        docs['property_card_url'],
        docs['propertyCardUrl'],
        json['property_card_url'],
        json['propertyCardUrl'],
      ]),
      profilePicUrl: json['profile_pic_url']?.toString(),
      dniFrontStatus: _parseStatus(_firstNonEmptyString([
        docs['dni_front_status'],
        docs['dniFrontStatus'],
        json['dni_front_status'],
        json['dniFrontStatus'],
      ])),
      dniBackStatus: _parseStatus(_firstNonEmptyString([
        docs['dni_back_status'],
        docs['dniBackStatus'],
        json['dni_back_status'],
        json['dniBackStatus'],
      ])),
      licenseStatus: _parseStatus(_firstNonEmptyString([
        docs['license_status'],
        docs['licenseStatus'],
        json['license_status'],
        json['licenseStatus'],
      ])),
      soatStatus: _parseStatus(_firstNonEmptyString([
        docs['soat_status'],
        docs['soatStatus'],
        json['soat_status'],
        json['soatStatus'],
      ])),
      propertyCardStatus: _parseStatus(_firstNonEmptyString([
        docs['property_card_status'],
        docs['propertyCardStatus'],
        json['property_card_status'],
        json['propertyCardStatus'],
      ])),
    );
  }

  static Map<String, dynamic> _extractDocumentPayload(Map<String, dynamic> json) {
    final raw = json['driver_documents'] ?? json['driverDocuments'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String _parseStatus(dynamic value) {
    return DocumentReviewStatus.fromRaw(value).value;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final s = value.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    if (value is num) return value != 0;
    return defaultValue;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'phone': phone,
      'role': role,
      'is_driver_applicant': isDriverApplicant,
      'full_name': fullName,
      'email': email,
      'dni': dni,
      'car_plate': carPlate,
      'car_brand': carBrand,
      'car_model': carModel,
      'is_approved': isApproved,
      'is_banned': isBanned,
      'car_year': carYear,
      'car_color': carColor,
      'soat_expiration': soatExpiration?.toUtc().toIso8601String(),
      'property_card_expiration':
          propertyCardExpiration?.toUtc().toIso8601String(),
      'technical_review_expiration':
          technicalReviewExpiration?.toUtc().toIso8601String(),
      'license_category': licenseCategory,
      'license_number': licenseNumber,
      'birth_date': birthDate?.toUtc().toIso8601String(),
      'dni_front_url': dniFrontUrl,
      'dni_back_url': dniBackUrl,
      'license_url': licenseUrl,
      'soat_url': soatUrl,
      'property_card_url': propertyCardUrl,
      'profile_pic_url': profilePicUrl,
      'dni_front_status': dniFrontStatus,
      'dni_back_status': dniBackStatus,
      'license_status': licenseStatus,
      'soat_status': soatStatus,
      'property_card_status': propertyCardStatus,
    };

    if (id != 'temporal' && id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? role,
    bool? isDriverApplicant,
    String? fullName,
    String? email,
    String? dni,
    String? carPlate,
    String? carBrand,
    String? carModel,
    bool? isApproved,
    bool? isBanned,
    int? carYear,
    String? carColor,
    DateTime? soatExpiration,
    DateTime? propertyCardExpiration,
    DateTime? technicalReviewExpiration,
    String? licenseCategory,
    String? licenseNumber,
    DateTime? birthDate,
    String? dniFrontUrl,
    String? dniBackUrl,
    String? licenseUrl,
    String? soatUrl,
    String? propertyCardUrl,
    String? profilePicUrl,
    String? dniFrontStatus,
    String? dniBackStatus,
    String? licenseStatus,
    String? soatStatus,
    String? propertyCardStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isDriverApplicant: isDriverApplicant ?? this.isDriverApplicant,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      dni: dni ?? this.dni,
      carPlate: carPlate ?? this.carPlate,
      carBrand: carBrand ?? this.carBrand,
      carModel: carModel ?? this.carModel,
      isApproved: isApproved ?? this.isApproved,
      isBanned: isBanned ?? this.isBanned,
      carYear: carYear ?? this.carYear,
      carColor: carColor ?? this.carColor,
      soatExpiration: soatExpiration ?? this.soatExpiration,
      propertyCardExpiration:
          propertyCardExpiration ?? this.propertyCardExpiration,
      technicalReviewExpiration:
          technicalReviewExpiration ?? this.technicalReviewExpiration,
      licenseCategory: licenseCategory ?? this.licenseCategory,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      birthDate: birthDate ?? this.birthDate,
      dniFrontUrl: dniFrontUrl ?? this.dniFrontUrl,
      dniBackUrl: dniBackUrl ?? this.dniBackUrl,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      soatUrl: soatUrl ?? this.soatUrl,
      propertyCardUrl: propertyCardUrl ?? this.propertyCardUrl,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      dniFrontStatus: _parseStatus(dniFrontStatus ?? this.dniFrontStatus),
      dniBackStatus: _parseStatus(dniBackStatus ?? this.dniBackStatus),
      licenseStatus: _parseStatus(licenseStatus ?? this.licenseStatus),
      soatStatus: _parseStatus(soatStatus ?? this.soatStatus),
      propertyCardStatus:
          _parseStatus(propertyCardStatus ?? this.propertyCardStatus),
    );
  }
}
