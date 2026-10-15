import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/vehicle_category_helper.dart';
import '../../bloc/driver_profile/driver_profile_cubit.dart';

const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);

/// Nivel del conductor: insignia actual, avance al siguiente nivel,
/// calificación y beneficios. Espera un [DriverProfileCubit] provisto.
class DriverLevelScreen extends StatelessWidget {
  const DriverLevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kTextDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mi nivel',
          style: TextStyle(
            color: _kTextDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocBuilder<DriverProfileCubit, DriverProfileState>(
        builder: (context, state) {
          if (state.isLoading && state.totalTrips == 0) {
            return const Center(child: CircularProgressIndicator());
          }
          final level = VehicleCategoryHelper.getLevel(state.totalTrips);
          final progress = level.progressFor(state.totalTrips);
          final remaining = level.remainingFor(state.totalTrips);
          final atLeast = level.index;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Insignia del nivel actual
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: level.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(level.icon, color: Colors.white, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        'Nivel ${level.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        state.totalTrips == 1
                            ? '1 viaje completado'
                            : '${state.totalTrips} viajes completados',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Avance al siguiente nivel
                if (!level.isMax) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EEFF)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Próximo nivel: ${level.nextLevelName}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _kTextDark,
                                ),
                              ),
                            ),
                            Text(
                              remaining == 1
                                  ? '1 viaje restante'
                                  : '$remaining viajes restantes',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFEEEEEE),
                            valueColor: AlwaysStoppedAnimation(level.color),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${state.totalTrips}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: level.color,
                              ),
                            ),
                            Text(
                              '${level.nextLevelTrips}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Calificación
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0F0F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB800),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calificación actual',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kTextMuted,
                              ),
                            ),
                            Text(
                              state.rating != null
                                  ? '${state.rating!.toStringAsFixed(1)} / 5.0'
                                  : 'Aún sin calificaciones',
                              style: TextStyle(
                                fontSize: state.rating != null ? 22 : 16,
                                fontWeight: FontWeight.w700,
                                color: _kTextDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Beneficios
                const Text(
                  'Beneficios de tu nivel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                const _BenefitItem(
                  icon: Icons.check_circle_rounded,
                  color: Color(0xFF00AA44),
                  title: 'Acceso a la plataforma',
                  subtitle: 'Disponible en todos los niveles',
                ),
                if (atLeast >= DriverLevel.platinum.index)
                  const _BenefitItem(
                    icon: Icons.star_rounded,
                    color: Color(0xFF0066CC),
                    title: 'Prioridad en solicitudes',
                    subtitle:
                        'Recibes solicitudes antes que conductores básicos',
                    comingSoon: true,
                  ),
                if (atLeast >= DriverLevel.gold.index)
                  const _BenefitItem(
                    icon: Icons.verified_rounded,
                    color: Color(0xFFFFB800),
                    title: 'Insignia Verificado Oro',
                    subtitle: 'Los pasajeros ven tu verificación premium',
                    comingSoon: true,
                  ),
                if (level.isMax)
                  const _BenefitItem(
                    icon: Icons.diamond_rounded,
                    color: Color(0xFF00D4FF),
                    title: 'Insignia Diamante',
                    subtitle: 'Máximo nivel de confianza y visibilidad',
                    comingSoon: true,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.comingSoon = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// true = beneficio anunciado que la app aún no aplica.
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kTextDark,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Próximamente',
                          style: TextStyle(fontSize: 9, color: _kTextMuted),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
