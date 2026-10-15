import 'package:flutter/material.dart';

import '../../../core/enums/client_vehicle_category.dart';

/// Datos de presentación de una categoría de vehículo.
class VehicleCategoryOption {
  const VehicleCategoryOption({
    required this.category,
    required this.icon,
    required this.name,
    required this.image,
    required this.gradient,
    required this.accent,
  });

  final ClientVehicleCategory category;
  final IconData icon;
  final String name;

  /// Ruta del PNG del vehículo en assets/images/.
  final String image;
  final List<Color> gradient;

  /// Color de borde, íconos y precio de la tarjeta.
  final Color accent;
}

/// Las cuatro categorías, en el orden en que se muestran.
const List<VehicleCategoryOption> kVehicleCategoryOptions = [
  VehicleCategoryOption(
    category: ClientVehicleCategory.standard,
    icon: Icons.directions_car_rounded,
    name: 'Estándar',
    image: 'assets/images/Estándar.png',
    gradient: [Color(0xFFE8F4FF), Color(0xFFD0E8FF)],
    accent: Color(0xFF0066CC),
  ),
  VehicleCategoryOption(
    category: ClientVehicleCategory.comfort,
    icon: Icons.car_rental_rounded,
    name: 'Confort',
    image: 'assets/images/Confort.png',
    gradient: [Color(0xFFF0E8FF), Color(0xFFE0D0FF)],
    accent: Color(0xFF7B2FBE),
  ),
  VehicleCategoryOption(
    category: ClientVehicleCategory.xl,
    icon: Icons.airport_shuttle_rounded,
    name: 'XL',
    image: 'assets/images/XL.png',
    gradient: [Color(0xFFE8FFF0), Color(0xFFD0F0E0)],
    accent: Color(0xFF1A8A4A),
  ),
  VehicleCategoryOption(
    category: ClientVehicleCategory.moto,
    icon: Icons.two_wheeler_rounded,
    name: 'Moto',
    image: 'assets/images/Moto.png',
    gradient: [Color(0xFFFFF0E8), Color(0xFFFFDDCC)],
    accent: Color(0xFFE05A00),
  ),
];

/// Tarjeta de categoría de vehículo (degradado pastel, cabecera con ícono,
/// nombre y precio, foto del vehículo). La usan la cuadrícula del inicio del
/// dashboard y el paso de vehículo.
///
/// Con [isSelected] lleva borde del color de la categoría y un check en lugar
/// de la flecha.
class VehicleCategoryCard extends StatelessWidget {
  const VehicleCategoryCard({
    super.key,
    required this.option,
    required this.priceLabel,
    required this.onTap,
    this.isSelected = false,
  });

  final VehicleCategoryOption option;

  /// Texto bajo el nombre, p. ej. «Desde S/ 8.5» o «S/ 12.50».
  final String priceLabel;
  final VoidCallback onTap;
  final bool isSelected;

  static const Color _textDark = Color(0xFF1A1A1A);
  static const double _padding = 10;

  /// Alto de la fila de cabecera (lo fija el recuadro del ícono: 22 + 2·7).
  static const double _headerHeight = 36;

  /// Separación mínima de la imagen respecto a la cabecera y los bordes.
  static const double _imageGap = 4;

  @override
  Widget build(BuildContext context) {
    final accent = option.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: option.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          // Siempre 2 px (transparente si no está elegida) para que la
          // tarjeta no cambie de tamaño al seleccionarla.
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Imagen del vehículo, completa (sin recortes) y pegada a la
            // derecha: su alto va desde donde termina la cabecera hasta el
            // borde inferior, con una separación mínima; el ancho sale de la
            // proporción de cada foto.
            Positioned(
              right: _imageGap,
              top: _padding + _headerHeight + _imageGap,
              bottom: _imageGap,
              child: Image.asset(
                option.image,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                // Los PNG originales miden hasta 2048 px; se decodifican
                // cerca del tamaño en que se muestran.
                cacheWidth: 360,
                // Si el asset falta, queda el ícono de la categoría.
                errorBuilder: (_, __, ___) => Icon(
                  option.icon,
                  size: 38,
                  color: accent.withValues(alpha: 0.7),
                ),
              ),
            ),

            // Cabecera: ícono, tipo + precio, flecha (o check si está elegida)
            Positioned(
              left: _padding,
              right: _padding,
              top: _padding,
              height: _headerHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(option.icon, size: 22, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          option.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        // En pantallas angostas el precio se encoge en vez
                        // de cortarse.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent
                          : accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 14,
                      color: isSelected ? Colors.white : accent,
                    ),
                  ),
                ],
              ),
            ),

            // Tiempo estimado, abajo a la izquierda
            Positioned(
              left: _padding,
              bottom: _padding,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF666666),
                      size: 12,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '~4 min',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
