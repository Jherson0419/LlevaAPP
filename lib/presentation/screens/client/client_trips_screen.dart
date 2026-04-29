import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class ClientTripsScreen extends StatelessWidget {
  const ClientTripsScreen({super.key});

  // Datos simulados de viajes
  final List<Map<String, dynamic>> _trips = const [
    {
      'date': '15 Mar 2024',
      'time': '14:30',
      'origin': 'Plaza de Armas',
      'destination': 'Mall Aventura Plaza',
      'price': 12.00,
    },
    {
      'date': '12 Mar 2024',
      'time': '09:15',
      'origin': 'Universidad Nacional',
      'destination': 'Centro Histórico',
      'price': 10.50,
    },
    {
      'date': '10 Mar 2024',
      'time': '18:45',
      'origin': 'Real Plaza',
      'destination': 'Aeropuerto',
      'price': 25.00,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mis Viajes'),
      ),
      body: SafeArea(
        child: _trips.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: AppTheme.darkTextSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes viajes aún',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _trips.length,
                itemBuilder: (context, index) {
                  final trip = _trips[index];
                  return _buildTripCard(context, trip);
                },
              ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha y hora
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.darkTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${trip['date']} • ${trip['time']}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.darkTextSecondary,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${AppConstants.currencySymbol} ${trip['price'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Origen
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trip['origin'],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Línea conectora
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              width: 2,
              height: 20,
              color: AppTheme.darkTextSecondary.withOpacity(0.3),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Destino
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.successGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trip['destination'],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w600,
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
