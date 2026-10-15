import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/custom_map_markers.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

/// Mapa de solo lectura con la ruta del viaje, el origen (verde) y el
/// destino (azul), encuadrado para que se vea el trayecto completo. No
/// admite gestos. Lee el viaje del [ClientRideBloc] del contexto.
///
/// - Con [height] es una tarjeta de ese alto, con borde y esquinas
///   redondeadas (vista previa del paso de pago).
/// - Sin [height] llena el espacio disponible, sin marco (fondo de la
///   pantalla de búsqueda de conductor).
///
/// [mapPadding] reserva las zonas tapadas por otros elementos, para que la
/// ruta se encuadre en la parte que queda a la vista.
class RoutePreviewMap extends StatefulWidget {
  const RoutePreviewMap({
    super.key,
    this.height,
    this.mapPadding = EdgeInsets.zero,
    this.focusOrigin = false,
    this.recenterToken = 0,
    this.originZoom = defaultOriginZoom,
    this.driverLatLng,
    this.fitToDriver = false,
    this.showDestination = true,
  });

  /// false = no se dibujan el destino ni la ruta (p. ej. mientras se busca
  /// conductor solo importa el punto de recojo). El viaje los conserva.
  final bool showDestination;

  /// Posición del conductor del viaje: se dibuja como un auto.
  final LatLng? driverLatLng;

  /// true = en vez de la ruta completa, la cámara encuadra el origen y el
  /// conductor ([driverLatLng]), y se va acercando conforme él llega. Sin
  /// posición del conductor se encuadra la ruta.
  final bool fitToDriver;

  final double? height;
  final EdgeInsets mapPadding;

  /// Al cambiar de valor, la cámara vuelve a su posición (encuadre de la
  /// ruta o, con [focusOrigin], el origen). Sirve para un botón «mi
  /// ubicación».
  final int recenterToken;

  /// true = en vez de encuadrar la ruta, la cámara se centra en el origen
  /// (que queda en el centro de la zona libre de [mapPadding]) y no se
  /// dibuja su marcador: quien usa el mapa pone ahí su propio indicador.
  final bool focusOrigin;

  /// Zoom de la cámara con [focusOrigin]. Al cambiar, la cámara se acerca
  /// o aleja con una animación, sin moverse del origen.
  final double originZoom;

  static const double defaultOriginZoom = 15.5;

  @override
  State<RoutePreviewMap> createState() => _RoutePreviewMapState();
}

class _RoutePreviewMapState extends State<RoutePreviewMap> {
  static const double _fitPadding = 32;

  /// Espacio extra arriba para el cuerpo de los pines: el encuadre se hace
  /// por su punta y, sin esto, un pin en el borde superior quedaría cortado.
  static const double _pinHeadroom = 40;

  /// Con el conductor a menos de esta distancia del origen, la cámara usa
  /// [_closeZoom] en lugar de encuadrar los dos puntos.
  static const double _closeDistanceMeters = 250;
  static const double _closeZoom = 17;

  GoogleMapController? _controller;
  String? _mapStyle;
  BitmapDescriptor? _carIcon;

  /// Pines «gota» de origen (azul) y destino (rojo), los mismos del mapa de
  /// la búsqueda. Se generan una sola vez para todas las vistas previas.
  static Future<BitmapDescriptor>? _originPinFuture;
  static Future<BitmapDescriptor>? _destPinFuture;
  BitmapDescriptor? _originPinIcon;
  BitmapDescriptor? _destPinIcon;

  @override
  void initState() {
    super.initState();
    CustomMapMarkers.createCarMarker().then((icon) {
      if (!mounted) return;
      setState(() => _carIcon = icon);
    }).catchError((_) {});
    _originPinFuture ??= CustomMapMarkers.createPinMarker();
    _destPinFuture ??= CustomMapMarkers.createPinMarker(
      color: CustomMapMarkers.destPinColor,
    );
    _originPinFuture!.then((icon) {
      if (mounted) setState(() => _originPinIcon = icon);
    }).catchError((_) {});
    _destPinFuture!.then((icon) {
      if (mounted) setState(() => _destPinIcon = icon);
    }).catchError((_) {});
    // Mismo estilo que el mapa del dashboard.
    rootBundle.loadString('assets/map_style.json').then((style) {
      if (!mounted) return;
      setState(() => _mapStyle = style);
    }).catchError((_) {});
  }

  /// Acerca o aleja la cámara al nuevo [RoutePreviewMap.originZoom], con
  /// animación y sin moverla del origen.
  Future<void> _animateOriginZoom() async {
    final controller = _controller;
    final origin = context.read<ClientRideBloc>().state.originLatLng;
    if (controller == null || origin == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(origin, widget.originZoom),
      );
    } catch (_) {
      // Error transitorio de plataforma: el siguiente paso lo corrige.
    }
  }

  @override
  void didUpdateWidget(covariant RoutePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusOrigin && oldWidget.originZoom != widget.originZoom) {
      _animateOriginZoom();
    }
    if (oldWidget.driverLatLng != widget.driverLatLng ||
        oldWidget.fitToDriver != widget.fitToDriver) {
      // El conductor se movió (o cambió la etapa): la cámara lo sigue.
      _fitRoute(context.read<ClientRideBloc>().state, animate: true);
    }
    if (oldWidget.mapPadding != widget.mapPadding ||
        oldWidget.focusOrigin != widget.focusOrigin ||
        oldWidget.recenterToken != widget.recenterToken) {
      // La zona visible cambió: se vuelve a colocar la cámara cuando el
      // mapa ya aplicó el nuevo padding.
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _fitRoute(context.read<ClientRideBloc>().state);
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Encuadra la ruta completa (o, si aún no hay trazo, origen y destino).
  /// Con [RoutePreviewMap.fitToDriver] encuadra el origen y el conductor.
  Future<void> _fitRoute(ClientRideState state, {bool animate = false}) async {
    final controller = _controller;
    final origin = state.originLatLng;
    final dest = state.destLatLng;
    if (controller == null || origin == null || dest == null) return;

    Future<void> go(CameraUpdate update) => animate
        ? controller.animateCamera(update)
        : controller.moveCamera(update);

    if (widget.focusOrigin) {
      try {
        await go(CameraUpdate.newLatLngZoom(origin, widget.originZoom));
      } catch (_) {
        // Queda la cámara inicial, ya centrada en el origen.
      }
      return;
    }

    final driver = widget.driverLatLng;
    final List<LatLng> points;
    if (widget.fitToDriver && driver != null) {
      final apart = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        driver.latitude,
        driver.longitude,
      );
      if (apart < _closeDistanceMeters) {
        // Ya está al lado: un encuadre de dos puntos casi iguales acercaría
        // la cámara al máximo, así que se fija un zoom de calle.
        try {
          await go(
            CameraUpdate.newLatLngZoom(
              LatLng(
                (origin.latitude + driver.latitude) / 2,
                (origin.longitude + driver.longitude) / 2,
              ),
              _closeZoom,
            ),
          );
        } catch (_) {}
        return;
      }
      points = [origin, driver];
    } else {
      points = [
        origin,
        dest,
        ...state.routePolyline,
        if (driver != null) driver,
      ];
    }

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    try {
      await go(CameraUpdate.newLatLngBounds(bounds, _fitPadding));
    } catch (_) {
      // El mapa aún no terminó de medirse: queda la cámara inicial,
      // centrada entre origen y destino.
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    // En Android el encuadre falla si el mapa todavía no tiene tamaño.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await _fitRoute(context.read<ClientRideBloc>().state);
  }

  @override
  Widget build(BuildContext context) {
    final framed = widget.height != null;
    return BlocConsumer<ClientRideBloc, ClientRideState>(
      listenWhen: (p, c) =>
          p.originLatLng != c.originLatLng ||
          p.destLatLng != c.destLatLng ||
          p.routePolyline != c.routePolyline,
      listener: (context, state) => _fitRoute(state),
      buildWhen: (p, c) =>
          p.originLatLng != c.originLatLng ||
          p.destLatLng != c.destLatLng ||
          p.routePolyline != c.routePolyline,
      builder: (context, state) {
        final origin = state.originLatLng;
        final dest = state.destLatLng;
        final driver = widget.driverLatLng;
        if (origin == null || dest == null) {
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: framed ? BorderRadius.circular(14) : null,
            ),
            child: const Center(
              child: Icon(
                Icons.map_outlined,
                color: Color(0xFFCCCCCC),
                size: 48,
              ),
            ),
          );
        }

        final map = AbsorbPointer(
          child: GoogleMap(
            // Sin edificios 3D: al acercar se dibujan con lados sombreados
            // oscuros que rompen el estilo claro.
            buildingsEnabled: false,
            initialCameraPosition: widget.focusOrigin
                ? CameraPosition(
                    target: origin,
                    zoom: widget.originZoom,
                  )
                : CameraPosition(
                    target: LatLng(
                      (origin.latitude + dest.latitude) / 2,
                      (origin.longitude + dest.longitude) / 2,
                    ),
                    zoom: 13.0,
                  ),
            style: _mapStyle,
            padding: widget.focusOrigin
                ? widget.mapPadding
                : widget.mapPadding + const EdgeInsets.only(top: _pinHeadroom),
            markers: {
              if (!widget.focusOrigin)
                Marker(
                  markerId: const MarkerId('origin'),
                  position: origin,
                  anchor: const Offset(0.5, 1.0),
                  icon: _originPinIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                ),
              if (driver != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driver,
                  anchor: _carIcon != null
                      ? const Offset(0.5, 0.5)
                      : const Offset(0.5, 1.0),
                  icon: _carIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                ),
              if (widget.showDestination)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: dest,
                  anchor: const Offset(0.5, 1.0),
                  icon: _destPinIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                ),
            },
            // Mismo trazo que el mapa de la búsqueda: halo translúcido
            // debajo y línea azul encima.
            polylines: {
              if (widget.showDestination && state.routePolyline.length > 1) ...{
                Polyline(
                  polylineId: const PolylineId('route_shadow'),
                  points: state.routePolyline,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  width: 12,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                  zIndex: 1,
                ),
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: state.routePolyline,
                  color: AppTheme.primaryBlue,
                  width: 6,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                  zIndex: 2,
                ),
              },
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: _onMapCreated,
          ),
        );
        if (!framed) return map;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: map,
          ),
        );
      },
    );
  }
}
