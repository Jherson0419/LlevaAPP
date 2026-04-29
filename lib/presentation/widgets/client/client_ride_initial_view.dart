import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

class ClientRideInitialView extends StatelessWidget {
  const ClientRideInitialView({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<ClientRideBloc>().add(const StartSearch());
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface, // #1A1A1A
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Ícono de ubicación izquierdo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF162A35), // Azul muy oscuro/verdoso
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppTheme.primaryBlue, // #00D4FF
                size: 28,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Textos en el centro
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿A dónde vamos?',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ingresa tu destino',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Botón de búsqueda derecho
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue, // #00D4FF
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.search,
                color: Colors.black,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
