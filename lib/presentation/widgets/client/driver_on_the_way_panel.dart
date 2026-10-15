import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'vehicle_category_card.dart';

/// Contenido del panel inferior cuando el conductor ya fue aceptado y va
/// hacia el pasajero: título con el tiempo estimado y barra de avance, datos
/// del conductor y de su vehículo, monto aprobado y acciones (llamar,
/// mensaje, cancelar).
class DriverOnTheWayPanel extends StatelessWidget {
  const DriverOnTheWayPanel({
    super.key,
    required this.driverName,
    required this.etaLabel,
    required this.progress,
    required this.vehicle,
    required this.approvedAmount,
    required this.onCall,
    required this.onMessage,
    this.onCancel,
    this.onComing,
    this.title,
    this.subtitle,
    this.comingAnnounced = false,
    this.photoUrl,
    this.rating,
    this.carModel,
    this.plate,
    this.arrived = false,
    this.waitRemaining = Duration.zero,
    this.waitTotal = const Duration(minutes: 5),
  });

  final String driverName;

  /// Tiempo estimado de llegada, p. ej. «3 min».
  final String etaLabel;

  /// Avance del conductor hacia el punto de recojo, de 0 a 1.
  final double progress;

  /// Categoría del vehículo elegida al pedir el viaje.
  final VehicleCategoryOption vehicle;
  final double approvedAmount;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  /// `null` = sin botón «Cancelar» (el viaje ya no se puede cancelar).
  final VoidCallback? onCancel;
  final String? photoUrl;
  final double? rating;
  final String? carModel;
  final String? plate;

  /// true cuando el conductor ya llegó al punto de recojo. Desde entonces
  /// la barra muestra la espera: [waitRemaining] de [waitTotal], bajando.
  final bool arrived;
  final Duration waitRemaining;
  final Duration waitTotal;

  /// «Ya voy»: el pasajero avisa al conductor que está saliendo.
  /// `null` = sin botón.
  final VoidCallback? onComing;

  /// Reemplazan el título y la descripción propios de «va hacia ti» /
  /// «llegó» (p. ej. durante el trayecto al destino).
  final String? title;
  final String? subtitle;

  /// true si ya se envió ese aviso: el botón queda como confirmación.
  final bool comingAnnounced;

  static const Color _waitOrange = Color(0xFFFF8F00);
  static const Color _blue = AppTheme.primaryBlue;
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF888888);
  static const Color _green = Color(0xFF00AA44);
  static const Color _cancelRed = Color(0xFFFF4444);
  static const Color _starYellow = Color(0xFFFFB800);

  String get _firstName {
    final trimmed = driverName.trim();
    return trimmed.isEmpty ? 'Tu conductor' : trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final rating = this.rating;
    final plate = this.plate?.trim() ?? '';
    final accent = arrived ? _waitOrange : _blue;
    // Con el conductor esperando, la barra es la cuenta regresiva.
    final waitFraction = waitTotal.inSeconds <= 0
        ? 0.0
        : waitRemaining.inSeconds / waitTotal.inSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título + tiempo estimado
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? (arrived ? '¡Tu conductor llegó!' : 'Llega pronto'),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ??
                        (arrived
                            ? (waitRemaining > Duration.zero
                                ? '$_firstName te espera en el punto de recojo'
                                : 'Se agotó el tiempo de espera')
                            : '$_firstName va hacia ti'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    arrived
                        ? Icons.hourglass_bottom_rounded
                        : Icons.access_time_rounded,
                    color: accent,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    arrived ? _formatCountdown(waitRemaining) : etaLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // En camino: avance de izquierda a derecha con un auto en la punta.
        // Esperando: cuenta regresiva que se va vaciando.
        _TripProgressBar(
          value: arrived ? waitFraction : progress,
          color: accent,
          showCar: !arrived,
        ),
        const SizedBox(height: 14),

        // Conductor
        Row(
          children: [
            _Photo(url: photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          driverName,
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
                  if (rating != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
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
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vehículo + monto aprobado
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
                width: 72,
                height: 44,
                child: Image.asset(
                  vehicle.image,
                  fit: BoxFit.contain,
                  cacheWidth: 300,
                  errorBuilder: (_, __, ___) =>
                      Icon(vehicle.icon, size: 30, color: vehicle.accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carModel ?? vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    if (plate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCCCCCC)),
                        ),
                        child: Text(
                          plate,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Monto aprobado',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                  Text(
                    'S/ ${approvedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Llamar · Mensaje · Cancelar
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.call_rounded,
                label: 'Llamar',
                color: _green,
                onTap: onCall,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.chat_bubble_rounded,
                label: 'Mensaje',
                color: _blue,
                onTap: onMessage,
              ),
            ),
            if (onCancel != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Cancelar',
                  color: _cancelRed,
                  onTap: onCancel!,
                ),
              ),
            ],
          ],
        ),
        // «Ya voy»: avisa al conductor que el pasajero está saliendo. Solo
        // tiene sentido cuando el conductor ya llegó.
        if (arrived && onComing != null) ...[
          const SizedBox(height: 12),
          _buildComingButton(),
        ],
      ],
    );
  }

  Widget _buildComingButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: comingAnnounced ? null : onComing,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: comingAnnounced
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: comingAnnounced ? _green.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  comingAnnounced
                      ? Icons.check_circle_rounded
                      : Icons.directions_walk_rounded,
                  color: comingAnnounced ? _green : Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  comingAnnounced ? 'Avisaste que ya sales' : 'Ya voy',
                  style: TextStyle(
                    color: comingAnnounced ? _green : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Cuenta regresiva como «m:ss».
  static String _formatCountdown(Duration remaining) {
    final seconds = remaining.inSeconds.clamp(0, 5999);
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}

/// Barra de avance con esquinas redondeadas. Con [showCar], un auto pequeño
/// viaja en la punta del tramo recorrido.
class _TripProgressBar extends StatelessWidget {
  const _TripProgressBar({
    required this.value,
    required this.color,
    required this.showCar,
  });

  final double value;
  final Color color;
  final bool showCar;

  static const double _barHeight = 8;
  static const double _carSize = 22;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    return SizedBox(
      height: _carSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // El auto no se sale por los extremos de la barra.
          final carLeft =
              (width * fraction - _carSize / 2).clamp(0.0, width - _carSize);
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF7),
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
              ),
              Container(
                height: _barHeight,
                width: width * fraction,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                ),
              ),
              if (showCar)
                Positioned(
                  left: carLeft,
                  child: Container(
                    width: _carSize,
                    height: _carSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: color,
                      size: 13,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto circular del conductor; sin URL (o si falla la carga) muestra un
/// ícono de persona.
class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.person_rounded,
      color: AppTheme.primaryBlue,
      size: 30,
    );
    final photoUrl = url?.trim() ?? '';
    return Container(
      width: 52,
      height: 52,
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
