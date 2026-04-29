import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/enums/client_ride_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';

class SearchLocationPanel extends StatelessWidget {
  const SearchLocationPanel({
    super.key,
    required this.originController,
    required this.destController,
    required this.originFocusNode,
    required this.destFocusNode,
    required this.state,
  });

  final TextEditingController originController;
  final TextEditingController destController;
  final FocusNode originFocusNode;
  final FocusNode destFocusNode;
  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            height: 4,
            width: 48,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (state.status == ClientRideStatus.error &&
            state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            style: const TextStyle(
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: originController,
          focusNode: originFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppTheme.darkSurface,
            prefixIcon: Icon(Icons.my_location, color: AppTheme.primaryBlue),
            hintText: 'Punto de recojo',
            hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            rideBloc.add(OriginTextChanged(value));
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: destController,
          focusNode: destFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppTheme.darkSurface,
            prefixIcon: Icon(Icons.place, color: AppTheme.primaryBlue),
            hintText: '¿A dónde vas?',
            hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) {
            rideBloc.add(DestTextChanged(value));
          },
        ),
        if (state.originPredictions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sugerencias (origen)',
            style: TextStyle(
              color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(
            state.originPredictions.length,
            (index) {
              final p = state.originPredictions[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.location_on,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                title: Text(
                  p.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  originController.text = p.description;
                  rideBloc.add(OriginSelected(p.placeId, p.description));
                },
              );
            },
          ),
        ],
        if (state.destPredictions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sugerencias (destino)',
            style: TextStyle(
              color: AppTheme.darkTextSecondary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(
            state.destPredictions.length,
            (index) {
              final p = state.destPredictions[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.flag,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                title: Text(
                  p.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  destController.text = p.description;
                  rideBloc.add(DestSelected(p.placeId, p.description));
                },
              );
            },
          ),
        ],
      ],
    );
  }
}
