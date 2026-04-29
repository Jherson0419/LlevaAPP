import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

class ClientRideSearchingView extends StatefulWidget {
  const ClientRideSearchingView({super.key});

  @override
  State<ClientRideSearchingView> createState() => _ClientRideSearchingViewState();
}

class _ClientRideSearchingViewState extends State<ClientRideSearchingView> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
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
            'Ingresa tu ruta',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          
          // Campo Origen
          TextField(
            controller: _originController,
            focusNode: _originFocusNode,
            decoration: InputDecoration(
              labelText: 'Origen',
              hintText: '¿Dónde estás?',
              prefixIcon: const Icon(
                Icons.radio_button_checked,
                color: AppTheme.primaryBlue,
              ),
            ),
            style: const TextStyle(color: AppTheme.darkText),
          ),
          const SizedBox(height: 16),
          
          // Campo Destino
          TextField(
            controller: _destinationController,
            focusNode: _destinationFocusNode,
            decoration: InputDecoration(
              labelText: 'Destino',
              hintText: '¿A dónde vas?',
              prefixIcon: const Icon(
                Icons.location_on,
                color: AppTheme.primaryBlue,
              ),
            ),
            style: const TextStyle(color: AppTheme.darkText),
          ),
          const SizedBox(height: 24),
          
          // Botón Calcular Tarifa
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_originController.text.isNotEmpty &&
                    _destinationController.text.isNotEmpty) {
                  context.read<ClientRideBloc>().add(
                        CalculateRoute(
                          origin: _originController.text,
                          destination: _destinationController.text,
                        ),
                      );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor completa ambos campos'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Calcular Tarifa',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
