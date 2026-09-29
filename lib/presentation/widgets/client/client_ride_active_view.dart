import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

class ClientRideActiveView extends StatelessWidget {
  final String driverName;
  final String vehicleModel;
  final String licensePlate;
  final String phoneNumber;

  const ClientRideActiveView({
    super.key,
    required this.driverName,
    required this.vehicleModel,
    required this.licensePlate,
    required this.phoneNumber,
  });

  void _callDriver(BuildContext context, String phone) {
    // Copiar número al portapapeles y mostrar mensaje
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Número copiado: $phone'),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle del draggable sheet
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.darkTextSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Título
          Text(
            'Viaje confirmado',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.successGreen,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          
          // Tarjeta del conductor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Avatar del conductor
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nombre del conductor
                Text(
                  driverName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                
                // Información del vehículo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car,
                      color: AppTheme.darkTextSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      vehicleModel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Placa: $licensePlate',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Botones de acción
          Row(
            children: [
              // Botón Llamar
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _callDriver(context, phoneNumber),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Llamar',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Botón Cancelar
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    developer.log(
                      'ClientRideActiveView: Cancelar → add(CancelRide)',
                      name: 'ClientUI',
                    );
                    context.read<ClientRideBloc>().add(const CancelRide());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.close, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Cancelar',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
