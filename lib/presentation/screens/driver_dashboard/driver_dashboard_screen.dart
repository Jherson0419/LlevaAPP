import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/passenger_name_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/custom_map_markers.dart';
import '../../../core/utils/location_helper.dart';
import '../../../data/datasources/remote/directions_service.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/driver_stats/driver_stats_cubit.dart';
import '../../bloc/driver_stats/driver_stats_state.dart';
import '../../bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../bloc/driver_status/driver_status_bloc.dart';
import '../../bloc/driver_status/driver_status_event.dart';
import '../../bloc/driver_status/driver_status_state.dart';
import '../../widgets/driver/driver_drawer.dart';
import '../../widgets/driver/driver_negotiating_card.dart';
import '../../widgets/ride_destination_display.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  static const Duration _requestExpiry = Duration(minutes: 15);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ValueNotifier<int> _requestClockSec =
      ValueNotifier<int>(DateTime.now().millisecondsSinceEpoch ~/ 1000);
  Timer? _requestClockTimer;

  GoogleMapController? _mapController;
  String? _mapError;
  
  // Control de pestañas
  int _currentTabIndex = 0;
  
  // Ubicación actual del conductor
  Position? _currentPosition;
  
  // Marcadores y polylines del mapa
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _negotiatingAnimToken = 0;
  String? _lastNegotiatingAnimatedRideId;
  
  // Servicio de direcciones
  final DirectionsService _directionsService = DirectionsService();

  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destIcon;

  @override
  void initState() {
    super.initState();
    _requestClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _requestClockSec.value = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const RefreshProfileEvent());
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        context.read<DriverStatsCubit>().loadTodayStats(auth.user.id);
        context.read<DriverWalletCubit>().loadWallet(auth.user.id);
        context
            .read<DriverStatusBloc>()
            .add(RecoverDriverActiveRide(auth.user.id));
      }
      _loadCustomMapIcons(context);
    });
  }

  Future<void> _loadCustomMapIcons(BuildContext context) async {
    BitmapDescriptor? car;
    BitmapDescriptor? origin;
    BitmapDescriptor? dest;
    try {
      car = await CustomMapMarkers.createDriverCarMarker();
    } catch (_) {}
    try {
      origin = await CustomMapMarkers.createOriginMarker();
    } catch (_) {}
    try {
      dest = await CustomMapMarkers.createDestMarker();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _carIcon = car;
      _originIcon = origin;
      _destIcon = dest;
      _upsertDriverLocationMarker();
    });
    _redrawActiveRouteIfAny();
  }

  void _upsertDriverLocationMarker() {
    if (_currentPosition == null || _carIcon == null) return;
    _markers.removeWhere((m) => m.markerId == const MarkerId('driver_location'));
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_location'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        icon: _carIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndex: 1000,
      ),
    );
  }

  void _redrawActiveRouteIfAny() {
    if (!mounted) return;
    final s = context.read<DriverStatusBloc>().state;
    if (s is DriverNegotiating || s is DriverWaitingForPassengerDecision) {
      final r = s is DriverNegotiating
          ? (s as DriverNegotiating).activeRide
          : (s as DriverWaitingForPassengerDecision).activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
        animateNegotiatingEntry: true,
        rideIdForAnimation: r.id,
      );
    } else if (s is DriverOnTrip) {
      final r = s.activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
      );
    } else if (s is DriverArrivedAtPickup) {
      final r = s.activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
      );
    } else if (s is DriverTripInProgress) {
      final r = s.activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
      );
    }
  }

  @override
  void dispose() {
    _requestClockTimer?.cancel();
    _requestClockSec.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _setMapStyle();
    setState(() {
      _mapError = null;
    });

    // Obtener ubicación real del dispositivo
    try {
      final position = await LocationHelper.determinePosition();
      setState(() {
        _currentPosition = position;
        _upsertDriverLocationMarker();
      });

      // Centrar el mapa en la ubicación actual
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _setMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map_style.json');
      await _mapController?.setMapStyle(style);
    } catch (_) {
      // Si falla la carga, el mapa usa el estilo por defecto.
    }
  }

  /// ETA aproximada en minutos (velocidad media 30 km/h).
  int _etaMinutesFromKm(double distanceKm) {
    return (distanceKm / 30.0 * 60.0).ceil().clamp(1, 999);
  }

  String _formatDistanceSmart(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Muestra la ruta en el mapa con marcadores y polyline
  /// Obtiene la ruta real usando Google Maps Directions API
  Future<void> _showRouteOnMap(
    LatLng origin,
    LatLng destination, {
    bool animateNegotiatingEntry = false,
    String? rideIdForAnimation,
  }) async {
    final shouldAnimateNegotiatingEntry =
        animateNegotiatingEntry &&
        rideIdForAnimation != null &&
        _lastNegotiatingAnimatedRideId != rideIdForAnimation;
    if (shouldAnimateNegotiatingEntry) {
      _lastNegotiatingAnimatedRideId = rideIdForAnimation;
    }
    final kmOriginToDest =
        LocationHelper.calculateDistance(origin, destination);

    LatLng? driver;
    double? kmDriverToOrigin;
    if (_currentPosition != null) {
      driver = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      kmDriverToOrigin = LocationHelper.calculateDistance(driver, origin);
    }

    final originTitle = kmDriverToOrigin != null
        ? '${_etaMinutesFromKm(kmDriverToOrigin)} min'
        : 'Recojo';
    final originDistanceLine2 = kmDriverToOrigin != null
        ? _formatDistanceSmart(kmDriverToOrigin)
        : '---';

    final totalKmToDestination =
        kmOriginToDest + (kmDriverToOrigin ?? 0);
    final destTitle = '${_etaMinutesFromKm(totalKmToDestination)} min';
    final destDistanceLine2 = _formatDistanceSmart(totalKmToDestination);
    BitmapDescriptor? originDistanceBadge;
    BitmapDescriptor? destinationDistanceBadge;
    try {
      originDistanceBadge = await CustomMapMarkers.createDistanceBadgeMarker(
        line1: originTitle,
        line2: originDistanceLine2,
      );
    } catch (_) {}
    try {
      destinationDistanceBadge = await CustomMapMarkers.createDistanceBadgeMarker(
        line1: destTitle,
        line2: destDistanceLine2,
      );
    } catch (_) {}

    setState(() {
      _markers.clear();
      _polylines.clear();
      _upsertDriverLocationMarker();

      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(origin.latitude, origin.longitude),
          icon: _originIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: originTitle,
            snippet: 'Hasta punto de recojo',
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: destTitle,
            snippet: 'Origen → destino',
          ),
        ),
      );

      if (originDistanceBadge != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('origin_distance_badge'),
            position: origin,
            icon: originDistanceBadge,
            anchor: const Offset(0.5, 1.0),
            zIndex: 998,
          ),
        );
      }
      if (destinationDistanceBadge != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination_distance_badge'),
            position: destination,
            icon: destinationDistanceBadge,
            anchor: const Offset(0.5, 1.0),
            zIndex: 998,
          ),
        );
      }

      if (driver != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_to_origin'),
            points: [driver, origin],
            color: const Color(0xFF32D74B),
            width: 4,
            geodesic: true,
          ),
        );
      }
    });

    // Intentar obtener la ruta real de Google Maps
    try {
      final routePoints = await _directionsService.getRouteCoordinates(
        origin,
        destination,
        AppConstants.googleMapsApiKey,
      );

      if (routePoints.isNotEmpty) {
        if (shouldAnimateNegotiatingEntry) {
          await _animateNegotiatingRouteProgress(origin, routePoints);
        } else {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: const Color(0xFF00D4FF), // Azul eléctrico de la app
                width: 5,
                geodesic: true,
              ),
            );
          });
          _adjustCameraToFitRoute(routePoints);
        }
      } else {
        _drawStraightLine(origin, destination);
      }
    } catch (e) {
      print('Error al obtener la ruta: $e');
      _drawStraightLine(origin, destination);
    }
  }

  Future<void> _animateNegotiatingRouteProgress(
    LatLng origin,
    List<LatLng> routePoints,
  ) async {
    if (_mapController == null || routePoints.length < 2) {
      _drawStraightLine(origin, routePoints.isNotEmpty ? routePoints.last : origin);
      return;
    }

    final animToken = ++_negotiatingAnimToken;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: origin, zoom: 16.7),
        ),
      );
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted || animToken != _negotiatingAnimToken) return;

    const totalFrames = 24;
    final step = (routePoints.length / totalFrames).ceil().clamp(1, routePoints.length);
    for (int i = step; i <= routePoints.length; i += step) {
      if (!mounted || animToken != _negotiatingAnimToken) return;
      final end = i > routePoints.length ? routePoints.length : i;
      final partial = routePoints.sublist(0, end);
      final progress = end / routePoints.length;
      final zoom = 16.7 - (progress * 2.6);

      setState(() {
        _polylines.removeWhere((p) => p.polylineId == const PolylineId('route'));
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: partial,
            color: const Color(0xFF00D4FF),
            width: 5,
            geodesic: true,
          ),
        );
      });

      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: origin, zoom: zoom.clamp(13.7, 16.7)),
          ),
        );
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }

    if (!mounted || animToken != _negotiatingAnimToken) return;
    _adjustCameraToFitRoute(routePoints);
  }

  /// Dibuja una línea recta como fallback cuando la API falla
  void _drawStraightLine(LatLng origin, LatLng destination) {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [origin, destination],
          color: const Color(0xFF00D4FF), // Azul eléctrico de la app
          width: 4,
        ),
      );
    });

    // Ajustar cámara para mostrar ambos puntos
    _adjustCameraToFitBounds(origin, destination);
  }

  /// Ajusta la cámara para mostrar toda la ruta (múltiples puntos)
  void _adjustCameraToFitRoute(List<LatLng> routePoints) {
    if (_mapController == null || routePoints.isEmpty) return;

    // Encontrar los límites de todos los puntos de la ruta
    double minLat = routePoints[0].latitude;
    double maxLat = routePoints[0].latitude;
    double minLng = routePoints[0].longitude;
    double maxLng = routePoints[0].longitude;

    for (final point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Animar la cámara para mostrar toda la ruta con padding
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  /// Ajusta la cámara para que ambos puntos (origen y destino) quepan en pantalla
  void _adjustCameraToFitBounds(LatLng origin, LatLng destination) {
    if (_mapController == null) return;

    // Calcular los límites (bounds) que incluyen ambos puntos
    final bounds = LatLngBounds(
      southwest: LatLng(
        origin.latitude < destination.latitude
            ? origin.latitude
            : destination.latitude,
        origin.longitude < destination.longitude
            ? origin.longitude
            : destination.longitude,
      ),
      northeast: LatLng(
        origin.latitude > destination.latitude
            ? origin.latitude
            : destination.latitude,
        origin.longitude > destination.longitude
            ? origin.longitude
            : destination.longitude,
      ),
    );

    // Animar la cámara para mostrar ambos puntos con padding
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  /// Limpia los marcadores y polylines del mapa
  void _clearMap() {
    setState(() {
      _markers.clear();
      _polylines.clear();
      _upsertDriverLocationMarker();
    });
  }

  /// Centra el mapa en la ubicación actual del conductor
  void _centerMapOnCurrentLocation() async {
    if (_mapController == null || _currentPosition == null) return;

    try {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      // Si falla, intentar obtener la ubicación nuevamente
      try {
        final position = await LocationHelper.determinePosition();
        setState(() {
          _currentPosition = position;
          _upsertDriverLocationMarker();
        });
        await _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        // Ignorar errores silenciosamente
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.78;
    final authState = context.watch<AuthBloc>().state;
    return BlocBuilder<DriverStatusBloc, DriverStatusState>(
      builder: (context, blocState) {
        final hasRejectedDocuments = authState is AuthAuthenticated &&
            _hasRejectedDocuments(authState.user);
        final showRejectedBanner =
            hasRejectedDocuments && blocState is DriverOffline;
        final immersiveMode = blocState is DriverNegotiating ||
            blocState is DriverWaitingForPassengerDecision;
        final bottomNavHeight = immersiveMode ? 0.0 : 56.0;

        return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      drawer: Drawer(
        width: drawerWidth,
        backgroundColor: const Color(0xFF0A0A0A),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<DriverStatsCubit>.value(
              value: context.read<DriverStatsCubit>(),
            ),
            BlocProvider<DriverWalletCubit>.value(
              value: context.read<DriverWalletCubit>(),
            ),
          ],
          child: DriverDrawer(hostContext: context),
        ),
      ),
      bottomNavigationBar:
          immersiveMode ? null : _buildBottomNavigationBar(),
      body: MultiBlocListener(
        listeners: [
          BlocListener<DriverStatusBloc, DriverStatusState>(
            listenWhen: (prev, curr) =>
                prev is DriverTripInProgress && curr is DriverOnline,
            listener: (context, state) {
              context.read<DriverStatsCubit>().refresh();
              context.read<DriverWalletCubit>().refresh();
            },
          ),
        ],
        child: BlocConsumer<DriverStatusBloc, DriverStatusState>(
          listener: (context, state) {
            if (state is DriverRequestExpired) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.warningOrange,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (state is DriverOnline) {
              // Limpiar mapa y centrar en ubicación actual
              _clearMap();
              _centerMapOnCurrentLocation();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modo Disponible activado'),
                  backgroundColor: AppTheme.successGreen,
                  duration: Duration(seconds: 2),
                ),
              );
            } else if (state is DriverOffline) {
              // Limpiar mapa cuando se desconecta
              _clearMap();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Modo No Disponible activado'),
                  backgroundColor: AppTheme.unavailableGray,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state is DriverNegotiating ||
                state is DriverWaitingForPassengerDecision) {
              final r = state is DriverNegotiating
                  ? (state as DriverNegotiating).activeRide
                  : (state as DriverWaitingForPassengerDecision).activeRide;
              final origin = LatLng(r.originLat, r.originLng);
              final destination = LatLng(r.destLat, r.destLng);
              _showRouteOnMap(
                origin,
                destination,
                animateNegotiatingEntry: true,
                rideIdForAnimation: r.id,
              );
            } else if (state is DriverOnTrip ||
                state is DriverArrivedAtPickup ||
                state is DriverTripInProgress) {
              _lastNegotiatingAnimatedRideId = null;
              _negotiatingAnimToken++;
              final ride = state is DriverOnTrip
                  ? state.activeRide
                  : state is DriverArrivedAtPickup
                      ? state.activeRide
                      : (state as DriverTripInProgress).activeRide;
              final origin = LatLng(ride.originLat, ride.originLng);
              final destination = LatLng(ride.destLat, ride.destLng);
              _showRouteOnMap(origin, destination);
            } else {
              _lastNegotiatingAnimatedRideId = null;
              _negotiatingAnimToken++;
            }
          },
          builder: (context, state) {
            return Stack(
              children: [
                // Mapa de Google Maps
                _mapError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Mapa no disponible',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: colors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _mapError!,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _mapError = null;
                                  });
                                },
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                     : GoogleMap(
                         onMapCreated: _onMapCreated,
                         initialCameraPosition: const CameraPosition(
                           target: LatLng(
                             AppConstants.trujilloLatitude,
                             AppConstants.trujilloLongitude,
                           ),
                           zoom: AppConstants.defaultZoom,
                         ),
                         mapType: MapType.normal,
                         myLocationEnabled: false,
                         myLocationButtonEnabled: false,
                         zoomControlsEnabled: false,
                         mapToolbarEnabled: false,
                         markers: _markers,
                         polylines: _polylines,
                         onCameraIdle: () {
                           // Mapa cargado correctamente
                         },
                       ),

                if (state is DriverWaitingForPassengerDecision)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      alignment: const Alignment(0, -0.25),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Se está ofreciendo tu tarifa de S/ ${state.submittedPrice.toStringAsFixed(2)},\nesperando respuesta del cliente...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Vistas de las pestañas (superpuestas sobre el mapa)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildTabView(context, state, bottomNavHeight),
                ),

                // Toggle de disponibilidad en la parte superior (siempre por encima)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: _buildAvailabilityToggle(context, state),
                        ),
                        if (showRejectedBanner) ...[
                          const SizedBox(height: 10),
                          _buildRejectedDocumentsBanner(context),
                        ],
                      ],
                    ),
                  ),
                ),

                // FAB del menú en la parte superior izquierda (oculto en negociación / espera)
                if (state is! DriverNegotiating &&
                    state is! DriverWaitingForPassengerDecision)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, left: 16),
                        child: FloatingActionButton(
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                          backgroundColor: colors.surface,
                          mini: true,
                          child: Icon(
                            Icons.more_vert,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Tarjeta de negociación o espera del pasajero
                if (state is DriverNegotiating)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: DriverNegotiatingCard(
                      activeRide: state.activeRide,
                      currentOffer: state.currentOffer,
                      isWaitingOnPassenger: false,
                      distanceToPickupKm: _currentPosition != null
                          ? LocationHelper.calculateDistance(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              LatLng(
                                state.activeRide.originLat,
                                state.activeRide.originLng,
                              ),
                            )
                          : null,
                    ),
                  ),
                if (state is DriverWaitingForPassengerDecision)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: DriverNegotiatingCard(
                      activeRide: state.activeRide,
                      currentOffer: state.submittedPrice,
                      isWaitingOnPassenger: true,
                      distanceToPickupKm: _currentPosition != null
                          ? LocationHelper.calculateDistance(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              LatLng(
                                state.activeRide.originLat,
                                state.activeRide.originLng,
                              ),
                            )
                          : null,
                    ),
                  ),

                // Fases operativas del viaje (aceptado → arribo → en curso)
                if (state is DriverOnTrip ||
                    state is DriverArrivedAtPickup ||
                    state is DriverTripInProgress)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildTripOperationalPanel(context, state),
                  ),
              ],
            );
          },
        ),
      ),
    );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    final colors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        backgroundColor: colors.surface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Solicitudes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department),
            label: 'Zonas Calientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Desempeño',
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(
    BuildContext context,
    DriverStatusState state,
    double bottomBarHeight,
  ) {
    if (state is DriverNegotiating || state is DriverWaitingForPassengerDecision) {
      return const SizedBox.shrink();
    }

    switch (_currentTabIndex) {
      case 0:
        return _buildRequestsView(context, state, bottomBarHeight);
      case 1:
        return _buildHotZonesView(context, bottomBarHeight);
      case 2:
        return _buildPerformanceView(context, bottomBarHeight);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRequestsView(BuildContext context, DriverStatusState state, double bottomBarHeight) {
    final colors = AppTheme.of(context);
    if (state is DriverOffline) {
      return Container(
        margin: EdgeInsets.only(bottom: bottomBarHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off,
                size: 48,
                color: colors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Conéctate para ver solicitudes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state is DriverOnline) {
      final mediaQuery = MediaQuery.of(context);
      const topGapBelowHeader = 10.0;
      const headerOverlayHeight = 140.0;
      final reservedTopSpace =
          mediaQuery.padding.top + headerOverlayHeight + topGapBelowHeader;
      final maxPanelHeight = mediaQuery.size.height - reservedTopSpace;
      return Container(
        height: maxPanelHeight > 0
            ? maxPanelHeight
            : mediaQuery.size.height * 0.4,
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Solicitudes cercanas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lista de solicitudes
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _requestClockSec,
                builder: (_, nowSec, __) {
                  final now = DateTime.fromMillisecondsSinceEpoch(
                    nowSec * 1000,
                    isUtc: true,
                  );
                  final rides = state.availableRides
                      .where((r) => !_isRideExpired(r, now))
                      .toList(growable: false);
                  if (rides.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay solicitudes cercanas',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      return _RideRequestItem(
                        ride: ride,
                        currentPosition: _currentPosition,
                        remainingTime: _remainingRequestTime(ride, now),
                        elapsedTime: _elapsedRequestTime(ride, now),
                        onTap: () {
                          context.read<DriverStatusBloc>().add(
                                ReceiveRequest(ride),
                              );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Cuando el conductor está en viaje, ocultar lista de solicitudes
    if (state is DriverOnTrip ||
        state is DriverArrivedAtPickup ||
        state is DriverTripInProgress) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  Widget _buildHotZonesView(BuildContext context, double bottomBarHeight) {
    final colors = AppTheme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: bottomBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              color: AppTheme.errorRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Actualizando zonas de alta demanda...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripOperationalPanel(
    BuildContext context,
    DriverStatusState state,
  ) {
    final colors = AppTheme.of(context);
    final RideEntity ride;
    final String title;
    final Widget actionButton;

    if (state is DriverOnTrip) {
      ride = state.activeRide;
      title = 'Camino al punto de recojo';
      actionButton = ElevatedButton(
        onPressed: () {
          context.read<DriverStatusBloc>().add(const NotifyArrival());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: const Text(
          '¡Ya llegué!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
    } else if (state is DriverArrivedAtPickup) {
      ride = state.activeRide;
      title = 'Pasajero en el punto de recojo';
      actionButton = ElevatedButton(
        onPressed: () {
          context.read<DriverStatusBloc>().add(const StartTrip());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Iniciar Viaje',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
    } else if (state is DriverTripInProgress) {
      ride = state.activeRide;
      title = 'Viaje en curso';
      actionButton = ElevatedButton(
        onPressed: () {
          context.read<DriverStatusBloc>().add(const FinishTrip());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.errorRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Finalizar Viaje',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    final passengerRef = ride.clientId.length > 8
        ? '${ride.clientId.substring(0, 8)}…'
        : ride.clientId;
    final price = ride.finalPrice ?? ride.offeredPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 56.0),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: colors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pasajero: $passengerRef',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.radio_button_checked,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride.originName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RideDestinationDisplay(rawDestName: ride.destName),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Tarifa acordada:',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${AppConstants.currencySymbol} ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            actionButton,
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceView(BuildContext context, double bottomBarHeight) {
    return Container(
      margin: EdgeInsets.only(bottom: bottomBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildStatsWidget(),
    );
  }

  Widget _buildAvailabilityToggle(BuildContext context, DriverStatusState state) {
    final isInTrip = state is DriverOnTrip ||
        state is DriverArrivedAtPickup ||
        state is DriverTripInProgress;
    final isNegotiating = state is DriverNegotiating ||
        state is DriverWaitingForPassengerDecision;
    final isAvailableOnline =
        state is DriverOnline || isNegotiating || isInTrip;

    Color chipColor;
    if (isNegotiating) {
      chipColor = const Color(0xFF00FF88);
    } else if (isInTrip) {
      chipColor = const Color(0xFFFFAA00);
    } else if (state is DriverOnline) {
      chipColor = AppTheme.primaryBlue;
    } else {
      chipColor = AppTheme.unavailableGray;
    }

    String chipLabel;
    if (isNegotiating) {
      chipLabel = state is DriverWaitingForPassengerDecision
          ? 'Esperando al pasajero'
          : 'Negociando';
    } else if (isInTrip) {
      chipLabel = 'En viaje';
    } else if (state is DriverOnline) {
      chipLabel = 'Disponible';
    } else {
      chipLabel = 'No Disponible';
    }

    return GestureDetector(
      onTap: () {
        final isTryingGoOnline = state is DriverOffline;
        if (isTryingGoOnline) {
          final authState = context.read<AuthBloc>().state;
          if (authState is AuthAuthenticated &&
              _hasRejectedDocuments(authState.user)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Revisa tus documentos: tienes archivos rechazados.',
                ),
                backgroundColor: AppTheme.errorRed,
              ),
            );
            context.push('/driver_rejected_documents');
            return;
          }
        }
        context.read<DriverStatusBloc>().add(const ToggleStatus());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: chipColor.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isAvailableOnline ? Colors.white : Colors.grey[400],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isAvailableOnline ? Colors.white : Colors.grey[400]!)
                        .withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              chipLabel,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasRejectedDocuments(user) {
    bool isRejected(String value) => value.trim().toUpperCase() == 'REJECTED';
    return isRejected(user.dniFrontStatus) ||
        isRejected(user.dniBackStatus) ||
        isRejected(user.licenseStatus) ||
        isRejected(user.soatStatus) ||
        isRejected(user.propertyCardStatus);
  }

  bool _isRideExpired(RideEntity ride, DateTime nowUtc) {
    return nowUtc.difference(ride.createdAt.toUtc()) >= _requestExpiry;
  }

  Duration _remainingRequestTime(RideEntity ride, DateTime nowUtc) {
    final elapsed = nowUtc.difference(ride.createdAt.toUtc());
    final remain = _requestExpiry - elapsed;
    return remain.isNegative ? Duration.zero : remain;
  }

  /// Tiempo desde la creación de la solicitud (0 → 15 min), inverso al contador del pasajero.
  Duration _elapsedRequestTime(RideEntity ride, DateTime nowUtc) {
    final elapsed = nowUtc.difference(ride.createdAt.toUtc());
    if (elapsed.isNegative) return Duration.zero;
    return elapsed > _requestExpiry ? _requestExpiry : elapsed;
  }

  Widget _buildRejectedDocumentsBanner(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.errorRed.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tienes documentos rechazados. Corrígelos para conectarte.',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/driver_rejected_documents'),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsWidget() {
    return BlocBuilder<DriverStatsCubit, DriverStatsState>(
      builder: (context, statsState) {
        final colors = AppTheme.of(context);
        final earningsText = statsState.isLoading
            ? '...'
            : '${AppConstants.currencySymbol} ${statsState.earnings.toStringAsFixed(2)}';
        final tripsText =
            statsState.isLoading ? '...' : '${statsState.trips}';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.attach_money,
                label: 'Ganancia de Hoy',
                value: earningsText,
                color: AppTheme.successGreen,
              ),
              Container(
                width: 1,
                height: 40,
                color: colors.textSecondary.withOpacity(0.3),
              ),
              _buildStatItem(
                icon: Icons.directions_car,
                label: 'Viajes',
                value: tripsText,
                color: AppTheme.primaryBlue,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
      ],
    );
  }

}

/// Fondo, borde y color de texto para chips de la solicitud (pago / servicio).
class _RideRequestChipPalette {
  const _RideRequestChipPalette({
    required this.fill,
    required this.border,
    required this.label,
  });

  final Color fill;
  final Color border;
  final Color label;
}

_RideRequestChipPalette _paymentChipPaletteFor(String paymentMethod) {
  switch (paymentMethod.toLowerCase().trim()) {
    case 'yape':
      return const _RideRequestChipPalette(
        fill: Color(0xFF6A1B9A),
        border: Color(0xFFCE93D8),
        label: Colors.white,
      );
    case 'plin':
      return const _RideRequestChipPalette(
        fill: Color(0xFF0277BD),
        border: Color(0xFF4FC3F7),
        label: Colors.white,
      );
    default:
      return const _RideRequestChipPalette(
        fill: Color(0xFF2E7D32),
        border: Color(0xFF81C784),
        label: Colors.white,
      );
  }
}

Widget _passengerAvatarOrPlaceholder(String? url, {required double size}) {
  final pic = url?.trim();
  if (pic != null && pic.isNotEmpty) {
    return Image.network(
      pic,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _passengerAvatarPlaceholder(size),
    );
  }
  return _passengerAvatarPlaceholder(size);
}

Widget _passengerAvatarPlaceholder(double size) {
  return Container(
    width: size,
    height: size,
    color: AppTheme.darkSurfaceElevated,
    alignment: Alignment.center,
    child: Icon(
      Icons.person,
      color: AppTheme.darkTextSecondary,
      size: size * 0.55,
    ),
  );
}

// Widget para cada item de solicitud
class _RideRequestItem extends StatelessWidget {
  final RideEntity ride;
  final Position? currentPosition;
  final Duration remainingTime;
  final Duration elapsedTime;
  final VoidCallback onTap;

  const _RideRequestItem({
    required this.ride,
    this.currentPosition,
    required this.remainingTime,
    required this.elapsedTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final cardBg = colors.surface;
    const cyanBorder = Color(0xFF00D4FF);

    final originLatLng = LatLng(ride.originLat, ride.originLng);

    double? distanceFromDriverKm;
    if (currentPosition != null) {
      distanceFromDriverKm = LocationHelper.calculateDistance(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        originLatLng,
      );
    }

    final distanceToPickupText = distanceFromDriverKm != null
        ? 'A ${distanceFromDriverKm.toStringAsFixed(1)} km de ti'
        : 'A — km de ti';

    final first =
        passengerFirstNameFromFullName(ride.clientFirstName.trim());
    final firstName = first.isEmpty ? 'Pasajero' : first;

    final pm = ride.paymentMethod.toLowerCase().trim();
    final bool isYape = pm == 'yape';
    final bool isPlin = pm == 'plin';
    final String paymentLabel =
        isYape ? 'Yape' : (isPlin ? 'Plin' : 'Efectivo');

    final destParts = RideDestPayloadParts.parse(ride.destName);
    final destLine =
        destParts.addressLine.trim().isEmpty ? '—' : destParts.addressLine;

    final payChip = _paymentChipPaletteFor(ride.paymentMethod);
    final elapsedSecs = elapsedTime.inSeconds.clamp(0, 15 * 60);
    final emins =
        (elapsedSecs ~/ 60).toString().padLeft(2, '0');
    final esecs =
        (elapsedSecs % 60).toString().padLeft(2, '0');
    final urgent = remainingTime <= const Duration(minutes: 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cyanBorder, width: 1.5),
                        ),
                        child: ClipOval(
                          child: _passengerAvatarOrPlaceholder(
                            ride.clientProfilePicUrl,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(
                          5,
                          (_) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 1),
                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${ride.clientCompletedTrips} viajes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: urgent
                              ? AppTheme.errorRed.withValues(alpha: 0.2)
                              : AppTheme.warningOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: urgent ? AppTheme.errorRed : AppTheme.warningOrange,
                          ),
                        ),
                        child: Text(
                          '$emins:$esecs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: urgent ? AppTheme.errorRed : AppTheme.warningOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distanceToPickupText,
                        style: TextStyle(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppConstants.currencySymbol} ${ride.offeredPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF00D4FF),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.my_location,
                              size: 14,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ride.originName,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.place,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              destLine,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: payChip.fill.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: payChip.border,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (isYape || isPlin)
                                  ? Icons.qr_code
                                  : Icons.attach_money,
                              size: 12,
                              color: payChip.label.withValues(alpha: 0.95),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              paymentLabel,
                              style: TextStyle(
                                color: payChip.label,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
