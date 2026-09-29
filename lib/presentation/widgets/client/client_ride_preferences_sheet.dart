import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

/// Abre la hoja de preferencias del viaje (compartida entre paneles del cliente).
void showClientRidePreferencesSheet(
  BuildContext context,
  ClientRideState state,
) {
  final rideBloc = context.read<ClientRideBloc>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
        ),
        child: _RidePreferencesSheetBody(
          rideBloc: rideBloc,
          initialComments: state.rideComments,
        ),
      );
    },
  );
}

WidgetStateProperty<Color> _ridePrefSwitchThumbColor() {
  return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
    if (states.contains(WidgetState.selected)) {
      return Colors.black;
    }
    return const Color(0xFFBDBDBD);
  });
}

class _RidePreferencesSheetBody extends StatefulWidget {
  const _RidePreferencesSheetBody({
    required this.rideBloc,
    required this.initialComments,
  });

  final ClientRideBloc rideBloc;
  final String initialComments;

  @override
  State<_RidePreferencesSheetBody> createState() =>
      _RidePreferencesSheetBodyState();
}

class _RidePreferencesSheetBodyState extends State<_RidePreferencesSheetBody> {
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.initialComments);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.darkSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: BlocBuilder<ClientRideBloc, ClientRideState>(
        bloc: widget.rideBloc,
        builder: (context, st) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Preferencias del viaje',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El conductor verá esta información al aceptar tu solicitud. '
                  'La tarifa se ajusta un poco si activas ciertas opciones.',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Más de 4 pasajeros',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Somos un grupo grande y necesitamos más espacio.',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: st.moreThanFourPassengers,
                  activeTrackColor: AppTheme.primaryBlue,
                  thumbColor: _ridePrefSwitchThumbColor(),
                  onChanged: (v) => widget.rideBloc.add(
                    RidePreferencesChanged(moreThanFourPassengers: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Silla de bebé',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Necesito asiento infantil o base para bebé.',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: st.babySeat,
                  activeTrackColor: AppTheme.primaryBlue,
                  thumbColor: _ridePrefSwitchThumbColor(),
                  onChanged: (v) =>
                      widget.rideBloc.add(RidePreferencesChanged(babySeat: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Llevo una mascota',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Viajo con un animal (indica detalles en comentarios).',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: st.pet,
                  activeTrackColor: AppTheme.primaryBlue,
                  thumbColor: _ridePrefSwitchThumbColor(),
                  onChanged: (v) =>
                      widget.rideBloc.add(RidePreferencesChanged(pet: v)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Comentarios',
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF141414),
                    hintText:
                        'Ej.: portón negro, referencia, tipo de mascota…',
                    hintStyle: const TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () {
                    widget.rideBloc.add(
                      RidePreferencesChanged(
                        rideComments: _notesCtrl.text,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
