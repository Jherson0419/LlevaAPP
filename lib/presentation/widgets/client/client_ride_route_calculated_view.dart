import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

class ClientRideRouteCalculatedView extends StatefulWidget {
  final double distance;
  final double suggestedPrice;
  final String origin;
  final String destination;

  const ClientRideRouteCalculatedView({
    super.key,
    required this.distance,
    required this.suggestedPrice,
    required this.origin,
    required this.destination,
  });

  @override
  State<ClientRideRouteCalculatedView> createState() =>
      _ClientRideRouteCalculatedViewState();
}

class _ClientRideRouteCalculatedViewState
    extends State<ClientRideRouteCalculatedView> {
  final TextEditingController _offerController = TextEditingController();
  final FocusNode _offerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Establecer el precio sugerido como valor inicial
    _offerController.text = widget.suggestedPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _offerController.dispose();
    _offerFocusNode.dispose();
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
          
          // Información de la ruta
          Row(
            children: [
              const Icon(
                Icons.route,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.distance.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.origin} → ${widget.destination}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Precio sugerido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Precio sugerido',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkTextSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppConstants.currencySymbol} ${widget.suggestedPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Campo de contraoferta
          TextField(
            controller: _offerController,
            focusNode: _offerFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Tu oferta',
              hintText: 'Ingresa tu precio',
              prefixText: '${AppConstants.currencySymbol} ',
              prefixStyle: const TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            style: const TextStyle(
              color: AppTheme.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          
          // Botón Solicitar viaje
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final offerPrice = double.tryParse(_offerController.text);
                if (offerPrice != null && offerPrice > 0) {
                  context.read<ClientRideBloc>().add(
                        SubmitOffer(offerPrice: offerPrice),
                      );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un precio válido'),
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
                'Solicitar viaje',
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
