import 'package:flutter/material.dart';

/// Rutas del flujo de pedido que se apilan sobre el dashboard (pago →
/// vehículo → búsqueda de conductor). Todas comparten nombre para poder
/// cerrarlas juntas sin depender de cuántas haya ni de qué hay debajo.
const String kRideFlowRouteName = 'ride-flow';

/// Crea una ruta del flujo de pedido.
MaterialPageRoute<T> rideFlowRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    settings: const RouteSettings(name: kRideFlowRouteName),
    builder: builder,
  );
}

/// Cierra todas las pantallas del flujo de pedido y deja a la vista el
/// dashboard. No hace nada si ya no queda ninguna.
void closeRideFlow(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) => route.settings.name != kRideFlowRouteName,
  );
}
