import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/ride_offer_entity.dart';
import 'vehicle_category_card.dart';

/// Datos de la oferta de un conductor tal como los muestra
/// [DriverOfferPanel]. Puede venir de una oferta real ([fromEntity]) o de
/// una de demostración ([isDemo]).
class DriverOfferView {
  const DriverOfferView({
    required this.offerId,
    required this.driverId,
    required this.driverName,
    required this.price,
    this.photoUrl,
    this.rating,
    this.completedTrips = 0,
    this.carDescription,
    this.isDemo = false,
  });

  factory DriverOfferView.fromEntity(RideOfferEntity offer) {
    final car = [offer.driverCarBrand, offer.driverCarModel]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(' ');
    final plate = offer.driverCarPlate?.trim() ?? '';
    final description = [car, plate].where((p) => p.isNotEmpty).join(' · ');
    final name = offer.driverFullName?.trim() ?? '';
    return DriverOfferView(
      offerId: offer.id,
      driverId: offer.driverId,
      driverName: name.isEmpty ? 'Conductor' : name,
      price: offer.offeredPrice,
      photoUrl: offer.driverProfilePicUrl,
      rating: offer.driverRating,
      completedTrips: offer.driverCompletedTrips,
      carDescription: description.isEmpty ? null : description,
    );
  }

  final String offerId;
  final String driverId;
  final String driverName;

  /// Precio que propone el conductor.
  final double price;
  final String? photoUrl;
  final double? rating;
  final int completedTrips;

  /// Marca, modelo y placa, p. ej. «Toyota Corolla · T1A-234».
  final String? carDescription;

  /// true = oferta simulada, sin conductor real detrás.
  final bool isDemo;
}

/// Contenido del panel inferior cuando un conductor envía una oferta: foto,
/// etiqueta de verificado, nombre, estrellas y viajes; su vehículo; la
/// contraoferta (con el precio del pasajero tachado) y los botones de
/// rechazar y aceptar.
class DriverOfferPanel extends StatelessWidget {
  const DriverOfferPanel({
    super.key,
    required this.offer,
    required this.passengerPrice,
    required this.vehicle,
    required this.onAccept,
    required this.onReject,
    this.isBusy = false,
  });

  final DriverOfferView offer;

  /// Precio que ofreció el pasajero.
  final double passengerPrice;

  /// Categoría elegida al pedir el viaje: el vehículo mostrado coincide
  /// con ella.
  final VehicleCategoryOption vehicle;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  /// true mientras se procesa la respuesta: los botones no responden.
  final bool isBusy;

  static const Color _blue = AppTheme.primaryBlue;
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF888888);
  static const Color _verifiedGreen = Color(0xFF00AA44);
  static const Color _rejectRed = Color(0xFFFF4444);
  static const Color _starYellow = Color(0xFFFFB800);

  @override
  Widget build(BuildContext context) {
    // Hay contraoferta si el conductor propone un precio distinto.
    final isCounterOffer = (offer.price - passengerPrice).abs() > 0.009;
    final rating = offer.rating;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tiempo para decidir: al llegar a 0 la oferta se rechaza sola. La
        // clave reinicia la cuenta con cada oferta nueva.
        _OfferCountdown(
          key: ValueKey(offer.offerId),
          // Mientras se procesa una respuesta no se rechaza por tiempo.
          onExpired: isBusy ? null : onReject,
        ),
        const SizedBox(height: 12),

        // Conductor
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DriverPhoto(url: offer.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _verifiedGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: _verifiedGreen,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Conductor verificado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _verifiedGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          offer.driverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: _blue, size: 16),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (rating != null) ...[
                        for (var i = 0; i < 5; i++)
                          Icon(
                            i < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: _starYellow,
                            size: 14,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '·',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '${offer.completedTrips} viajes',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Vehículo (misma categoría elegida al pedir el viaje)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEFF)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 44,
                child: Image.asset(
                  vehicle.image,
                  fit: BoxFit.contain,
                  cacheWidth: 300,
                  errorBuilder: (_, __, ___) =>
                      Icon(vehicle.icon, size: 30, color: vehicle.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.carDescription ?? vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Categoría ${vehicle.name}',
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Precio: contraoferta del conductor o aceptación del precio
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCounterOffer
                        ? 'Contraoferta del conductor'
                        : 'El conductor aceptó tu oferta',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  if (isCounterOffer) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tu oferta: S/ ${passengerPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _muted,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'S/ ${offer.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _blue,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Rechazar / Aceptar
        Opacity(
          opacity: isBusy ? 0.5 : 1,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: isBusy ? null : onReject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _rejectRed, width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'Rechazar',
                        style: TextStyle(
                          color: _rejectRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: isBusy ? null : onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x440066CC),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Aceptar S/ ${offer.price.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Foto circular del conductor; sin URL (o si falla la carga) muestra un
/// ícono de persona.
class _DriverPhoto extends StatelessWidget {
  const _DriverPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.person_rounded,
      color: AppTheme.primaryBlue,
      size: 34,
    );
    final photoUrl = url?.trim() ?? '';
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEEF5FF),
        border: Border.all(color: AppTheme.primaryBlue, width: 2),
      ),
      child: photoUrl.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

/// Cuenta regresiva de una oferta: segundos restantes y una barra que baja
/// de forma continua (azul, naranja con 5 s o menos y roja con 2 s o menos).
/// Al terminar llama a [onExpired] una sola vez.
class _OfferCountdown extends StatefulWidget {
  const _OfferCountdown({super.key, required this.onExpired});

  /// `null` = por ahora no se rechaza al vencer (p. ej. aceptando).
  final VoidCallback? onExpired;

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 10;

  static const Color _blue = Color(0xFF0066CC);
  static const Color _orange = Color(0xFFFF8C00);
  static const Color _red = Color(0xFFFF4444);

  late final AnimationController _countdownCtrl;

  @override
  void initState() {
    super.initState();
    _countdownCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )
      ..addStatusListener((status) {
        // El estado «completed» llega una sola vez: no se rechaza dos veces.
        if (status == AnimationStatus.completed && mounted) {
          widget.onExpired?.call();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _countdownCtrl.dispose();
    super.dispose();
  }

  /// Fracción que queda, de 1 a 0.
  double get _remaining => 1.0 - _countdownCtrl.value;

  int get _secondsLeft =>
      (_remaining * _totalSeconds).ceil().clamp(0, _totalSeconds);

  Color get _timerColor {
    final remaining = _remaining;
    if (remaining > 0.5) return _blue; // más de 5 s
    if (remaining > 0.2) return _orange; // más de 2 s
    return _red;
  }

  @override
  Widget build(BuildContext context) {
    // Solo se redibuja la cuenta en cada cuadro, no todo el panel.
    return AnimatedBuilder(
      animation: _countdownCtrl,
      builder: (context, _) {
        final color = _timerColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tiempo para decidir',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
                Text(
                  '$_secondsLeft s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _remaining,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }
}
